using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Hubs;
using WashSmart.API.Models;
using WashSmart.API.Services;

namespace WashSmart.API.Controllers;

public class RefundPaymentRequest
{
    public decimal? Amount { get; set; }
    public string? Reason { get; set; }
    public int? ComplaintId { get; set; }
}

public class BankTransactionWebhookRequest
{
    public int? Id { get; set; }
    public string? Gateway { get; set; }
    public string? TransactionDate { get; set; }
    public string? AccountNumber { get; set; }
    public string? SubAccount { get; set; }
    public decimal? AmountIn { get; set; }
    public decimal? AmountOut { get; set; }
    public decimal? TransferAmount { get; set; }
    public string? Code { get; set; }
    public string? TransactionContent { get; set; }
    public string? Content { get; set; }
    public string? ReferenceNumber { get; set; }
    public string? Body { get; set; }
}

public class StatementItemDto
{
    public string? ReferenceNo { get; set; }
    public decimal Amount { get; set; }
    public string Description { get; set; } = string.Empty;
    public string? TransactionDate { get; set; }
}

public class ReconcileStatementRequest
{
    public List<StatementItemDto>? Transactions { get; set; }
    public string? RawStatementText { get; set; }
}

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IHubContext<OrderNotificationHub> _hubContext;
    private readonly IWebHostEnvironment _env;

    public PaymentsController(
        ApplicationDbContext context,
        IHubContext<OrderNotificationHub> hubContext,
        IWebHostEnvironment env)
    {
        _context = context;
        _hubContext = hubContext;
        _env = env;
    }

    private StoreConfig LoadStoreConfig()
    {
        return _context.StoreConfigs.AsNoTracking().FirstOrDefault(c => c.Id == 1) ?? new StoreConfig();
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

        // Phát thông báo thời gian thực qua SignalR Hub
        try
        {
            await _hubContext.Clients.All.SendAsync("PaymentConfirmed", new { orderId = payment.OrderId, amount = payment.Amount });
            await _hubContext.Clients.All.SendAsync("DashboardStatsUpdated");
        }
        catch { }

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

        try
        {
            await _hubContext.Clients.All.SendAsync("DashboardStatsUpdated");
        }
        catch { }

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

    // ============================================================
    // GET: api/Payments/vietqr/{orderId}
    // Sinh mã VietQR chuẩn EMVCo khóa cứng số tiền và mã đơn hàng #WS3T-XXXX
    // ============================================================
    [HttpGet("vietqr/{orderId}")]
    public async Task<IActionResult> GetVietQr(int orderId)
    {
        var userId = GetCurrentUserId();
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

        var cfg = LoadStoreConfig();
        var orderCode = $"#WS3T-{order.Id:D4}";
        var qrResult = VietQrService.GenerateVietQr(
            cfg.BankBin,
            cfg.BankAccountNo,
            cfg.BankAccountHolder,
            order.TotalAmount,
            orderCode
        );

        return Ok(new
        {
            orderId = order.Id,
            orderCode,
            amount = order.TotalAmount,
            emvCoString = qrResult.EmvCoString,
            qrImageUrl = qrResult.QrImageUrl,
            bankBin = qrResult.BankBin,
            bankAccountNo = qrResult.BankAccountNo,
            bankAccountHolder = qrResult.BankAccountHolder
        });
    }

    // ============================================================
    // POST: api/Payments/webhook
    // Cổng nhận Webhook tự động từ Ngân Hàng / SePay / Casso / MBBank
    // Đối soát tự động nội dung chuyển khoản chứa mã đơn #WS3T-XXXX
    // ============================================================
    [HttpPost("webhook")]
    [AllowAnonymous]
    public async Task<IActionResult> ProcessBankWebhook([FromBody] BankTransactionWebhookRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { message = "Dữ liệu webhook rỗng." });
        }

        var content = $"{request.Content} {request.TransactionContent} {request.Body} {request.Code}".Trim();
        var amount = request.AmountIn ?? request.TransferAmount ?? 0;

        // Trích xuất mã đơn hàng dạng #WS3T-XXXX hoặc WS3TXXXX
        var match = Regex.Match(content, @"(?:WS3T|#WS3T-?)\s*(\d+)", RegexOptions.IgnoreCase);
        if (!match.Success)
        {
            return Ok(new
            {
                success = false,
                matched = false,
                message = "Nội dung giao dịch không chứa mã đơn hợp lệ #WS3T-XXXX. Đã ghi nhận log."
            });
        }

        var orderIdStr = match.Groups[1].Value;
        if (!int.TryParse(orderIdStr, out var orderId))
        {
            return Ok(new { success = false, matched = false, message = "Mã đơn hàng không đúng định dạng số." });
        }

        var order = await _context.Orders.FirstOrDefaultAsync(o => o.Id == orderId);
        if (order == null)
        {
            return Ok(new { success = false, matched = false, message = $"Không tìm thấy đơn hàng #{orderId} trong hệ thống." });
        }

        var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderId == orderId);
        if (payment == null)
        {
            payment = new Payment
            {
                OrderId = orderId,
                Amount = order.TotalAmount,
                Method = PaymentMethod.BankTransfer,
                Status = PaymentStatus.Pending,
                CreatedAt = DateTime.UtcNow
            };
            _context.Payments.Add(payment);
        }

        if (payment.Status == PaymentStatus.Paid)
        {
            return Ok(new { success = true, matched = true, orderId, message = $"Đơn hàng #{orderId} đã được thanh toán trước đó." });
        }

        // Cập nhật thanh toán thành công
        payment.Status = PaymentStatus.Paid;
        payment.PaidAt = DateTime.UtcNow;
        var refCode = request.ReferenceNumber ?? request.Code ?? "WEBHOOK";
        payment.PaymentNote = $"Đối soát tự động qua Webhook ({request.Gateway ?? "Bank"} Ref#{refCode}, {amount:N0}đ): {content}";

        await _context.SaveChangesAsync();

        // Bắn tín hiệu SignalR cập nhật tức thì tới Dashboard & Web POS
        try
        {
            await _hubContext.Clients.All.SendAsync("PaymentConfirmed", new { orderId = order.Id, amount = payment.Amount });
            await _hubContext.Clients.All.SendAsync("DashboardStatsUpdated");
        }
        catch { }

        return Ok(new
        {
            success = true,
            matched = true,
            orderId = order.Id,
            reconciledAmount = amount,
            message = $"Khớp lệnh và đối soát thành công đơn hàng #{order.Id} ({amount:N0}đ)!"
        });
    }

    // ============================================================
    // POST: api/Payments/reconcile-statement
    // Đối soát tự động hàng loạt từ Sao kê ngân hàng (CSV / JSON / Text)
    // ============================================================
    [HttpPost("reconcile-statement")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> ReconcileStatement([FromBody] ReconcileStatementRequest request)
    {
        var matchedList = new List<object>();
        var unmatchedList = new List<string>();
        decimal totalReconciled = 0;

        var items = request.Transactions ?? new List<StatementItemDto>();

        // Nếu client gửi text thô từ file sao kê ngân hàng
        if (!string.IsNullOrWhiteSpace(request.RawStatementText) && !items.Any())
        {
            var lines = request.RawStatementText.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (var line in lines)
            {
                var match = Regex.Match(line, @"(?:WS3T|#WS3T-?)\s*(\d+)", RegexOptions.IgnoreCase);
                if (match.Success)
                {
                    // Tìm số tiền trong dòng
                    var amountMatch = Regex.Match(line, @"(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?)");
                    decimal parsedAmt = 0;
                    if (amountMatch.Success)
                    {
                        var cleanStr = amountMatch.Value.Replace(".", "").Replace(",", "");
                        decimal.TryParse(cleanStr, out parsedAmt);
                    }
                    items.Add(new StatementItemDto
                    {
                        Description = line,
                        Amount = parsedAmt,
                        ReferenceNo = $"STMT-{Guid.NewGuid().ToString()[..8]}"
                    });
                }
            }
        }

        foreach (var item in items)
        {
            var match = Regex.Match(item.Description, @"(?:WS3T|#WS3T-?)\s*(\d+)", RegexOptions.IgnoreCase);
            if (!match.Success)
            {
                unmatchedList.Add(item.Description);
                continue;
            }

            if (!int.TryParse(match.Groups[1].Value, out var orderId))
            {
                unmatchedList.Add(item.Description);
                continue;
            }

            var order = await _context.Orders.FirstOrDefaultAsync(o => o.Id == orderId);
            if (order == null)
            {
                unmatchedList.Add($"Không tìm thấy đơn #{orderId}: {item.Description}");
                continue;
            }

            var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderId == orderId);
            if (payment == null)
            {
                payment = new Payment
                {
                    OrderId = orderId,
                    Amount = order.TotalAmount,
                    Method = PaymentMethod.BankTransfer,
                    Status = PaymentStatus.Pending,
                    CreatedAt = DateTime.UtcNow
                };
                _context.Payments.Add(payment);
            }

            if (payment.Status != PaymentStatus.Paid)
            {
                payment.Status = PaymentStatus.Paid;
                payment.PaidAt = DateTime.UtcNow;
                payment.PaymentNote = $"Đối soát tự động từ sao kê: {item.Description}";
                totalReconciled += payment.Amount;
                matchedList.Add(new { orderId = order.Id, amount = payment.Amount, note = payment.PaymentNote });
            }
        }

        await _context.SaveChangesAsync();

        if (matchedList.Any())
        {
            try
            {
                await _hubContext.Clients.All.SendAsync("DashboardStatsUpdated");
            }
            catch { }
        }

        return Ok(new
        {
            message = $"Đối soát hoàn tất: Khớp {matchedList.Count} đơn, tổng tiền {totalReconciled:N0}đ.",
            matchedCount = matchedList.Count,
            totalReconciledAmount = totalReconciled,
            matchedOrders = matchedList,
            unmatchedCount = unmatchedList.Count,
            unmatchedEntries = unmatchedList
        });
    }
}
