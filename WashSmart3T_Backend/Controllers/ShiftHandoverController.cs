using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using System.Text.Json;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Hubs;
using WashSmart.API.Models;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ShiftHandoverController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IHubContext<OrderNotificationHub> _hubContext;

    public ShiftHandoverController(
        ApplicationDbContext context,
        IHubContext<OrderNotificationHub> hubContext)
    {
        _context = context;
        _hubContext = hubContext;
    }

    // ============================================================
    // GET: api/ShiftHandover/current-shift
    // Shipper xem thống kê các đơn đã hoàn tất trong ca hiện tại
    // và số tiền mặt cần nộp lại cho quầy
    // ============================================================
    [HttpGet("current-shift")]
    [Authorize(Roles = "Shipper,Admin,Staff")]
    public async Task<IActionResult> GetCurrentShiftSummary()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int currentUserId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        int targetShipperId = currentUserId;
        // Nếu là Admin/Staff muốn xem của shipper cụ thể qua query param ?shipperId=...
        if (Request.Query.ContainsKey("shipperId") && int.TryParse(Request.Query["shipperId"], out int queryShipperId))
        {
            targetShipperId = queryShipperId;
        }

        // 1. Kiểm tra phiên bàn giao đang chờ duyệt (Pending) gần nhất
        var pendingHandover = await _context.ShiftHandovers
            .AsNoTracking()
            .Where(x => x.ShipperId == targetShipperId && x.Status == "Pending")
            .OrderByDescending(x => x.CreatedAt)
            .FirstOrDefaultAsync();

        // 2. Xác định các đơn đã được bàn giao chốt ca trước đây
        var lastConfirmedHandover = await _context.ShiftHandovers
            .AsNoTracking()
            .Where(x => x.ShipperId == targetShipperId && x.Status == "Confirmed")
            .OrderByDescending(x => x.ConfirmedAt)
            .FirstOrDefaultAsync();

        var shiftStartTime = lastConfirmedHandover?.ConfirmedAt;

        var confirmedOrderIdsJson = await _context.ShiftHandovers
            .AsNoTracking()
            .Where(x => x.ShipperId == targetShipperId && x.Status == "Confirmed" && x.OrderIdsJson != null)
            .Select(x => x.OrderIdsJson)
            .ToListAsync();

        var handedOverSet = new HashSet<int>();
        foreach (var json in confirmedOrderIdsJson)
        {
            if (!string.IsNullOrWhiteSpace(json))
            {
                try
                {
                    var ids = JsonSerializer.Deserialize<List<int>>(json);
                    if (ids != null)
                    {
                        foreach (var id in ids) handedOverSet.Add(id);
                    }
                }
                catch { }
            }
        }

        // 3. Lấy tất cả các đơn hàng hoàn tất của shipper này chưa được bàn giao chốt sổ
        var allCompletedOrders = await _context.Orders
            .AsNoTracking()
            .Where(o => o.ShipperId == targetShipperId && o.Status == OrderStatus.Completed)
            .OrderByDescending(o => o.UpdatedAt ?? o.CreatedAt)
            .Select(o => new
            {
                o.Id,
                orderCode = $"WS3T-{o.Id:D4}",
                o.ContactPhone,
                customerName = o.Customer != null ? o.Customer.FullName : "Khách hàng",
                o.PickupAddress,
                o.DeliveryAddress,
                o.TotalAmount,
                o.PaymentMethod,
                isCash = o.PaymentMethod == "Cash" || o.PaymentMethod == "COD",
                o.CreatedAt,
                o.UpdatedAt
            })
            .ToListAsync();

        var completedOrders = allCompletedOrders.Where(o => !handedOverSet.Contains(o.Id)).ToList();

        var cashOrders = completedOrders.Where(x => x.isCash).ToList();
        var onlineOrders = completedOrders.Where(x => !x.isCash).ToList();

        decimal cashTotal = cashOrders.Sum(x => x.TotalAmount);
        decimal onlineTotal = onlineOrders.Sum(x => x.TotalAmount);

        return Ok(new
        {
            shipperId = targetShipperId,
            shiftStartTime,
            hasPendingHandover = pendingHandover != null,
            pendingHandover = pendingHandover != null ? new
            {
                pendingHandover.Id,
                pendingHandover.TotalOrders,
                pendingHandover.CashOrdersCount,
                pendingHandover.OnlineOrdersCount,
                pendingHandover.CashAmount,
                pendingHandover.OnlineAmount,
                pendingHandover.Status,
                pendingHandover.Note,
                pendingHandover.CreatedAt
            } : null,
            lastConfirmedHandover = lastConfirmedHandover != null ? new
            {
                lastConfirmedHandover.Id,
                lastConfirmedHandover.CashAmount,
                lastConfirmedHandover.ConfirmedAt
            } : null,
            totalOrders = completedOrders.Count,
            cashOrdersCount = cashOrders.Count,
            cashAmount = cashTotal,
            onlineOrdersCount = onlineOrders.Count,
            onlineAmount = onlineTotal,
            orders = completedOrders
        });
    }

    // ============================================================
    // POST: api/ShiftHandover/submit
    // Shipper gửi biên bản bàn giao tiền mặt cuối ca
    // ============================================================
    [HttpPost("submit")]
    [Authorize(Roles = "Shipper")]
    public async Task<IActionResult> SubmitShiftHandover([FromBody] SubmitShiftHandoverRequest request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int shipperId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var shipper = await _context.Users.FindAsync(shipperId);
        if (shipper == null) return NotFound(new { message = "Không tìm thấy thông tin shipper." });

        // Kiểm tra xem đã có yêu cầu nào đang chờ duyệt hay chưa
        var existingPending = await _context.ShiftHandovers
            .FirstOrDefaultAsync(x => x.ShipperId == shipperId && x.Status == "Pending");

        if (existingPending != null)
        {
            return BadRequest(new { message = "Bạn đã có một phiên bàn giao đang chờ quản lý xác nhận. Vui lòng đợi thu ngân kiểm đếm xong." });
        }

        // Tính toán các đơn của ca hiện tại chưa được bàn giao
        var confirmedOrderIdsJson = await _context.ShiftHandovers
            .AsNoTracking()
            .Where(x => x.ShipperId == shipperId && x.Status == "Confirmed" && x.OrderIdsJson != null)
            .Select(x => x.OrderIdsJson)
            .ToListAsync();

        var handedOverSet = new HashSet<int>();
        foreach (var json in confirmedOrderIdsJson)
        {
            if (!string.IsNullOrWhiteSpace(json))
            {
                try
                {
                    var ids = JsonSerializer.Deserialize<List<int>>(json);
                    if (ids != null)
                    {
                        foreach (var id in ids) handedOverSet.Add(id);
                    }
                }
                catch { }
            }
        }

        var allCompletedOrders = await _context.Orders
            .Where(o => o.ShipperId == shipperId && o.Status == OrderStatus.Completed)
            .ToListAsync();

        var completedOrders = allCompletedOrders.Where(o => !handedOverSet.Contains(o.Id)).ToList();

        if (completedOrders.Count == 0)
        {
            return BadRequest(new { message = "Ca làm việc hiện tại chưa có đơn hàng nào hoàn tất để bàn giao." });
        }

        var cashOrders = completedOrders.Where(o => o.PaymentMethod == "Cash" || o.PaymentMethod == "COD").ToList();
        var onlineOrders = completedOrders.Where(o => o.PaymentMethod != "Cash" && o.PaymentMethod != "COD").ToList();

        decimal cashAmount = cashOrders.Sum(o => o.TotalAmount);
        decimal onlineAmount = onlineOrders.Sum(o => o.TotalAmount);

        var orderIds = completedOrders.Select(o => o.Id).ToList();

        var handover = new ShiftHandover
        {
            ShipperId = shipperId,
            TotalOrders = completedOrders.Count,
            CashOrdersCount = cashOrders.Count,
            OnlineOrdersCount = onlineOrders.Count,
            CashAmount = cashAmount,
            OnlineAmount = onlineAmount,
            Status = "Pending",
            Note = request.Note?.Trim(),
            CreatedAt = DateTime.UtcNow,
            OrderIdsJson = JsonSerializer.Serialize(orderIds)
        };

        _context.ShiftHandovers.Add(handover);
        await _context.SaveChangesAsync();

        // Gửi thông báo thời gian thực qua SignalR Hub tới Web Portal (Quản lý / Thu ngân)
        try
        {
            await _hubContext.Clients.All.SendAsync("ShiftHandoverSubmitted", new
            {
                handoverId = handover.Id,
                shipperId = shipper.Id,
                shipperName = shipper.FullName,
                shipperPhone = shipper.Phone,
                cashAmount = handover.CashAmount,
                onlineAmount = handover.OnlineAmount,
                totalOrders = handover.TotalOrders,
                cashOrdersCount = handover.CashOrdersCount,
                createdAt = handover.CreatedAt,
                note = handover.Note
            });
        }
        catch { }

        return Ok(new
        {
            success = true,
            message = "Gửi biên bản bàn giao ca thành công! Vui lòng nộp số tiền mặt cho quản lý để được xác nhận.",
            handoverId = handover.Id,
            cashAmount = handover.CashAmount,
            totalOrders = handover.TotalOrders
        });
    }

    // ============================================================
    // GET: api/ShiftHandover/pending-list
    // Quản lý/Thu ngân xem danh sách các phiên nộp tiền đang chờ duyệt
    // ============================================================
    [HttpGet("pending-list")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> GetPendingHandovers()
    {
        var list = await _context.ShiftHandovers
            .AsNoTracking()
            .Include(x => x.Shipper)
            .Where(x => x.Status == "Pending")
            .OrderByDescending(x => x.CreatedAt)
            .Select(x => new
            {
                x.Id,
                x.ShipperId,
                shipperName = x.Shipper != null ? x.Shipper.FullName : "Shipper",
                shipperPhone = x.Shipper != null ? x.Shipper.Phone : "",
                x.TotalOrders,
                x.CashOrdersCount,
                x.OnlineOrdersCount,
                x.CashAmount,
                x.OnlineAmount,
                x.Status,
                x.Note,
                x.CreatedAt,
                x.OrderIdsJson
            })
            .ToListAsync();

        return Ok(list);
    }

    // ============================================================
    // GET: api/ShiftHandover/history
    // Xem lịch sử các phiên bàn giao ca
    // ============================================================
    [HttpGet("history")]
    [Authorize(Roles = "Admin,Staff,Shipper")]
    public async Task<IActionResult> GetHandoverHistory([FromQuery] int? shipperId)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        var roleClaim = User.FindFirst(ClaimTypes.Role)?.Value;

        var query = _context.ShiftHandovers
            .AsNoTracking()
            .Include(x => x.Shipper)
            .Include(x => x.ConfirmedByUser)
            .AsQueryable();

        // Nếu là Shipper thì chỉ xem lịch sử của chính mình
        if (roleClaim == "Shipper" && int.TryParse(userIdClaim, out int currentShipperId))
        {
            query = query.Where(x => x.ShipperId == currentShipperId);
        }
        else if (shipperId.HasValue)
        {
            query = query.Where(x => x.ShipperId == shipperId.Value);
        }

        var history = await query
            .OrderByDescending(x => x.CreatedAt)
            .Take(50)
            .Select(x => new
            {
                x.Id,
                x.ShipperId,
                shipperName = x.Shipper != null ? x.Shipper.FullName : "Shipper",
                shipperPhone = x.Shipper != null ? x.Shipper.Phone : "",
                x.TotalOrders,
                x.CashOrdersCount,
                x.OnlineOrdersCount,
                x.CashAmount,
                x.OnlineAmount,
                x.Status,
                x.Note,
                x.ManagerNote,
                x.CreatedAt,
                x.ConfirmedAt,
                confirmedByName = x.ConfirmedByUser != null ? x.ConfirmedByUser.FullName : null
            })
            .ToListAsync();

        return Ok(history);
    }

    // ============================================================
    // POST: api/ShiftHandover/{id}/confirm
    // Quản lý/Thu ngân xác nhận đã nhận đủ tiền mặt từ shipper
    // ============================================================
    [HttpPost("{id}/confirm")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> ConfirmShiftHandover(int id, [FromBody] ConfirmShiftHandoverRequest? request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int managerId))
        {
            return Unauthorized(new { message = "Không xác định được danh tính quản lý." });
        }

        var manager = await _context.Users.FindAsync(managerId);
        var handover = await _context.ShiftHandovers
            .Include(x => x.Shipper)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (handover == null)
        {
            return NotFound(new { message = "Không tìm thấy phiên bàn giao ca này." });
        }

        if (handover.Status != "Pending")
        {
            return BadRequest(new { message = $"Phiên bàn giao ca này đã được xử lý (trạng thái: {handover.Status})." });
        }

        handover.Status = "Confirmed";
        handover.ConfirmedByUserId = managerId;
        handover.ConfirmedAt = DateTime.UtcNow;
        if (!string.IsNullOrWhiteSpace(request?.ManagerNote))
        {
            handover.ManagerNote = request.ManagerNote.Trim();
        }

        await _context.SaveChangesAsync();

        // Bắn SignalR thông báo tới app Shipper và quầy
        try
        {
            await _hubContext.Clients.All.SendAsync("ShiftHandoverConfirmed", new
            {
                handoverId = handover.Id,
                shipperId = handover.ShipperId,
                confirmedBy = manager?.FullName ?? "Quản lý",
                confirmedAt = handover.ConfirmedAt,
                cashAmount = handover.CashAmount,
                message = "Quản lý đã xác nhận nhận đủ tiền mặt! Ca làm việc của bạn đã được chốt sổ thành công."
            });
        }
        catch { }

        return Ok(new
        {
            success = true,
            message = $"Đã xác nhận thu đủ {handover.CashAmount:N0} đ tiền mặt từ Shipper {handover.Shipper?.FullName}.",
            handoverId = handover.Id,
            confirmedAt = handover.ConfirmedAt
        });
    }

    // ============================================================
    // POST: api/ShiftHandover/{id}/reject
    // Quản lý từ chối (nếu lệch tiền hoặc có sai sót)
    // ============================================================
    [HttpPost("{id}/reject")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> RejectShiftHandover(int id, [FromBody] RejectShiftHandoverRequest request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int managerId))
        {
            return Unauthorized(new { message = "Không xác định được danh tính quản lý." });
        }

        var manager = await _context.Users.FindAsync(managerId);
        var handover = await _context.ShiftHandovers
            .Include(x => x.Shipper)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (handover == null) return NotFound(new { message = "Không tìm thấy phiên bàn giao ca này." });

        if (handover.Status != "Pending")
        {
            return BadRequest(new { message = $"Phiên bàn giao này đã được xử lý (trạng thái: {handover.Status})." });
        }

        handover.Status = "Rejected";
        handover.ConfirmedByUserId = managerId;
        handover.ConfirmedAt = DateTime.UtcNow;
        handover.ManagerNote = string.IsNullOrWhiteSpace(request.Reason) ? "Số tiền thực tế kiểm đếm không khớp với hệ thống." : request.Reason.Trim();

        await _context.SaveChangesAsync();

        try
        {
            await _hubContext.Clients.All.SendAsync("ShiftHandoverRejected", new
            {
                handoverId = handover.Id,
                shipperId = handover.ShipperId,
                confirmedBy = manager?.FullName ?? "Quản lý",
                reason = handover.ManagerNote
            });
        }
        catch { }

        return Ok(new
        {
            success = true,
            message = "Đã từ chối bàn giao ca do sai lệch số tiền. Shipper sẽ cần kiểm tra lại.",
            handoverId = handover.Id
        });
    }
}
