using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Models;

namespace WashSmart.API.Controllers;

public class RefundPaymentRequest
{
    public decimal? Amount { get; set; }
    public string? Reason { get; set; }
    public int? ComplaintId { get; set; }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public PaymentsController(ApplicationDbContext context)
    {
        _context = context;
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);
        return claim != null && int.TryParse(claim.Value, out var userId) ? userId : null;
    }

    private string? GetCurrentUserRole()
    {
        return User.FindFirst(ClaimTypes.Role)?.Value;
    }

    // ============================================================
    // GET: api/Payments/order/{orderId}
    // Xem chi tiết thanh toán và lịch sử hoàn tiền (khách, shipper, staff/admin)
    // ============================================================
    [HttpGet("order/{orderId}")]
    public async Task<IActionResult> GetPaymentByOrder(int orderId)
    {
        var userId = GetCurrentUserId();
        if (userId == null)
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var role = GetCurrentUserRole();
        var order = await _context.Orders.FirstOrDefaultAsync(x => x.Id == orderId);

        if (order == null)
        {
            return NotFound(new { message = "Không tìm thấy đơn hàng." });
        }

        var isOwner = order.CustomerId == userId;
        var isAssignedShipper = order.ShipperId == userId && role == "Shipper";
        var isStaff = role == "Admin" || role == "Staff";

        if (!isOwner && !isAssignedShipper && !isStaff)
        {
            return Forbid();
        }

        var payment = await _context.Payments.FirstOrDefaultAsync(x => x.OrderId == orderId);
        if (payment == null)
        {
            return NotFound(new { message = "Đơn hàng chưa có bản ghi thanh toán." });
        }

        return Ok(new
        {
            payment.Id,
            orderId = payment.OrderId,
            amount = payment.Amount,
            method = payment.Method.ToString(),
            status = payment.Status.ToString(),
            createdAt = payment.CreatedAt,
            paidAt = payment.PaidAt,
            paymentNote = payment.PaymentNote,
            refundedAmount = payment.RefundedAmount,
            refundReason = payment.RefundReason,
            refundedAt = payment.RefundedAt,
            refundedBy = payment.RefundedBy,
            complaintId = payment.ComplaintId
        });
    }

    // ============================================================
    // POST: api/Payments/order/{orderId}/create
    // ============================================================
    [HttpPost("order/{orderId}/create")]
    public async Task<IActionResult> CreatePayment(int orderId, [FromBody] CreatePaymentRequest request)
    {
        var userId = GetCurrentUserId();
        var role = GetCurrentUserRole();

        var order = await _context.Orders.FirstOrDefaultAsync(x => x.Id == orderId);
        if (order == null) return NotFound(new { message = "Không tìm thấy đơn hàng." });

        if (order.CustomerId != userId && role != "Admin" && role != "Staff")
        {
            return Forbid();
        }

        var existing = await _context.Payments.FirstOrDefaultAsync(x => x.OrderId == orderId);
        if (existing != null)
        {
            return BadRequest(new { message = "Đơn hàng đã có bản ghi thanh toán." });
        }

        Enum.TryParse<PaymentMethod>(request.Method, true, out var parsedMethod);
        var payment = new Payment
        {
            OrderId = orderId,
            Amount = order.TotalAmount,
            Method = parsedMethod,
            Status = PaymentStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            PaymentNote = request.Note
        };

        _context.Payments.Add(payment);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Tạo thanh toán thành công.",
            paymentId = payment.Id,
            orderId = payment.OrderId,
            method = payment.Method.ToString(),
            status = payment.Status.ToString(),
            amount = payment.Amount
        });
    }

    // ============================================================
    // POST: api/Payments/order/{orderId}/confirm
    // Shipper / Admin / Staff xác nhận đã thu tiền thực tế
    // ============================================================
    [HttpPost("order/{orderId}/confirm")]
    [Authorize(Roles = "Shipper,Admin,Staff")]
    public async Task<IActionResult> ConfirmPayment(int orderId, [FromBody] ConfirmPaymentRequest request)
    {
        var userId = GetCurrentUserId();
        var role = GetCurrentUserRole();

        var payment = await _context.Payments
            .Include(x => x.Order)
            .FirstOrDefaultAsync(x => x.OrderId == orderId);

        if (payment == null)
        {
            return NotFound(new { message = "Đơn hàng chưa có thanh toán." });
        }

        if (role == "Shipper" && payment.Order!.ShipperId != userId)
        {
            return Forbid();
        }

        if (payment.Status == PaymentStatus.Paid)
        {
            return BadRequest(new { message = "Thanh toán đã được xác nhận trước đó." });
        }

        if (payment.Status == PaymentStatus.Refunded)
        {
            return BadRequest(new { message = "Thanh toán đã bị hoàn tiền, không thể xác nhận." });
        }

        payment.Status = PaymentStatus.Paid;
        payment.PaidAt = DateTime.UtcNow;
        payment.PaymentNote = request.Note; // LƯU THỰC SỰ VÀO CSDL

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Xác nhận thanh toán thành công.",
            paymentId = payment.Id,
            orderId = payment.OrderId,
            status = payment.Status.ToString(),
            paidAt = payment.PaidAt,
            note = payment.PaymentNote
        });
    }

    // ============================================================
    // POST: api/Payments/order/{orderId}/refund
    // Admin duyệt hoàn tiền: Lưu rõ số tiền, lý do, người duyệt, liên kết khiếu nại
    // ============================================================
    [HttpPost("order/{orderId}/refund")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> RefundPayment(int orderId, [FromBody] RefundPaymentRequest? request)
    {
        request ??= new RefundPaymentRequest();

        var payment = await _context.Payments
            .Include(p => p.Order)
            .FirstOrDefaultAsync(x => x.OrderId == orderId);

        if (payment == null)
        {
            return NotFound(new { message = "Đơn hàng chưa có thanh toán." });
        }

        if (payment.Status != PaymentStatus.Paid)
        {
            return BadRequest(new { message = "Chỉ có thể hoàn tiền cho thanh toán đã ở trạng thái Paid." });
        }

        var refundAmount = request.Amount.HasValue && request.Amount.Value > 0
            ? request.Amount.Value
            : payment.Amount;

        if (refundAmount > payment.Amount)
        {
            return BadRequest(new { message = $"Số tiền hoàn ({refundAmount:N0}đ) không được vượt quá số tiền đơn hàng ({payment.Amount:N0}đ)." });
        }

        var adminName = User.FindFirstValue(ClaimTypes.Name) ?? "Admin";

        payment.RefundedAmount = refundAmount;
        payment.RefundReason = !string.IsNullOrWhiteSpace(request.Reason)
            ? request.Reason.Trim()
            : "Hoàn tiền bồi thường đơn hàng theo yêu cầu quản trị viên.";
        payment.RefundedAt = DateTime.UtcNow;
        payment.RefundedBy = adminName;
        payment.ComplaintId = request.ComplaintId;

        // Nếu hoàn 100% thì chuyển trạng thái Refunded
        if (refundAmount >= payment.Amount)
        {
            payment.Status = PaymentStatus.Refunded;
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Hoàn tiền {refundAmount:N0}đ thành công.",
            paymentId = payment.Id,
            orderId = payment.OrderId,
            status = payment.Status.ToString(),
            refundedAmount = payment.RefundedAmount,
            refundReason = payment.RefundReason,
            refundedAt = payment.RefundedAt,
            refundedBy = payment.RefundedBy,
            complaintId = payment.ComplaintId
        });
    }
}
