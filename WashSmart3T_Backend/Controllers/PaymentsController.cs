using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Models;

namespace WashSmart.API.Controllers;

// ============================================================
// QUẢN LÝ THANH TOÁN ĐƠN HÀNG
// ============================================================

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

        return claim != null &&
            int.TryParse(claim.Value, out var userId)
            ? userId
            : null;
    }

    private string? GetCurrentUserRole()
    {
        return User.FindFirst(ClaimTypes.Role)?.Value;
    }

    // ============================================================
    // GET: api/Payments/order/{orderId}
    // Xem thanh toán của một đơn hàng
    // (khách sở hữu đơn, shipper giao đơn, admin/staff)
    // ============================================================

    [HttpGet("order/{orderId}")]
    public async Task<IActionResult> GetPaymentByOrder(int orderId)
    {
        var userId = GetCurrentUserId();

        if (userId == null)
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var role = GetCurrentUserRole();

        var order = await _context.Orders
            .FirstOrDefaultAsync(x => x.Id == orderId);

        if (order == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        var isOwner = order.CustomerId == userId;

        var isAssignedShipper =
            order.ShipperId == userId &&
            role == "Shipper";

        var isStaff = role == "Admin" || role == "Staff";

        if (!isOwner && !isAssignedShipper && !isStaff)
        {
            return Forbid();
        }

        var payment = await _context.Payments
            .FirstOrDefaultAsync(x => x.OrderId == orderId);

        if (payment == null)
        {
            return NotFound(new
            {
                message = "Đơn hàng chưa có thanh toán."
            });
        }

        return Ok(new
        {
            payment.Id,
            payment.OrderId,
            method = payment.Method.ToString(),
            status = payment.Status.ToString(),
            payment.Amount,
            payment.CreatedAt,
            payment.PaidAt
        });
    }

    // ============================================================
    // POST: api/Payments/order/{orderId}
    // Khách tạo thanh toán cho đơn hàng của mình
    // ============================================================

    [HttpPost("order/{orderId}")]
    public async Task<IActionResult> CreatePayment(
        int orderId,
        CreatePaymentRequest request)
    {
        var userId = GetCurrentUserId();

        if (userId == null)
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var order = await _context.Orders
            .FirstOrDefaultAsync(x =>
                x.Id == orderId &&
                x.CustomerId == userId);

        if (order == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        // Chỉ cho tạo thanh toán khi đơn chưa hoàn tất/hủy
        if (order.Status == OrderStatus.Completed ||
            order.Status == OrderStatus.Cancelled)
        {
            return BadRequest(new
            {
                message =
                    $"Không thể tạo thanh toán cho đơn ở trạng thái {order.Status}."
            });
        }

        // Nếu đã có thanh toán chưa hủy
        var existingPayment = await _context.Payments
            .FirstOrDefaultAsync(x =>
                x.OrderId == orderId &&
                x.Status != PaymentStatus.Failed);

        if (existingPayment != null)
        {
            return BadRequest(new
            {
                message = "Đơn hàng đã có thanh toán.",
                paymentId = existingPayment.Id,
                status = existingPayment.Status.ToString()
            });
        }

        if (!Enum.TryParse<PaymentMethod>(
                request.Method,
                true,
                out var method))
        {
            return BadRequest(new
            {
                message =
                    "Phương thức thanh toán không hợp lệ " +
                    "(Cash, MoMo, BankTransfer)."
            });
        }

        var payment = new Payment
        {
            OrderId = orderId,
            Method = method,
            Status = PaymentStatus.Pending,
            Amount = order.TotalAmount,
            CreatedAt = DateTime.UtcNow
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
    // Shipper/admin/staff xác nhận đã thu tiền
    // ============================================================

    [HttpPost("order/{orderId}/confirm")]
    [Authorize(Roles = "Shipper,Admin,Staff")]
    public async Task<IActionResult> ConfirmPayment(
        int orderId,
        ConfirmPaymentRequest request)
    {
        var userId = GetCurrentUserId();

        var role = GetCurrentUserRole();

        if (userId == null)
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var payment = await _context.Payments
            .Include(x => x.Order)
            .FirstOrDefaultAsync(x => x.OrderId == orderId);

        if (payment == null)
        {
            return NotFound(new
            {
                message = "Đơn hàng chưa có thanh toán."
            });
        }

        // Shipper chỉ được xác nhận đơn mình giao
        if (role == "Shipper" &&
            payment.Order!.ShipperId != userId)
        {
            return Forbid();
        }

        if (payment.Status == PaymentStatus.Paid)
        {
            return BadRequest(new
            {
                message = "Thanh toán đã được xác nhận trước đó."
            });
        }

        if (payment.Status == PaymentStatus.Refunded)
        {
            return BadRequest(new
            {
                message = "Thanh toán đã bị hoàn tiền, không thể xác nhận."
            });
        }

        payment.Status = PaymentStatus.Paid;
        payment.PaidAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Xác nhận thanh toán thành công.",
            paymentId = payment.Id,
            orderId = payment.OrderId,
            status = payment.Status.ToString(),
            paidAt = payment.PaidAt,
            note = request.Note
        });
    }

    // ============================================================
    // POST: api/Payments/order/{orderId}/refund
    // Admin hoàn tiền
    // ============================================================

    [HttpPost("order/{orderId}/refund")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> RefundPayment(int orderId)
    {
        var payment = await _context.Payments
            .FirstOrDefaultAsync(x => x.OrderId == orderId);

        if (payment == null)
        {
            return NotFound(new
            {
                message = "Đơn hàng chưa có thanh toán."
            });
        }

        if (payment.Status != PaymentStatus.Paid)
        {
            return BadRequest(new
            {
                message =
                    "Chỉ có thể hoàn tiền cho thanh toán đã ở trạng thái Paid."
            });
        }

        payment.Status = PaymentStatus.Refunded;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Hoàn tiền thành công.",
            paymentId = payment.Id,
            orderId = payment.OrderId,
            status = payment.Status.ToString()
        });
    }
}
