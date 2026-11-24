using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.Models;
using WashSmart.API.Services;

namespace WashSmart.API.Controllers;

public class CreateComplaintRequest
{
    public int? OrderId { get; set; }
    public string? CustomerName { get; set; }
    public string? CustomerPhone { get; set; }
    public string? IncidentType { get; set; }
    public string? Severity { get; set; }
    public string ItemDescription { get; set; } = string.Empty;
    public string? PhotoUrl { get; set; }
    public string? CustomerNote { get; set; }
    public decimal? RequestedRefund { get; set; }
}

public class ResolveComplaintRequest
{
    public string? Resolution { get; set; }
    public decimal? ApprovedAmount { get; set; }
    public string? StaffNote { get; set; }
    public int? AssignedShipperId { get; set; }
    public string? VoucherCode { get; set; }
    public decimal? VoucherAmount { get; set; }
}

[ApiController]
[Route("api/[controller]")]
[Authorize] // BẮT BUỘC ĐĂNG NHẬP CHO TOÀN BỘ ENDPOINTS KHIẾU NẠI
public class ComplaintsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public ComplaintsController(ApplicationDbContext context)
    {
        _context = context;
    }

    private (int? userId, string role, string phone, string name) GetCurrentUser()
    {
        var idStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
        int? userId = int.TryParse(idStr, out var id) ? id : null;
        var role = User.FindFirstValue(ClaimTypes.Role) ?? "Customer";
        var phone = User.FindFirstValue(ClaimTypes.MobilePhone) ?? "";
        var name = User.FindFirstValue(ClaimTypes.Name) ?? "";
        return (userId, role, phone, name);
    }

    // ============================================================
    // GET: api/Complaints
    // Admin/Staff: Xem tất cả khiếu nại của hệ thống.
    // Customer/Shipper: Chỉ xem khiếu nại của chính mình (chống rò rỉ PII).
    // ============================================================
    [HttpGet]
    public async Task<IActionResult> GetComplaints([FromQuery] string? status, [FromQuery] string? search)
    {
        var (userId, role, phone, _) = GetCurrentUser();

        var query = _context.Complaints
            .Include(c => c.Customer)
            .Include(c => c.Order)
            .AsNoTracking()
            .AsQueryable();

        // Phân quyền dữ liệu: Customer chỉ xem khiếu nại do mình gửi
        if (role != "Admin" && role != "Staff")
        {
            query = query.Where(c => (c.CustomerId.HasValue && c.CustomerId == userId) ||
                                     (!string.IsNullOrEmpty(phone) && c.Customer != null && c.Customer.Phone == phone));
        }

        if (!string.IsNullOrWhiteSpace(status) && status.ToLower() != "all")
        {
            var s = status.Trim().ToLower();
            if (s == "pending")
                query = query.Where(c => c.Status == "Pending" || c.Status == "Chờ xử lý");
            else if (s == "completed")
                query = query.Where(c => c.Status == "Completed" || c.Status == "Approved" || c.Status == "Rejected" || c.Status == "Đã hoàn tất");
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.ToLower().Trim();
            query = query.Where(c =>
                c.TicketCode.ToLower().Contains(s) ||
                (c.Customer != null && c.Customer.FullName.ToLower().Contains(s)) ||
                (c.Customer != null && c.Customer.Phone.Contains(s)) ||
                c.OrderCode.ToLower().Contains(s) ||
                c.ItemDescription.ToLower().Contains(s));
        }

        var list = await query
            .OrderByDescending(c => c.CreatedAt)
            .Select(c => new
            {
                id = c.Id,
                ticketCode = c.TicketCode,
                userId = c.CustomerId,
                orderId = c.OrderId,
                orderCode = c.OrderCode,
                customerName = c.Customer != null ? c.Customer.FullName : "Khách hàng",
                customerPhone = c.Customer != null ? c.Customer.Phone : "",
                incidentType = c.IncidentType,
                severity = c.Severity,
                itemDescription = c.ItemDescription,
                photoUrl = c.PhotoUrl ?? "",
                customerNote = c.CustomerNote ?? "",
                requestedRefund = c.RequestedRefund,
                approvedAmount = c.ApprovedAmount,
                status = c.Status,
                resolution = c.Resolution,
                staffNote = c.StaffNote,
                resolvedBy = c.ResolvedBy,
                resolvedAt = c.ResolvedAt.HasValue ? c.ResolvedAt.Value.ToString("o") : null,
                sealCode = c.SealCode ?? (c.OrderId.HasValue ? $"WS-SEAL-{c.OrderId.Value:D4}" : "WS-SEAL-TRỰC TIẾP"),
                sealStatus = c.SealStatus ?? "Intact",
                drumInfo = c.DrumInfo ?? "Lồng giặt sấy thông minh LG Turbo #02",
                shipperName = c.ShipperName ?? "Shipper giao nhận WashSmart 3T",
                orderTotal = c.Order != null ? c.Order.TotalAmount : 0,
                createdAt = c.CreatedAt.ToString("o")
            })
            .ToListAsync();

        return Ok(list);
    }

    // ============================================================
    // GET: api/Complaints/{id}
    // Lấy chi tiết khiếu nại (có kiểm tra quyền sở hữu).
    // ============================================================
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var (userId, role, phone, _) = GetCurrentUser();

        var item = await _context.Complaints
            .Include(c => c.Customer)
            .Include(c => c.Order)
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == id);

        if (item == null) return NotFound(new { message = "Không tìm thấy khiếu nại." });

        // Kiểm tra quyền: nếu là Customer thì phải là chủ khiếu nại
        if (role != "Admin" && role != "Staff")
        {
            var isOwner = (item.CustomerId.HasValue && item.CustomerId == userId) ||
                          (!string.IsNullOrEmpty(phone) && item.Customer != null && item.Customer.Phone == phone);
            if (!isOwner)
            {
                return Forbid();
            }
        }

        return Ok(new
        {
            id = item.Id,
            ticketCode = item.TicketCode,
            userId = item.CustomerId,
            orderId = item.OrderId,
            orderCode = item.OrderCode,
            customerName = item.Customer?.FullName ?? "Khách hàng",
            customerPhone = item.Customer?.Phone ?? "",
            incidentType = item.IncidentType,
            severity = item.Severity,
            itemDescription = item.ItemDescription,
            photoUrl = item.PhotoUrl ?? "",
            customerNote = item.CustomerNote ?? "",
            requestedRefund = item.RequestedRefund,
            approvedAmount = item.ApprovedAmount,
            status = item.Status,
            resolution = item.Resolution,
            staffNote = item.StaffNote,
            resolvedBy = item.ResolvedBy,
            resolvedAt = item.ResolvedAt.HasValue ? item.ResolvedAt.Value.ToString("o") : null,
            sealCode = item.SealCode,
            sealStatus = item.SealStatus,
            drumInfo = item.DrumInfo,
            shipperName = item.ShipperName,
            orderTotal = item.Order?.TotalAmount ?? 0,
            createdAt = item.CreatedAt.ToString("o")
        });
    }

    // ============================================================
    // POST: api/Complaints
    // Tạo khiếu nại mới lưu trực tiếp vào CSDL SQL Server:
    // 1. Gắn trực tiếp với CustomerId của người dùng đang đăng nhập.
    // 2. Nếu có OrderId, xác thực đơn hàng tồn tại và thuộc về người dùng này.
    // 3. Sử dụng DateTime.UtcNow để tạo TicketCode chuẩn KN-yyyyMMdd-XXX.
    // ============================================================
    [HttpPost]
    public async Task<IActionResult> CreateComplaint([FromBody] CreateComplaintRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.ItemDescription))
        {
            return BadRequest(new { message = "Vui lòng nhập mô tả món đồ sự cố." });
        }

        var (userId, role, phone, name) = GetCurrentUser();
        if (userId == null)
        {
            return Unauthorized(new { message = "Phiên làm việc không hợp lệ." });
        }

        // Lấy thông tin tài khoản người dùng từ DB
        var userInDb = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId.Value);
        var effectiveName = !string.IsNullOrWhiteSpace(userInDb?.FullName) ? userInDb.FullName : (name ?? "Khách hàng");
        var effectivePhone = !string.IsNullOrWhiteSpace(userInDb?.Phone) ? userInDb.Phone : phone;

        // Nếu có OrderId, kiểm tra đơn hàng và quyền sở hữu đơn hàng
        string orderCode = "#WS3T-TRỰC TIẾP";
        string sealCode = "WS-SEAL-TRỰC TIẾP";
        string sealStatus = "Intact";
        string drumInfo = "Lồng giặt sấy thông minh LG Turbo #02";
        string shipperName = "Giao nhận tại quầy";

        if (request.OrderId.HasValue && request.OrderId.Value > 0)
        {
            var order = await _context.Orders
                .Include(o => o.Shipper)
                .AsNoTracking()
                .FirstOrDefaultAsync(o => o.Id == request.OrderId.Value);
            if (order == null)
            {
                return BadRequest(new { message = $"Không tìm thấy đơn hàng mã #{request.OrderId.Value}." });
            }

            // Customer chỉ được khiếu nại đơn hàng của chính mình
            if (role != "Admin" && role != "Staff" && order.CustomerId != userId.Value)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    message = "Bạn không có quyền gửi khiếu nại cho đơn hàng của khách hàng khác."
                });
            }

            // 🚀 QUY TẮC BẢO HIỂM 3T CARE: Chỉ tiếp nhận khiếu nại trong vòng 60 phút sau khi giao hàng thành công
            if (role != "Admin" && role != "Staff")
            {
                if (order.Status == OrderStatus.Completed)
                {
                    var historyCompleted = await _context.OrderStatusHistories
                        .Where(h => h.OrderId == order.Id && h.Status == OrderStatus.Completed)
                        .OrderByDescending(h => h.ChangedAt)
                        .FirstOrDefaultAsync();

                    var completionTime = historyCompleted?.ChangedAt ?? order.UpdatedAt ?? order.CreatedAt;
                    var elapsed = DateTime.UtcNow - completionTime;
                    if (elapsed.TotalMinutes > 60)
                    {
                        var minutesPassed = (int)Math.Round(elapsed.TotalMinutes);
                        return BadRequest(new
                        {
                            message = $"Đơn hàng đã giao thành công được {minutesPassed} phút. Thời hạn tiếp nhận khiếu nại trực tuyến tối đa là 60 phút kể từ lúc nhận đồ sạch (để đối soát niêm phong seal). Quý khách vui lòng liên hệ Hotline 1900 3T3T (0818.605.505) để được chuyên viên hỗ trợ trực tiếp."
                        });
                    }
                }
            }

            orderCode = $"#WS3T-{order.Id:D4}";
            sealCode = !string.IsNullOrWhiteSpace(order.SealCode) ? order.SealCode : $"WS-SEAL-{order.Id:D4}";
            sealStatus = !string.IsNullOrWhiteSpace(order.SealStatus) ? order.SealStatus : "Intact";
            drumInfo = !string.IsNullOrWhiteSpace(order.DrumCode) ? order.DrumCode : "Lồng giặt sấy thông minh LG Turbo #02";
            shipperName = order.Shipper != null ? $"{order.Shipper.FullName} ({order.Shipper.Phone})" : "Shipper giao nhận WashSmart 3T";
        }

        // Tạo mã ticket dựa trên DateTime.UtcNow
        var todayPrefix = $"KN-{DateTime.UtcNow:yyyyMMdd}";
        var todayCount = await _context.Complaints.CountAsync(c => c.TicketCode.StartsWith(todayPrefix));
        var ticketCode = $"{todayPrefix}-{(todayCount + 1):D3}";

        var ticket = new Complaint
        {
            TicketCode = ticketCode,
            CustomerId = userId.Value,
            OrderId = request.OrderId,
            OrderCode = orderCode,
            IncidentType = string.IsNullOrWhiteSpace(request.IncidentType) ? "Hỏng / Rách vải" : request.IncidentType.Trim(),
            Severity = request.Severity ?? "Medium",
            ItemDescription = request.ItemDescription.Trim(),
            PhotoUrl = request.PhotoUrl ?? "",
            CustomerNote = request.CustomerNote ?? "",
            RequestedRefund = request.RequestedRefund ?? 0,
            Status = "Pending",
            SealCode = sealCode,
            SealStatus = sealStatus,
            DrumInfo = drumInfo,
            ShipperName = shipperName,
            CreatedAt = DateTime.UtcNow
        };

        _context.Complaints.Add(ticket);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Gửi khiếu nại thành công! Chuyên viên bảo hiểm sẽ phản hồi trong vòng 15 phút.",
            complaint = new
            {
                id = ticket.Id,
                ticketCode = ticket.TicketCode,
                orderId = ticket.OrderId,
                orderCode = ticket.OrderCode,
                customerName = effectiveName,
                customerPhone = effectivePhone,
                incidentType = ticket.IncidentType,
                severity = ticket.Severity,
                itemDescription = ticket.ItemDescription,
                photoUrl = ticket.PhotoUrl,
                customerNote = ticket.CustomerNote,
                requestedRefund = ticket.RequestedRefund,
                status = ticket.Status,
                sealCode = ticket.SealCode,
                sealStatus = ticket.SealStatus,
                drumInfo = ticket.DrumInfo,
                shipperName = ticket.ShipperName,
                createdAt = ticket.CreatedAt.ToString("o")
            }
        });
    }

    // ============================================================
    // PUT: api/Complaints/{id}/resolve
    // Chỉ Quản trị viên (Admin) hoặc Nhân viên cửa hàng (Staff) mới được duyệt bồi hoàn.
    // LƯU Ý BẢO MẬT: ResolvedBy được lấy tự động từ tài khoản nhân viên đang đăng nhập.
    // ============================================================
    [HttpPut("{id}/resolve")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> ResolveComplaint(int id, [FromBody] ResolveComplaintRequest request)
    {
        var (currentUserId, role, _, staffName) = GetCurrentUser();
        if (string.IsNullOrWhiteSpace(staffName))
        {
            staffName = role == "Admin" ? "Quản trị viên" : "Nhân viên tiếp nhận";
        }

        var item = await _context.Complaints
            .Include(c => c.Customer)
            .FirstOrDefaultAsync(c => c.Id == id);

        if (item == null) return NotFound(new { message = "Không tìm thấy hồ sơ khiếu nại." });

        var amount = request.ApprovedAmount ?? item.RequestedRefund;
        if (amount < 0)
        {
            return BadRequest(new { message = "Số tiền bồi hoàn không hợp lệ." });
        }

        item.Status = "Completed";
        item.Resolution = request.Resolution ?? "Approved";
        item.ApprovedAmount = amount;
        item.StaffNote = request.StaffNote ?? "Đã giải quyết theo quy chuẩn bảo hành WashSmart 3T.";
        item.ResolvedAt = DateTime.UtcNow;
        item.ResolvedBy = staffName;
        item.UpdatedAt = DateTime.UtcNow;

        var resLower = (item.Resolution ?? "").ToLower();

        // ================================================================
        // 1. PHƯƠNG ÁN 1: GIẶT & PHỤC HỒI MIỄN PHÍ -> TẠO ĐƠN & GÁN SHIPPER ĐI LẤY ĐỒ
        // ================================================================
        int? createdRewashOrderId = null;
        if (resLower.Contains("giặt") || resLower.Contains("phục hồi") || resLower.Contains("rewash"))
        {
            var originalOrder = item.OrderId.HasValue && item.OrderId.Value > 0
                ? await _context.Orders.Include(o => o.OrderDetails).FirstOrDefaultAsync(o => o.Id == item.OrderId.Value)
                : null;

            User? assignedShipper = null;
            if (request.AssignedShipperId.HasValue && request.AssignedShipperId.Value > 0)
            {
                assignedShipper = await _context.Users.FirstOrDefaultAsync(u => u.Id == request.AssignedShipperId.Value);
            }

            var pickupAddr = originalOrder?.DeliveryAddress ?? originalOrder?.PickupAddress ?? item.Customer?.Address ?? "140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP.HCM";
            var deliveryAddr = originalOrder?.DeliveryAddress ?? originalOrder?.PickupAddress ?? item.Customer?.Address ?? "140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP.HCM";
            var phone = item.Customer?.Phone ?? originalOrder?.ContactPhone ?? "";

            var rewashOrder = new Order
            {
                CustomerId = item.CustomerId ?? (originalOrder?.CustomerId ?? 1),
                OrderType = "HomeDelivery",
                PickupAddress = pickupAddr,
                DeliveryAddress = deliveryAddr,
                ContactPhone = phone,
                Note = $"[BẢO HÀNH 3T CARE - GIẶT PHỤC HỒI] Sự cố #{item.TicketCode}: {item.ItemDescription}. Đơn gốc: #{item.OrderCode}. Ghi chú: {request.StaffNote}",
                TotalAmount = 0,
                ShippingFee = 0,
                AddonFee = 0,
                DiscountAmount = 0,
                PaymentMethod = "FreeWarranty",
                ShipperId = assignedShipper?.Id,
                Status = assignedShipper != null ? OrderStatus.PickingUp : OrderStatus.Confirmed,
                SealCode = $"WS-SEAL-{item.TicketCode.Replace("-", "")}",
                SealStatus = "Intact",
                DrumCode = "Lồng giặt sấy chuyên sâu 3T Care",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _context.Orders.Add(rewashOrder);
            await _context.SaveChangesAsync();

            createdRewashOrderId = rewashOrder.Id;

            // Thêm dịch vụ giặt lại miễn phí
            if (originalOrder != null && originalOrder.OrderDetails.Any())
            {
                foreach (var od in originalOrder.OrderDetails)
                {
                    _context.OrderDetails.Add(new OrderDetail
                    {
                        OrderId = rewashOrder.Id,
                        ServiceId = od.ServiceId,
                        Quantity = od.Quantity,
                        Unit = od.Unit,
                        UnitPrice = 0,
                        TotalPrice = 0
                    });
                }
            }
            else
            {
                var defaultService = await _context.Services.FirstOrDefaultAsync(s => s.IsActive);
                if (defaultService != null)
                {
                    _context.OrderDetails.Add(new OrderDetail
                    {
                        OrderId = rewashOrder.Id,
                        ServiceId = defaultService.Id,
                        Quantity = 1,
                        Unit = "gói",
                        UnitPrice = 0,
                        TotalPrice = 0
                    });
                }
            }

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = rewashOrder.Id,
                Status = rewashOrder.Status,
                Note = assignedShipper != null
                    ? $"[Bảo hành 3T Care] Khởi tạo đơn giặt lại miễn phí 0đ theo khiếu nại #{item.TicketCode}. Gán cho Shipper {assignedShipper.FullName} ({assignedShipper.Phone}) đi lấy lại đồ."
                    : $"[Bảo hành 3T Care] Khởi tạo đơn giặt lại miễn phí 0đ theo khiếu nại #{item.TicketCode}. Chờ điều phối shipper.",
                ChangedByUserId = currentUserId,
                ChangedAt = DateTime.UtcNow
            });

            if (originalOrder != null)
            {
                _context.OrderStatusHistories.Add(new OrderStatusHistory
                {
                    OrderId = originalOrder.Id,
                    Status = originalOrder.Status,
                    Note = $"[Khiếu nại #{item.TicketCode}] Đã lập đơn giặt phục hồi bảo hành #WS3T-{rewashOrder.Id:D4} cho khách.",
                    ChangedByUserId = currentUserId,
                    ChangedAt = DateTime.UtcNow
                });
            }

            item.StaffNote = (request.StaffNote ?? "") + $" (Đã tạo đơn lấy đồ giặt lại #WS3T-{rewashOrder.Id:D4}" + (assignedShipper != null ? $" - Gán Shipper: {assignedShipper.FullName}" : "") + ").";
        }

        // ================================================================
        // 2. PHƯƠNG ÁN 2: HOÀN TIỀN DỊCH VỤ GIẶT -> CẬP NHẬT PAYMENT & LỊCH SỬ KẾ TOÁN
        // ================================================================
        if (resLower.Contains("hoàn tiền") || resLower.Contains("refund"))
        {
            if (item.OrderId.HasValue && item.OrderId.Value > 0)
            {
                var originalOrder = await _context.Orders.FirstOrDefaultAsync(o => o.Id == item.OrderId.Value);
                var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderId == item.OrderId.Value);
                if (payment != null)
                {
                    payment.RefundedAmount = amount > 0 ? amount : payment.Amount;
                    payment.RefundReason = $"Hoàn tiền dịch vụ giặt theo khiếu nại #{item.TicketCode}: {item.IncidentType}";
                    payment.RefundedAt = DateTime.UtcNow;
                    payment.RefundedBy = staffName;
                    payment.ComplaintId = item.Id;
                    payment.Status = PaymentStatus.Refunded;
                }
                else if (originalOrder != null)
                {
                    payment = new Payment
                    {
                        OrderId = originalOrder.Id,
                        Amount = originalOrder.TotalAmount,
                        RefundedAmount = amount > 0 ? amount : originalOrder.TotalAmount,
                        Method = originalOrder.PaymentMethod == "VietQR" ? PaymentMethod.BankTransfer : PaymentMethod.Cash,
                        Status = PaymentStatus.Refunded,
                        PaidAt = originalOrder.CreatedAt,
                        RefundedAt = DateTime.UtcNow,
                        RefundedBy = staffName,
                        RefundReason = $"Hoàn tiền dịch vụ giặt theo khiếu nại #{item.TicketCode}",
                        ComplaintId = item.Id,
                        CreatedAt = DateTime.UtcNow
                    };
                    _context.Payments.Add(payment);
                }

                if (originalOrder != null)
                {
                    _context.OrderStatusHistories.Add(new OrderStatusHistory
                    {
                        OrderId = originalOrder.Id,
                        Status = originalOrder.Status,
                        Note = $"[Hoàn tiền sự cố #{item.TicketCode}] Đã hoàn {amount:N0} VNĐ tiền dịch vụ giặt cho khách hàng ({staffName}).",
                        ChangedByUserId = currentUserId,
                        ChangedAt = DateTime.UtcNow
                    });
                }
            }
        }

        // ================================================================
        // 3. PHƯƠNG ÁN 3: TẶNG VOUCHER ĐỀN BÙ -> PHÁT CHÍNH XÁC CHO KHÁCH ĐÓ & CỘNG XU
        // ================================================================
        string? generatedVoucher = null;
        if (resLower.Contains("voucher") || resLower.Contains("xu") || resLower.Contains("point"))
        {
            var voucherVal = request.VoucherAmount.HasValue && request.VoucherAmount.Value > 0
                ? request.VoucherAmount.Value
                : (amount > 0 ? amount : 50000m);

            var custPhone = item.Customer?.Phone ?? "";
            var phoneTail = custPhone.Length >= 4 ? custPhone[^4..] : "CARE";
            var voucherCode = !string.IsNullOrWhiteSpace(request.VoucherCode)
                ? request.VoucherCode.Trim().ToUpperInvariant()
                : $"VIP3T-{phoneTail}-{item.Id:D3}";

            var existingPromo = await _context.Promotions.FirstOrDefaultAsync(p => p.Code == voucherCode);
            if (existingPromo == null)
            {
                var promo = new Promotion
                {
                    Code = voucherCode,
                    Title = $"Voucher Đền Bù 3T Care - {item.Customer?.FullName ?? "Khách hàng"}",
                    Description = $"Ưu đãi đền bù trị giá {voucherVal:N0}đ dành riêng cho quý khách {item.Customer?.FullName} ({custPhone}) theo sự cố #{item.TicketCode}.",
                    DiscountType = "FixedAmount",
                    DiscountValue = voucherVal,
                    MinOrderAmount = 0,
                    UsageLimit = 1,
                    UsedCount = 0,
                    StartDate = DateTime.UtcNow,
                    EndDate = DateTime.UtcNow.AddMonths(6),
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                };
                _context.Promotions.Add(promo);
            }

            generatedVoucher = voucherCode;

            // Đồng thời tặng điểm 3T Xu vào ví App nếu khách đã có tài khoản
            if (item.Customer != null && voucherVal > 0)
            {
                int bonusCoins = (int)(voucherVal / 10m);
                LoyaltyService.CompensatePoints(item.Customer, bonusCoins);
            }

            item.StaffNote = (request.StaffNote ?? "") + $" (Đã phát Voucher riêng mã {voucherCode} trị giá {voucherVal:N0}đ cho khách).";
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Hồ sơ khiếu nại đã được phê duyệt xử lý thành công!",
            complaint = new
            {
                id = item.Id,
                ticketCode = item.TicketCode,
                orderId = item.OrderId,
                orderCode = item.OrderCode,
                customerName = item.Customer?.FullName ?? "Khách hàng",
                customerPhone = item.Customer?.Phone ?? "",
                status = item.Status,
                resolution = item.Resolution,
                approvedAmount = item.ApprovedAmount,
                staffNote = item.StaffNote,
                resolvedBy = item.ResolvedBy,
                resolvedAt = item.ResolvedAt.HasValue ? item.ResolvedAt.Value.ToString("o") : null
            }
        });
    }
}
