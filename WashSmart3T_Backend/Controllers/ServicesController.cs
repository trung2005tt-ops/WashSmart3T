using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Models;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ServicesController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public ServicesController(ApplicationDbContext context)
    {
        _context = context;
    }

    // =========================
    // GET: api/Services
    // =========================
    [HttpGet]
    public async Task<IActionResult> GetServices([FromQuery] bool includeInactive = false)
    {
        var query = _context.Services.AsQueryable();
        if (!includeInactive)
        {
            query = query.Where(x => x.IsActive);
        }

        var services = await query
            .Include(x => x.Prices)
            .Select(x => new
            {
                x.Id,
                x.Name,
                x.Description,
                x.IsActive,

                Price = x.Prices
                    .Where(p => p.IsActive && p.EffectiveTo == null)
                    .OrderByDescending(p => p.EffectiveFrom)
                    .Select(p => new
                    {
                        p.Price,
                        p.Unit,
                        p.MinimumPrice,
                        p.EffectiveFrom
                    })
                    .FirstOrDefault()
            })
            .ToListAsync();

        return Ok(services);
    }

    // =========================
    // GET: api/Services/1
    // =========================
    [HttpGet("{id}")]
    public async Task<IActionResult> GetService(int id)
    {
        var service = await _context.Services
            .Include(x => x.Prices)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (service == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy dịch vụ."
            });
        }

        return Ok(new
        {
            service.Id,
            service.Name,
            service.Description,
            service.IsActive,

            CurrentPrice = service.Prices
                .Where(p => p.IsActive && p.EffectiveTo == null)
                .OrderByDescending(p => p.EffectiveFrom)
                .Select(p => new
                {
                    p.Id,
                    p.Price,
                    p.Unit,
                    p.MinimumPrice,
                    p.EffectiveFrom
                })
                .FirstOrDefault()
        });
    }

    // =========================
    // POST: api/Services
    // ADMIN / STAFF
    // =========================
    [Authorize(Roles = "Admin,Staff")]
    [HttpPost]
    public async Task<IActionResult> CreateService(
        ServiceCreateRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(new
            {
                message = "Tên dịch vụ không được để trống."
            });
        }

        if (request.Price < 0)
        {
            return BadRequest(new
            {
                message = "Giá dịch vụ không hợp lệ."
            });
        }

        var service = new Service
        {
            Name = request.Name,
            Description = request.Description,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.Services.Add(service);

        await _context.SaveChangesAsync();

        var price = new ServicePrice
        {
            ServiceId = service.Id,
            Price = request.Price,
            Unit = request.Unit,
            MinimumPrice = request.MinimumPrice,
            EffectiveFrom = DateTime.UtcNow,
            EffectiveTo = null,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.ServicePrices.Add(price);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Tạo dịch vụ thành công.",
            serviceId = service.Id
        });
    }

    // =========================
    // PUT: api/Services/1
    // ADMIN / STAFF
    // =========================
    [Authorize(Roles = "Admin,Staff")]
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateService(
        int id,
        ServiceCreateRequest request)
    {
        var service = await _context.Services
            .Include(x => x.Prices)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (service == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy dịch vụ."
            });
        }

        if (!string.IsNullOrWhiteSpace(request.Name))
        {
            service.Name = request.Name;
        }
        service.Description = request.Description ?? string.Empty;
        service.UpdatedAt = DateTime.UtcNow;

        // Cập nhật giá & đơn vị nếu được cung cấp
        if (request.Price >= 0 && !string.IsNullOrWhiteSpace(request.Unit))
        {
            var currentPrice = service.Prices
                .FirstOrDefault(x => x.IsActive && x.EffectiveTo == null);

            if (currentPrice != null)
            {
                if (currentPrice.Price != request.Price || currentPrice.Unit != request.Unit)
                {
                    currentPrice.EffectiveTo = DateTime.UtcNow;
                    currentPrice.IsActive = false;

                    var newPrice = new ServicePrice
                    {
                        ServiceId = service.Id,
                        Price = request.Price,
                        Unit = request.Unit,
                        MinimumPrice = request.MinimumPrice,
                        EffectiveFrom = DateTime.UtcNow,
                        EffectiveTo = null,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    };
                    _context.ServicePrices.Add(newPrice);
                }
            }
            else
            {
                var newPrice = new ServicePrice
                {
                    ServiceId = service.Id,
                    Price = request.Price,
                    Unit = request.Unit,
                    MinimumPrice = request.MinimumPrice,
                    EffectiveFrom = DateTime.UtcNow,
                    EffectiveTo = null,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                };
                _context.ServicePrices.Add(newPrice);
            }
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật dịch vụ thành công."
        });
    }

    // =========================
    // PATCH: api/Services/1/status
    // ADMIN / STAFF
    // =========================
    [Authorize(Roles = "Admin,Staff")]
    [HttpPatch("{id}/status")]
    public async Task<IActionResult> UpdateStatus(
        int id,
        [FromQuery] bool isActive)
    {
        var service = await _context.Services
            .FirstOrDefaultAsync(x => x.Id == id);

        if (service == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy dịch vụ."
            });
        }

        service.IsActive = isActive;
        service.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = isActive
                ? "Đã kích hoạt dịch vụ."
                : "Đã tạm ngưng dịch vụ."
        });
    }

    // =========================
    // PUT: api/Services/1/price
    // ADMIN / STAFF
    // =========================
    [Authorize(Roles = "Admin,Staff")]
    [HttpPut("{id}/price")]
    public async Task<IActionResult> UpdatePrice(
        int id,
        ServicePriceUpdateRequest request)
    {
        if (request.Price < 0)
        {
            return BadRequest(new
            {
                message = "Giá không hợp lệ."
            });
        }

        var service = await _context.Services
            .Include(x => x.Prices)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (service == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy dịch vụ."
            });
        }

        // Đóng giá hiện tại
        var currentPrice = service.Prices
            .FirstOrDefault(x =>
                x.IsActive &&
                x.EffectiveTo == null);

        if (currentPrice != null)
        {
            currentPrice.EffectiveTo = DateTime.UtcNow;
            currentPrice.IsActive = false;
        }

        // Tạo giá mới
        var newPrice = new ServicePrice
        {
            ServiceId = service.Id,
            Price = request.Price,
            Unit = request.Unit,
            MinimumPrice = request.MinimumPrice,
            EffectiveFrom = DateTime.UtcNow,
            EffectiveTo = null,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.ServicePrices.Add(newPrice);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật giá thành công.",
            newPrice = request.Price,
            unit = request.Unit
        });
    }

    // =========================
    // POST: api/Services/{id}/toggle
    // ADMIN: Bật / Tắt trạng thái kinh doanh dịch vụ
    // =========================
    [Authorize(Roles = "Admin,Staff")]
    [HttpPost("{id}/toggle")]
    public async Task<IActionResult> ToggleService(int id)
    {
        var service = await _context.Services.FirstOrDefaultAsync(x => x.Id == id);
        if (service == null)
        {
            return NotFound(new { message = "Không tìm thấy dịch vụ." });
        }

        service.IsActive = !service.IsActive;
        service.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Đã {(service.IsActive ? "kích hoạt kinh doanh" : "tạm dừng kinh doanh")} dịch vụ: {service.Name}",
            isActive = service.IsActive
        });
    }

    // =========================
    // DELETE: api/Services/{id}
    // ADMIN / STAFF: Xóa dịch vụ
    // =========================
    [Authorize(Roles = "Admin,Staff")]
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteService(int id)
    {
        var service = await _context.Services
            .Include(x => x.Prices)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (service == null)
        {
            return NotFound(new { message = "Không tìm thấy dịch vụ." });
        }

        var hasOrders = await _context.OrderDetails.AnyAsync(x => x.ServiceId == id);
        if (hasOrders)
        {
            service.IsActive = false;
            service.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return Ok(new { message = $"Dịch vụ '{service.Name}' đã có đơn hàng trong quá khứ nên đã được chuyển sang trạng thái tạm ngưng kinh doanh." });
        }

        if (service.Prices != null && service.Prices.Any())
        {
            _context.ServicePrices.RemoveRange(service.Prices);
        }

        _context.Services.Remove(service);
        await _context.SaveChangesAsync();

        return Ok(new { message = $"Đã xóa dịch vụ '{service.Name}' thành công." });
    }
}