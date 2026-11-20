using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.Models;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CareOptionsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public CareOptionsController(ApplicationDbContext context)
    {
        _context = context;
    }

    // ============================================================
    // GET: api/CareOptions
    // Lấy danh sách các gói chăm sóc nâng cao & đóng gói
    // ============================================================
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetAll([FromQuery] bool includeInactive = false)
    {
        var query = _context.CareOptions.AsNoTracking();
        if (!includeInactive)
        {
            query = query.Where(x => x.IsActive);
        }

        var list = await query.OrderBy(x => x.Id).ToListAsync();
        return Ok(list);
    }

    // ============================================================
    // GET: api/CareOptions/{id}
    // ============================================================
    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetById(int id)
    {
        var item = await _context.CareOptions.FindAsync(id);
        if (item == null)
        {
            return NotFound(new { message = "Không tìm thấy gói chăm sóc." });
        }
        return Ok(item);
    }

    // ============================================================
    // POST: api/CareOptions
    // Thêm gói chăm sóc nâng cao mới (Admin/Staff)
    // ============================================================
    [HttpPost]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> Create([FromBody] CareOptionRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(new { message = "Tên gói chăm sóc không được để trống." });
        }

        var option = new CareOption
        {
            Name = request.Name.Trim(),
            Description = request.Description?.Trim() ?? string.Empty,
            Price = request.Price < 0 ? 0 : request.Price,
            BadgeText = string.IsNullOrWhiteSpace(request.BadgeText) ? null : request.BadgeText.Trim(),
            IsActive = request.IsActive,
            CreatedAt = DateTime.UtcNow
        };

        _context.CareOptions.Add(option);
        await _context.SaveChangesAsync();

        return CreatedAtAction(nameof(GetById), new { id = option.Id }, option);
    }

    // ============================================================
    // PUT: api/CareOptions/{id}
    // Sửa thông tin & đơn giá gói chăm sóc (Admin/Staff)
    // ============================================================
    [HttpPut("{id}")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> Update(int id, [FromBody] CareOptionRequest request)
    {
        var item = await _context.CareOptions.FindAsync(id);
        if (item == null)
        {
            return NotFound(new { message = "Không tìm thấy gói chăm sóc cần cập nhật." });
        }

        if (string.IsNullOrWhiteSpace(request.Name))
        {
            return BadRequest(new { message = "Tên gói chăm sóc không được để trống." });
        }

        item.Name = request.Name.Trim();
        item.Description = request.Description?.Trim() ?? string.Empty;
        item.Price = request.Price < 0 ? 0 : request.Price;
        item.BadgeText = string.IsNullOrWhiteSpace(request.BadgeText) ? null : request.BadgeText.Trim();
        item.IsActive = request.IsActive;
        item.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật gói chăm sóc nâng cao thành công.",
            data = item
        });
    }

    // ============================================================
    // POST: api/CareOptions/{id}/toggle
    // Bật/tắt trạng thái gói chăm sóc
    // ============================================================
    [HttpPost("{id}/toggle")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> Toggle(int id)
    {
        var item = await _context.CareOptions.FindAsync(id);
        if (item == null)
        {
            return NotFound(new { message = "Không tìm thấy gói chăm sóc." });
        }

        item.IsActive = !item.IsActive;
        item.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Đã {(item.IsActive ? "kích hoạt" : "tạm dừng")} gói chăm sóc: {item.Name}",
            isActive = item.IsActive
        });
    }

    // ============================================================
    // DELETE: api/CareOptions/{id}
    // Xóa gói chăm sóc (Admin)
    // ============================================================
    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var item = await _context.CareOptions.FindAsync(id);
        if (item == null)
        {
            return NotFound(new { message = "Không tìm thấy gói chăm sóc." });
        }

        _context.CareOptions.Remove(item);
        await _context.SaveChangesAsync();

        return Ok(new { message = "Đã xóa gói chăm sóc thành công." });
    }
}

public class CareOptionRequest
{
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public decimal Price { get; set; } = 0;
    public string? BadgeText { get; set; }
    public bool IsActive { get; set; } = true;
}
