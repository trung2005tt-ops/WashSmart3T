using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Models;
using WashSmart.API.Services;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OrdersController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(
        ApplicationDbContext context,
        IWebHostEnvironment env,
        ILogger<OrdersController> logger)
    {
        _context = context;
        _env = env;
        _logger = logger;
    }

    private StoreConfigModel GetStoreConfig()
    {
        var path = Path.Combine(_env.ContentRootPath, "store_config.json");
        if (System.IO.File.Exists(path))
        {
            try
            {
                var json = System.IO.File.ReadAllText(path);
                var cfg = JsonSerializer.Deserialize<StoreConfigModel>(json, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });
                if (cfg != null) return cfg;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Lỗi đọc store_config.json, dùng cấu hình mặc định.");
            }
        }
        return new StoreConfigModel();
    }

    private decimal CalculateShippingFee(double distanceKm, bool isExpress, StoreConfigModel config)
    {
        decimal fee = config.BaseShippingFee;
        if (distanceKm > config.Tier1MaxKm && distanceKm <= config.Tier2MaxKm)
        {
            fee = config.Tier2ShippingFee;
        }
        else if (distanceKm > config.Tier2MaxKm)
        {
            fee = config.Tier3ShippingFee;
        }

        if (isExpress)
        {
            fee += config.ExpressExtraFee;
        }

        return fee;
    }

    // ============================================================
    // GET: api/Orders/management
    // Admin/Staff xem toàn bộ đơn hàng kèm cấu trúc tài chính và thanh toán
    // ============================================================
    [HttpGet("management")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> GetOrdersForManagement()
    {
        try
        {
            var orders = await _context.Orders
                .AsNoTracking()
                .Include(o => o.Customer)
                .Include(o => o.Shipper)
                .Include(o => o.OrderDetails)
                    .ThenInclude(d => d.Service)
                .OrderByDescending(o => o.CreatedAt)
                .Select(o => new
                {
                    o.Id,
                    o.CustomerId,
                    customerName = o.Customer != null ? o.Customer.FullName : "",
                    customerPhone = o.Customer != null ? o.Customer.Phone : o.ContactPhone,

                    o.ShipperId,
                    shipperName = o.Shipper != null ? o.Shipper.FullName : null,

                    status = o.Status.ToString(),
                    o.OrderType,
                    o.PickupAddress,
                    o.DeliveryAddress,
                    o.ContactPhone,
                    o.Note,
                    o.ShippingFee,
                    o.AddonFee,
                    o.DiscountAmount,
                    o.TotalAmount,
                    o.PaymentMethod,
                    o.DeliveryProofPhotoUrl,
                    o.CreatedAt,
                    o.UpdatedAt,

                    paymentStatus = _context.Payments
                        .Where(p => p.OrderId == o.Id)
                        .Select(p => p.Status.ToString())
                        .FirstOrDefault() ?? "Pending",

                    paidAt = _context.Payments
                        .Where(p => p.OrderId == o.Id)
                        .Select(p => p.PaidAt)
                        .FirstOrDefault(),

                    items = o.OrderDetails.Select(d => new
                    {
                        d.ServiceId,
                        serviceName = d.Service != null ? d.Service.Name : "",
                        d.Quantity,
                        d.Unit,
                        d.UnitPrice,
                        d.TotalPrice
                    })
                })
                .ToListAsync();

            return Ok(orders);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi lấy danh sách đơn quản lý.");
            return StatusCode(500, new { message = "Lỗi máy chủ khi lấy danh sách đơn hàng." });
        }
    }

    // ============================================================
    // GET: api/Orders/management/shippers
    // Danh sách shipper cho Admin/Staff phân công (hỗ trợ hiển thị số đơn đang ghép)
    // ============================================================
    [HttpGet("management/shippers")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> GetActiveShippers()
    {
        var shipperUsers = await _context.Users
            .AsNoTracking()
            .Where(u => u.IsActive && u.Role != null && u.Role.Name == "Shipper")
            .OrderBy(u => u.FullName)
            .Select(u => new
            {
                u.Id,
                u.FullName,
                u.Phone
            })
            .ToListAsync();

        var activeStatuses = new[]
        {
            OrderStatus.Confirmed,
            OrderStatus.PickingUp,
            OrderStatus.Ready,
            OrderStatus.Delivering
        };

        var shippers = new List<object>();
        foreach (var shipper in shipperUsers)
        {
            var activeOrders = await _context.Orders
                .AsNoTracking()
                .Where(o => o.ShipperId == shipper.Id && activeStatuses.Contains(o.Status))
                .Select(o => new { o.Id, status = o.Status.ToString() })
                .ToListAsync();

            var currentTask = activeOrders.FirstOrDefault()?.status switch
            {
                "Confirmed" or "PickingUp" => "Lấy đồ",
                "Ready" or "Delivering" => "Giao đồ",
                _ => null
            };

            // Shipper bận khi đã nhận tối đa 5 đơn cùng đợt (ghép tuyến)
            bool isBusy = activeOrders.Count >= 5;

            shippers.Add(new
            {
                shipper.Id,
                shipper.FullName,
                shipper.Phone,
                isBusy,
                activeTaskCount = activeOrders.Count,
                currentOrderId = activeOrders.FirstOrDefault()?.Id,
                currentTask
            });
        }

        return Ok(shippers);
    }

    public class AssignShipperRequest
    {
        public int ShipperId { get; set; }
    }

    // ============================================================
    // POST: api/Orders/{id}/assign-shipper
    // Admin/Staff phân công shipper (cho phép ghép tối đa 5 đơn cùng tuyến)
    // ============================================================
    [HttpPost("{id}/assign-shipper")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> AssignShipper(int id, [FromBody] AssignShipperRequest request)
    {
        if (request.ShipperId <= 0)
        {
            return BadRequest(new { message = "ShipperId không hợp lệ." });
        }

        using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            var order = await _context.Orders.FirstOrDefaultAsync(o => o.Id == id);
            if (order == null)
            {
                return NotFound(new { message = "Không tìm thấy đơn hàng." });
            }

            if (order.Status != OrderStatus.Confirmed && order.Status != OrderStatus.Ready)
            {
                return BadRequest(new
                {
                    message = $"Chỉ phân công đơn ở trạng thái Confirmed hoặc Ready. Trạng thái hiện tại: {order.Status}."
                });
            }

            var shipper = await _context.Users
                .Include(u => u.Role)
                .FirstOrDefaultAsync(u => u.Id == request.ShipperId && u.IsActive && u.Role != null && u.Role.Name == "Shipper");

            if (shipper == null)
            {
                return BadRequest(new { message = "Shipper không tồn tại hoặc đã bị khóa." });
            }

            // HỖ TRỢ GHÉP ĐƠN: Cho phép ghép tối đa 5 đơn cùng đợt
            const int MaxBatchTasks = 5;
            var shipperTaskCount = await _context.Orders.CountAsync(o =>
                o.Id != order.Id &&
                o.ShipperId == shipper.Id &&
                (o.Status == OrderStatus.Confirmed ||
                 o.Status == OrderStatus.PickingUp ||
                 o.Status == OrderStatus.Delivering));

            if (shipperTaskCount >= MaxBatchTasks)
            {
                return Conflict(new
                {
                    message = $"Shipper này đã nhận tối đa {MaxBatchTasks} đơn trong đợt ghép tuyến này. Vui lòng chọn shipper khác."
                });
            }

            order.ShipperId = shipper.Id;
            order.UpdatedAt = DateTime.UtcNow;

            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            int? changedByUserId = int.TryParse(userIdClaim, out var uId) ? uId : null;

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                Status = order.Status,
                Note = $"Phân công shipper: {shipper.FullName} (Đơn thứ {shipperTaskCount + 1} trong tuyến)",
                ChangedByUserId = changedByUserId,
                ChangedAt = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            return Ok(new
            {
                message = "Phân công shipper thành công.",
                orderId = order.Id,
                shipperId = shipper.Id,
                shipperName = shipper.FullName,
                status = order.Status.ToString()
            });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            _logger.LogError(ex, "Lỗi phân công shipper cho đơn {OrderId}.", id);
            return StatusCode(500, new { message = "Lỗi khi phân công shipper." });
        }
    }

    // ============================================================
    // POST: api/Orders
    // Khách hàng tự đặt đơn: Transaction duy nhất, nạp Service một lần (chống N+1),
    // tính phí ship động theo StoreConfig và tạo Payment đồng bộ
    // ============================================================
    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderRequest request)
    {
        if (request.Items == null || request.Items.Count == 0)
        {
            return BadRequest(new { message = "Đơn hàng phải có ít nhất một dịch vụ." });
        }

        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int customerId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var customer = await _context.Users.FirstOrDefaultAsync(x => x.Id == customerId && x.IsActive);
        if (customer == null)
        {
            return Unauthorized(new { message = "Tài khoản không tồn tại hoặc đã bị khóa." });
        }

        using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            // 1. Chuẩn hóa số điện thoại
            var (_, _, cleanPhone) = SmsService.NormalizePhone(!string.IsNullOrWhiteSpace(request.ContactPhone) ? request.ContactPhone : customer.Phone);

            // 2. Tải tất cả dịch vụ trong 1 QUERY DUY NHẤT (Loại bỏ N+1)
            var serviceIds = request.Items.Select(x => x.ServiceId).Distinct().ToList();
            var services = await _context.Services
                .Include(s => s.Prices)
                .Where(s => serviceIds.Contains(s.Id) && s.IsActive)
                .ToDictionaryAsync(s => s.Id);

            decimal subTotal = 0;
            var orderDetails = new List<OrderDetail>();

            foreach (var item in request.Items)
            {
                if (item.Quantity < 0)
                {
                    return BadRequest(new { message = $"Số lượng dịch vụ ID {item.ServiceId} không được âm." });
                }

                if (!services.TryGetValue(item.ServiceId, out var service))
                {
                    return BadRequest(new { message = $"Dịch vụ ID {item.ServiceId} không tồn tại hoặc đã ngưng hoạt động." });
                }

                var currentPrice = service.Prices
                    .Where(p => p.IsActive && p.EffectiveTo == null)
                    .OrderByDescending(p => p.EffectiveFrom)
                    .FirstOrDefault();

                if (currentPrice == null)
                {
                    return BadRequest(new { message = $"Dịch vụ '{service.Name}' chưa có giá." });
                }

                var calculated = item.Quantity * currentPrice.Price;
                var lineTotal = item.Quantity == 0 ? 0 : (currentPrice.MinimumPrice.HasValue ? Math.Max(calculated, currentPrice.MinimumPrice.Value) : calculated);
                var effectiveUnitPrice = item.Quantity > 0 ? lineTotal / item.Quantity : currentPrice.Price;

                orderDetails.Add(new OrderDetail
                {
                    ServiceId = service.Id,
                    Quantity = item.Quantity,
                    UnitPrice = effectiveUnitPrice,
                    Unit = currentPrice.Unit,
                    TotalPrice = lineTotal
                });

                subTotal += lineTotal;
            }

            // 3. Tính phí ship động từ StoreConfig (không bỏ rơi cấu hình)
            var storeConfig = GetStoreConfig();
            var orderType = string.IsNullOrWhiteSpace(request.OrderType) ? "Delivery" : request.OrderType.Trim();
            decimal shippingFee = 0;
            if (orderType == "Delivery")
            {
                if (request.ShippingFee > 0)
                {
                    shippingFee = request.ShippingFee;
                }
                else
                {
                    var distance = request.DistanceKm ?? 2.5;
                    shippingFee = CalculateShippingFee(distance, request.IsExpress, storeConfig);
                }
            }

            // 4. Phụ phí tiện ích (áp trần 500,000đ chống gian lận) và giảm giá
            var addonFee = Math.Min(Math.Max(0, request.AddonFee), 500000m);
            var discountAmount = Math.Max(0, request.DiscountAmount);

            var totalAmount = Math.Max(0, subTotal + shippingFee + addonFee - discountAmount);
            var payMethod = string.IsNullOrWhiteSpace(request.PaymentMethod) ? "COD" : request.PaymentMethod.Trim();

            // 5. Tạo đơn hàng với đầy đủ dữ liệu cấu trúc
            var order = new Order
            {
                CustomerId = customerId,
                OrderType = orderType,
                PickupAddress = request.PickupAddress.Trim(),
                DeliveryAddress = request.DeliveryAddress.Trim(),
                ContactPhone = cleanPhone,
                Note = request.Note,
                ShippingFee = shippingFee,
                AddonFee = addonFee,
                DiscountAmount = discountAmount,
                TotalAmount = totalAmount,
                PaymentMethod = payMethod,
                Status = OrderStatus.Pending,
                CreatedAt = DateTime.UtcNow,
                OrderDetails = orderDetails
            };

            _context.Orders.Add(order);
            await _context.SaveChangesAsync();

            // 6. Lưu lịch sử đơn hàng
            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                Status = OrderStatus.Pending,
                Note = "Đơn hàng được tạo thành công từ ứng dụng",
                ChangedByUserId = customerId,
                ChangedAt = DateTime.UtcNow
            });

            // 7. TẠO BẢN GHI THANH TOÁN ĐỒNG BỘ (DUY NHẤT 1 NGUỒN SỰ THẬT)
            Enum.TryParse<PaymentMethod>(payMethod, true, out var parsedMethod);
            var payment = new Payment
            {
                OrderId = order.Id,
                Amount = totalAmount,
                Method = parsedMethod,
                Status = PaymentStatus.Pending,
                CreatedAt = DateTime.UtcNow,
                PaymentNote = $"Thanh toán cho đơn #{order.Id:D4} qua {payMethod}"
            };
            _context.Payments.Add(payment);

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            return Ok(new
            {
                message = "Tạo đơn hàng thành công.",
                orderId = order.Id,
                status = order.Status.ToString(),
                subTotal = subTotal,
                shippingFee = order.ShippingFee,
                addonFee = order.AddonFee,
                discountAmount = order.DiscountAmount,
                totalAmount = order.TotalAmount,
                paymentMethod = order.PaymentMethod,
                items = order.OrderDetails.Select(x => new
                {
                    x.ServiceId,
                    x.Quantity,
                    x.Unit,
                    x.UnitPrice,
                    x.TotalPrice
                })
            });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            _logger.LogError(ex, "Lỗi tạo đơn hàng cho khách {CustomerId}.", customerId);
            return StatusCode(500, new { message = "Lỗi khi tạo đơn hàng: " + ex.Message });
        }
    }

    // ============================================================
    // POS QUẦY: Tìm khách hàng qua SĐT (chuẩn hóa số)
    // ============================================================
    [HttpGet("pos/customer")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> FindPosCustomer([FromQuery] string phone)
    {
        var (_, _, cleanPhone) = SmsService.NormalizePhone(phone ?? string.Empty);
        if (cleanPhone.Length < 9) return BadRequest(new { message = "Số điện thoại không hợp lệ." });

        var customer = await _context.Users
            .Include(u => u.Role)
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Phone == cleanPhone && u.Role != null && u.Role.Name == "Customer");

        if (customer == null) return Ok(new { found = false });
        return Ok(new { found = true, customer.Id, fullName = customer.FullName, phone = customer.Phone });
    }

    public class PosCreateOrderRequest
    {
        public string CustomerName { get; set; } = string.Empty;
        public string ContactPhone { get; set; } = string.Empty;
        public string PickupAddress { get; set; } = string.Empty;
        public string DeliveryAddress { get; set; } = string.Empty;
        public string DeliveryMethod { get; set; } = "StorePickup";
        public decimal DeliveryFee { get; set; }
        public decimal AddonFee { get; set; }
        public decimal CashReceived { get; set; }
        public string PaymentMethod { get; set; } = "Cash";
        public string PaymentTiming { get; set; } = "PayNow";
        public string? Note { get; set; }
        public double? DistanceKm { get; set; }
        public List<CreateOrderDetailRequest> Items { get; set; } = new();
    }

    // ============================================================
    // POST: api/Orders/pos
    // Tạo đơn tại quầy POS: Quản lý khách vãng lai, tính cước động,
    // lưu đầy đủ cột cấu trúc và hỗ trợ đơn StorePickup có đường hoàn thành trực tiếp!
    // ============================================================
    [HttpPost("pos")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> CreatePosOrder([FromBody] PosCreateOrderRequest request)
    {
        var staffClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (staffClaim == null || !int.TryParse(staffClaim, out var staffId))
            return Unauthorized(new { message = "Không xác định được nhân viên đang đăng nhập." });

        var name = (request.CustomerName ?? string.Empty).Trim();
        var (_, _, cleanPhone) = SmsService.NormalizePhone(request.ContactPhone ?? string.Empty);

        if (name.Length < 2) return BadRequest(new { message = "Vui lòng nhập họ tên khách hàng." });
        if (cleanPhone.Length < 10) return BadRequest(new { message = "Số điện thoại khách hàng không hợp lệ." });
        if (request.Items == null || request.Items.Count == 0) return BadRequest(new { message = "Vui lòng chọn ít nhất một dịch vụ." });

        using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            var customerRole = await _context.Roles.FirstOrDefaultAsync(r => r.Name == "Customer");
            if (customerRole == null) return BadRequest(new { message = "Database chưa có vai trò Customer." });

            var customer = await _context.Users.Include(u => u.Role).FirstOrDefaultAsync(u => u.Phone == cleanPhone);
            if (customer != null && customer.Role?.Name != "Customer")
                return Conflict(new { message = "Số điện thoại này đang được dùng cho tài khoản nhân viên hoặc shipper." });

            if (customer == null)
            {
                // Tạo tài khoản POS vãng lai (có tiền tố nhận diện pos- để khách kích hoạt sau)
                customer = new User
                {
                    FullName = name,
                    Phone = cleanPhone,
                    Email = $"pos-{cleanPhone}@customer.washsmart.local",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString("N")),
                    RoleId = customerRole.Id,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                };
                _context.Users.Add(customer);
                await _context.SaveChangesAsync();
            }
            else if (string.IsNullOrWhiteSpace(customer.FullName) || customer.FullName == cleanPhone)
            {
                customer.FullName = name;
            }

            // Tính phí giao nhận theo cấu hình bậc khoảng cách từ StoreConfig (không hardcode)
            var storeConfig = GetStoreConfig();
            decimal actualDeliveryFee = 0;
            if (request.DeliveryMethod == "HomeDelivery")
            {
                var dist = request.DistanceKm ?? 2.5;
                actualDeliveryFee = CalculateShippingFee(dist, false, storeConfig);
            }

            var addonFee = Math.Min(Math.Max(0, request.AddonFee), 500000m);

            // Nạp dịch vụ trong 1 query duy nhất
            var serviceIds = request.Items.Select(x => x.ServiceId).Distinct().ToList();
            var services = await _context.Services
                .Include(s => s.Prices)
                .Where(s => serviceIds.Contains(s.Id) && s.IsActive)
                .ToDictionaryAsync(s => s.Id);

            decimal subTotal = 0;
            var orderDetails = new List<OrderDetail>();

            foreach (var item in request.Items)
            {
                if (!services.TryGetValue(item.ServiceId, out var service))
                    return BadRequest(new { message = $"Dịch vụ ID {item.ServiceId} không hợp lệ." });

                var price = service.Prices.Where(p => p.IsActive && p.EffectiveTo == null)
                    .OrderByDescending(p => p.EffectiveFrom).FirstOrDefault();

                if (price == null) return BadRequest(new { message = $"Dịch vụ '{service.Name}' chưa có giá." });

                var lineTotal = item.Quantity * price.Price;
                if (price.MinimumPrice.HasValue) lineTotal = Math.Max(lineTotal, price.MinimumPrice.Value);
                var effectiveUnitPrice = item.Quantity > 0 ? lineTotal / item.Quantity : price.Price;

                orderDetails.Add(new OrderDetail
                {
                    ServiceId = service.Id,
                    Quantity = item.Quantity,
                    UnitPrice = effectiveUnitPrice,
                    Unit = price.Unit,
                    TotalPrice = lineTotal
                });

                subTotal += lineTotal;
            }

            var totalAmount = subTotal + actualDeliveryFee + addonFee;

            if (request.PaymentTiming == "PayNow" && request.PaymentMethod == "Cash" && request.CashReceived < totalAmount)
            {
                return BadRequest(new { message = "Tiền mặt khách đưa chưa đủ tổng thanh toán." });
            }

            // Với đơn nhận tại quầy (StorePickup), quần áo đã nằm tại cửa hàng => trạng thái là Received!
            var initialStatus = request.DeliveryMethod == "StorePickup" ? OrderStatus.Received : OrderStatus.Pending;

            var order = new Order
            {
                CustomerId = customer.Id,
                OrderType = request.DeliveryMethod,
                PickupAddress = request.PickupAddress.Trim(),
                DeliveryAddress = request.DeliveryAddress.Trim(),
                ContactPhone = cleanPhone,
                Note = request.Note?.Trim(),
                ShippingFee = actualDeliveryFee,
                AddonFee = addonFee,
                DiscountAmount = 0,
                TotalAmount = totalAmount,
                PaymentMethod = request.PaymentMethod,
                Status = initialStatus,
                CreatedAt = DateTime.UtcNow,
                OrderDetails = orderDetails
            };

            _context.Orders.Add(order);
            await _context.SaveChangesAsync();

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                Status = initialStatus,
                Note = request.DeliveryMethod == "StorePickup" ? "Đơn quầy: Khách gửi đồ trực tiếp tại tiệm (Đã tiếp nhận)" : "Đơn POS tạo chờ xử lý giao nhận",
                ChangedByUserId = staffId,
                ChangedAt = DateTime.UtcNow
            });

            if (!Enum.TryParse<PaymentMethod>(request.PaymentMethod, true, out var parsedPayMethod))
                parsedPayMethod = PaymentMethod.Cash;

            bool isPaidNow = request.PaymentTiming == "PayNow";
            var payment = new Payment
            {
                OrderId = order.Id,
                Method = parsedPayMethod,
                Amount = totalAmount,
                Status = isPaidNow ? PaymentStatus.Paid : PaymentStatus.Pending,
                CreatedAt = DateTime.UtcNow,
                PaidAt = isPaidNow ? DateTime.UtcNow : null,
                PaymentNote = isPaidNow ? $"Đã thanh toán tại quầy qua {request.PaymentMethod}" : "Chờ thanh toán"
            };

            _context.Payments.Add(payment);
            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            return Ok(new
            {
                message = "Tạo đơn POS thành công.",
                orderId = order.Id,
                customerId = customer.Id,
                customerName = customer.FullName,
                customerPhone = customer.Phone,
                status = order.Status.ToString(),
                subTotal,
                shippingFee = order.ShippingFee,
                addonFee = order.AddonFee,
                totalAmount = order.TotalAmount,
                paymentStatus = payment.Status.ToString(),
                items = order.OrderDetails.Select(d => new { d.ServiceId, d.Quantity, d.Unit, d.UnitPrice, d.TotalPrice })
            });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            _logger.LogError(ex, "Lỗi tạo đơn POS tại quầy.");
            return StatusCode(500, new { message = "Lỗi tạo đơn POS: " + ex.Message });
        }
    }

    // ============================================================
    // GET: api/Orders/shipper-orders
    // Shipper xem các đơn được giao cho mình và các đơn đang chờ nhận
    // ============================================================
    [HttpGet("shipper-orders")]
    [Authorize(Roles = "Shipper,Admin,Staff")]
    public async Task<IActionResult> GetShipperOrders()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int shipperId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var orders = await _context.Orders
            .Where(x => (x.ShipperId == null && (x.Status == OrderStatus.Confirmed || x.Status == OrderStatus.Ready)) || x.ShipperId == shipperId)
            .Include(x => x.Customer)
            .Include(x => x.OrderDetails)
                .ThenInclude(x => x.Service)
            .OrderByDescending(x => x.CreatedAt)
            .Select(x => new
            {
                x.Id,
                status = x.Status.ToString(),
                x.OrderType,
                x.CustomerId,
                customerName = x.Customer != null ? x.Customer.FullName : string.Empty,
                customerPhone = x.Customer != null ? x.Customer.Phone : x.ContactPhone,
                x.PickupAddress,
                x.DeliveryAddress,
                x.ContactPhone,
                x.Note,
                x.ShippingFee,
                x.AddonFee,
                x.DiscountAmount,
                x.TotalAmount,
                x.PaymentMethod,
                x.DeliveryProofPhotoUrl,
                x.CreatedAt,
                x.UpdatedAt,
                isAssignedToCurrentShipper = x.ShipperId == shipperId,
                paymentStatus = _context.Payments.Where(p => p.OrderId == x.Id).Select(p => p.Status.ToString()).FirstOrDefault() ?? "Pending",
                items = x.OrderDetails.Select(d => new
                {
                    d.ServiceId,
                    serviceName = d.Service!.Name,
                    d.Quantity,
                    d.Unit,
                    d.UnitPrice,
                    d.TotalPrice
                })
            })
            .ToListAsync();

        return Ok(orders);
    }

    // ============================================================
    // POST: api/Orders/{id}/assign
    // Shipper tự nhận đơn: HỖ TRỢ GHÉP ĐƠN (tối đa 5 đơn cùng tuyến)
    // ============================================================
    [HttpPost("{id}/assign")]
    [Authorize(Roles = "Shipper")]
    public async Task<IActionResult> AssignOrderToShipper(int id)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int shipperId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            var order = await _context.Orders.FirstOrDefaultAsync(x => x.Id == id);
            if (order == null) return NotFound(new { message = "Không tìm thấy đơn hàng." });

            if (order.ShipperId.HasValue && order.ShipperId.Value != shipperId)
            {
                return BadRequest(new { message = "Đơn hàng đã được shipper khác nhận." });
            }

            if (order.Status != OrderStatus.Confirmed && order.Status != OrderStatus.Ready)
            {
                return BadRequest(new { message = $"Không thể nhận đơn ở trạng thái {order.Status}." });
            }

            // HỖ TRỢ GHÉP ĐƠN: Cho phép nhận tối đa 5 nhiệm vụ cùng tuyến
            const int MaxBatchTasks = 5;
            var activeBatchCount = await _context.Orders.CountAsync(x =>
                x.Id != order.Id &&
                x.ShipperId == shipperId &&
                (x.Status == OrderStatus.Confirmed ||
                 x.Status == OrderStatus.PickingUp ||
                 x.Status == OrderStatus.Delivering));

            if (activeBatchCount >= MaxBatchTasks)
            {
                return Conflict(new
                {
                    message = $"Bạn đã nhận tối đa {MaxBatchTasks} đơn trong đợt ghép tuyến này. Vui lòng hoàn tất trước khi nhận thêm đơn mới."
                });
            }

            order.ShipperId = shipperId;
            order.UpdatedAt = DateTime.UtcNow;

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                Status = order.Status,
                Note = $"Shipper nhận nhiệm vụ đơn hàng (Đơn ghép thứ {activeBatchCount + 1})",
                ChangedByUserId = shipperId,
                ChangedAt = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            return Ok(new
            {
                message = "Nhận đơn thành công.",
                orderId = order.Id,
                shipperId,
                status = order.Status.ToString()
            });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            _logger.LogError(ex, "Lỗi khi shipper {ShipperId} nhận đơn {OrderId}.", shipperId, id);
            return StatusCode(500, new { message = "Lỗi nhận đơn hàng." });
        }
    }

    // ============================================================
    // PUT: api/Orders/{id}/pickup-details
    // Shipper cân đo tại chỗ: Cập nhật dòng dịch vụ, BẢO LƯU PHỤ PHÍ & PHÍ GIAO,
    // ĐỒNG BỘ 100% SANG PAYMENT.AMOUNT
    // ============================================================
    [HttpPut("{id}/pickup-details")]
    [Authorize(Roles = "Shipper")]
    public async Task<IActionResult> ConfirmPickupDetails(int id, [FromBody] PickupConfirmationRequest request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out var shipperId))
            return Unauthorized(new { message = "Không xác định được shipper." });

        using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            var order = await _context.Orders
                .Include(o => o.OrderDetails)
                    .ThenInclude(d => d.Service)
                .FirstOrDefaultAsync(o => o.Id == id);

            if (order == null) return NotFound(new { message = "Không tìm thấy đơn hàng." });
            if (order.ShipperId != shipperId) return Forbid();
            if (order.Status != OrderStatus.PickingUp)
                return BadRequest(new { message = "Chỉ xác nhận số lượng/cân nặng khi đơn đang ở trạng thái PickingUp." });
            if (request.Items == null || request.Items.Count == 0)
                return BadRequest(new { message = "Vui lòng nhập số lượng/cân nặng thực tế." });
            if (!request.CustomerConfirmed)
                return BadRequest(new { message = "Vui lòng xác nhận đã đối chiếu số liệu với khách hàng." });

            var serviceIds = request.Items.Select(x => x.ServiceId).Distinct().ToList();
            var services = await _context.Services
                .Include(s => s.Prices)
                .Where(s => serviceIds.Contains(s.Id) && s.IsActive)
                .ToDictionaryAsync(s => s.Id);

            decimal newSubTotal = 0;
            foreach (var input in request.Items)
            {
                if (!services.TryGetValue(input.ServiceId, out var service))
                    return BadRequest(new { message = $"Dịch vụ ID {input.ServiceId} không hợp lệ." });

                var currentPrice = service.Prices
                    .Where(p => p.IsActive && p.EffectiveTo == null)
                    .OrderByDescending(p => p.EffectiveFrom)
                    .FirstOrDefault();

                if (currentPrice == null)
                    return BadRequest(new { message = $"Dịch vụ '{service.Name}' chưa có bảng giá." });

                var calculated = input.Quantity * currentPrice.Price;
                var lineTotal = currentPrice.MinimumPrice.HasValue ? Math.Max(calculated, currentPrice.MinimumPrice.Value) : calculated;

                var detail = order.OrderDetails.FirstOrDefault(d => d.ServiceId == input.ServiceId);
                if (detail == null)
                {
                    detail = new OrderDetail
                    {
                        OrderId = order.Id,
                        ServiceId = service.Id,
                        Service = service
                    };
                    order.OrderDetails.Add(detail);
                }

                detail.Quantity = input.Quantity;
                detail.Unit = currentPrice.Unit;
                detail.UnitPrice = input.Quantity > 0 ? lineTotal / input.Quantity : currentPrice.Price;
                detail.TotalPrice = lineTotal;
                newSubTotal += lineTotal;
            }

            // BẢO LƯU PHỤ PHÍ TIỆN ÍCH, PHÍ GIAO VÀ GIẢM GIÁ
            order.TotalAmount = Math.Max(0, newSubTotal + order.ShippingFee + order.AddonFee - order.DiscountAmount);
            order.UpdatedAt = DateTime.UtcNow;

            // ĐỒNG BỘ 100% SANG PAYMENT (DUY NHẤT 1 NGUỒN SỰ THẬT TÀI CHÍNH)
            var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderId == order.Id);
            if (payment != null && payment.Status != PaymentStatus.Paid)
            {
                payment.Amount = order.TotalAmount;
            }

            var note = string.IsNullOrWhiteSpace(request.Note)
                ? "Shipper đã cân đo & đối chiếu số lượng với khách hàng."
                : $"Cân đo với khách: {request.Note.Trim()}";

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                Status = order.Status,
                Note = note,
                ChangedByUserId = shipperId,
                ChangedAt = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            return Ok(new
            {
                message = "Xác nhận số lượng & cân nặng thành công.",
                orderId = order.Id,
                subTotal = newSubTotal,
                shippingFee = order.ShippingFee,
                addonFee = order.AddonFee,
                totalAmount = order.TotalAmount,
                paymentAmount = payment?.Amount ?? order.TotalAmount,
                updatedAt = order.UpdatedAt
            });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            _logger.LogError(ex, "Lỗi đối chiếu cân đo đơn {OrderId}.", id);
            return StatusCode(500, new { message = "Lỗi đối chiếu số lượng/cân nặng." });
        }
    }

    // ============================================================
    // GET: api/Orders/my-orders
    // Khách hàng xem đơn của mình
    // ============================================================
    [HttpGet("my-orders")]
    public async Task<IActionResult> GetMyOrders()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int customerId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var orders = await _context.Orders
            .Where(x => x.CustomerId == customerId)
            .Include(x => x.OrderDetails)
                .ThenInclude(x => x.Service)
            .OrderByDescending(x => x.CreatedAt)
            .Select(x => new
            {
                x.Id,
                status = x.Status.ToString(),
                x.OrderType,
                x.PickupAddress,
                x.DeliveryAddress,
                x.ShippingFee,
                x.AddonFee,
                x.DiscountAmount,
                x.TotalAmount,
                x.PaymentMethod,
                x.DeliveryProofPhotoUrl,
                x.CreatedAt,
                paymentStatus = _context.Payments.Where(p => p.OrderId == x.Id).Select(p => p.Status.ToString()).FirstOrDefault() ?? "Pending",
                items = x.OrderDetails.Select(d => new
                {
                    d.ServiceId,
                    serviceName = d.Service!.Name,
                    d.Quantity,
                    d.Unit,
                    d.UnitPrice,
                    d.TotalPrice
                })
            })
            .ToListAsync();

        return Ok(orders);
    }

    // ============================================================
    // GET: api/Orders/{id}/history
    // Lịch sử trạng thái đơn
    // ============================================================
    [HttpGet("{id}/history")]
    public async Task<IActionResult> GetOrderHistory(int id)
    {
        var history = await _context.OrderStatusHistories
            .Where(x => x.OrderId == id)
            .OrderBy(x => x.ChangedAt)
            .Select(x => new
            {
                x.Id,
                x.OrderId,
                status = x.Status.ToString(),
                x.Note,
                x.ChangedAt,
                x.ChangedByUserId
            })
            .ToListAsync();

        return Ok(history);
    }

    // ============================================================
    // POST: api/Orders/{id}/cancel
    // Khách hủy đơn khi còn ở trạng thái Pending
    // ============================================================
    [HttpPost("{id}/cancel")]
    public async Task<IActionResult> CancelOrder(int id)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int customerId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var role = User.FindFirst(ClaimTypes.Role)?.Value;
        var order = await _context.Orders.FirstOrDefaultAsync(x => x.Id == id);
        if (order == null) return NotFound(new { message = "Không tìm thấy đơn hàng." });

        if (order.CustomerId != customerId && role != "Admin" && role != "Staff")
        {
            return Forbid();
        }

        if (order.Status != OrderStatus.Pending && order.Status != OrderStatus.Confirmed)
        {
            return BadRequest(new { message = "Chỉ có thể hủy đơn khi đơn chưa bắt đầu lấy hoặc đang xử lý." });
        }

        order.Status = OrderStatus.Cancelled;
        order.UpdatedAt = DateTime.UtcNow;

        _context.OrderStatusHistories.Add(new OrderStatusHistory
        {
            OrderId = order.Id,
            Status = OrderStatus.Cancelled,
            Note = "Đơn hàng đã được hủy",
            ChangedByUserId = customerId,
            ChangedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Hủy đơn hàng thành công.",
            orderId = order.Id,
            status = order.Status.ToString()
        });
    }

    // ============================================================
    // GET: api/Orders/{id}
    // Chi tiết đơn hàng (Khách sở hữu, Shipper được giao, Admin/Staff)
    // ============================================================
    [HttpGet("{id}")]
    public async Task<IActionResult> GetOrder(int id)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int currentUserId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var role = User.FindFirst(ClaimTypes.Role)?.Value;

        var order = await _context.Orders
            .Include(x => x.Customer)
            .Include(x => x.Shipper)
            .Include(x => x.OrderDetails)
                .ThenInclude(x => x.Service)
            .FirstOrDefaultAsync(x => x.Id == id);

        if (order == null)
        {
            return NotFound(new { message = "Không tìm thấy đơn hàng." });
        }

        var isOwner = order.CustomerId == currentUserId;
        var isAssignedShipper = order.ShipperId == currentUserId;
        var isStaffOrAdmin = role == "Admin" || role == "Staff";

        if (!isOwner && !isAssignedShipper && !isStaffOrAdmin)
        {
            return Forbid();
        }

        var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderId == order.Id);

        return Ok(new
        {
            order.Id,
            status = order.Status.ToString(),
            order.OrderType,
            order.CustomerId,
            customerName = order.Customer?.FullName ?? "",
            customerPhone = order.Customer?.Phone ?? order.ContactPhone,
            order.ShipperId,
            shipperName = order.Shipper?.FullName,
            order.PickupAddress,
            order.DeliveryAddress,
            order.ContactPhone,
            order.Note,
            order.ShippingFee,
            order.AddonFee,
            order.DiscountAmount,
            order.TotalAmount,
            order.PaymentMethod,
            order.DeliveryProofPhotoUrl,
            order.CreatedAt,
            order.UpdatedAt,
            paymentStatus = payment?.Status.ToString() ?? "Pending",
            paidAt = payment?.PaidAt,
            refundedAmount = payment?.RefundedAmount,
            items = order.OrderDetails.Select(d => new
            {
                d.ServiceId,
                serviceName = d.Service!.Name,
                d.Quantity,
                d.Unit,
                d.UnitPrice,
                d.TotalPrice
            })
        });
    }

    // ============================================================
    // POST: api/Orders/{id}/delivery-proof
    // Hoàn thành đơn hàng kèm ảnh chụp minh chứng giao hàng (COD thu tiền)
    // ============================================================
    [HttpPost("{id}/delivery-proof")]
    [Authorize(Roles = "Shipper,Admin,Staff")]
    public async Task<IActionResult> SubmitDeliveryProof(int id, [FromBody] DeliveryProofRequest request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userIdClaim == null || !int.TryParse(userIdClaim, out int currentUserId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var role = User.FindFirst(ClaimTypes.Role)?.Value;

        var order = await _context.Orders.FirstOrDefaultAsync(o => o.Id == id);
        if (order == null) return NotFound(new { message = "Không tìm thấy đơn hàng." });

        if (role == "Shipper" && order.ShipperId != currentUserId)
        {
            return Forbid();
        }

        if (order.Status != OrderStatus.Delivering)
        {
            return BadRequest(new { message = $"Chỉ có thể nộp minh chứng khi đơn đang ở trạng thái Delivering. Trạng thái hiện tại: {order.Status}." });
        }

        using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            order.DeliveryProofPhotoUrl = request.PhotoUrl?.Trim();
            order.Status = OrderStatus.Completed;
            order.UpdatedAt = DateTime.UtcNow;

            var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderId == order.Id);
            if (payment != null)
            {
                // Khi shipper giao thành công, nếu là COD / Tiền mặt thì tự động chuyển sang Paid
                if (order.PaymentMethod == "COD" || payment.Method == PaymentMethod.Cash || request.ConfirmPaymentCollected)
                {
                    payment.Status = PaymentStatus.Paid;
                    payment.PaidAt = DateTime.UtcNow;
                    payment.PaymentNote = request.Note ?? "Shipper thu tiền mặt COD khi giao đồ thành công.";
                }
            }

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                Status = OrderStatus.Completed,
                Note = string.IsNullOrWhiteSpace(request.Note) ? "Giao hàng thành công (Có ảnh chụp minh chứng)" : request.Note.Trim(),
                ChangedByUserId = currentUserId,
                ChangedAt = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            return Ok(new
            {
                message = "Xác nhận giao hàng thành công kèm ảnh chụp minh chứng.",
                orderId = order.Id,
                status = order.Status.ToString(),
                proofPhotoUrl = order.DeliveryProofPhotoUrl,
                paymentStatus = payment?.Status.ToString()
            });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            _logger.LogError(ex, "Lỗi nộp minh chứng giao hàng cho đơn {OrderId}.", id);
            return StatusCode(500, new { message = "Lỗi xác nhận minh chứng giao hàng." });
        }
    }

    // ============================================================
    // PUT: api/Orders/{id}/status
    // Chuyển trạng thái đơn: HỖ TRỢ ĐƠN QUẦY STOREPICKUP HOÀN TẤT TRỰC TIẾP,
    // VÀ BẢO VỆ CHỐNG ĐÓNG ĐƠN KHI CHƯA THANH TOÁN
    // ============================================================
    [HttpPut("{id}/status")]
    [Authorize(Roles = "Admin,Staff,Shipper")]
    public async Task<IActionResult> UpdateOrderStatus(int id, [FromBody] UpdateOrderStatusRequest request)
    {
        var order = await _context.Orders.FirstOrDefaultAsync(x => x.Id == id);
        if (order == null) return NotFound(new { message = "Không tìm thấy đơn hàng." });

        if (!Enum.TryParse<OrderStatus>(request.Status, true, out var newStatus))
        {
            return BadRequest(new { message = "Trạng thái không hợp lệ." });
        }

        var currentStatus = order.Status;
        if (currentStatus == newStatus)
        {
            return BadRequest(new { message = "Đơn hàng đã ở trạng thái này." });
        }

        var currentUserRole = User.FindFirst(ClaimTypes.Role)?.Value;
        var currentUserIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        int.TryParse(currentUserIdClaim, out var currentUserId);

        // ==========================================
        // 1. Phân quyền Shipper
        // ==========================================
        if (currentUserRole == "Shipper")
        {
            if (order.ShipperId != currentUserId) return Forbid();

            var isValidShipperTransition =
                (currentStatus == OrderStatus.Confirmed && newStatus == OrderStatus.PickingUp) ||
                (currentStatus == OrderStatus.PickingUp && newStatus == OrderStatus.Received) ||
                (currentStatus == OrderStatus.Ready && newStatus == OrderStatus.Delivering) ||
                (currentStatus == OrderStatus.Delivering && newStatus == OrderStatus.Completed);

            if (!isValidShipperTransition)
            {
                return BadRequest(new { message = $"Shipper không thể chuyển từ {currentStatus} sang {newStatus}." });
            }
        }

        // ==========================================
        // 2. Phân quyền Admin / Staff (HỖ TRỢ ĐƠN QUẦY TỰ HOÀN TẤT)
        // ==========================================
        if (currentUserRole == "Admin" || currentUserRole == "Staff")
        {
            var isValidStaffTransition =
                // Đơn bình thường
                (currentStatus == OrderStatus.Pending && newStatus == OrderStatus.Confirmed) ||
                (currentStatus == OrderStatus.Received && newStatus == OrderStatus.Washing) ||
                (currentStatus == OrderStatus.Washing && newStatus == OrderStatus.Ready) ||
                // ĐƠN TẠI QUẦY (STOREPICKUP): Nhân viên tiếp nhận trực tiếp và khách tự lấy trực tiếp không cần shipper!
                (currentStatus == OrderStatus.Confirmed && newStatus == OrderStatus.Received) ||
                (currentStatus == OrderStatus.Pending && newStatus == OrderStatus.Received) ||
                (currentStatus == OrderStatus.Ready && newStatus == OrderStatus.Completed) ||
                // Hủy đơn
                ((currentStatus == OrderStatus.Pending || currentStatus == OrderStatus.Confirmed) && newStatus == OrderStatus.Cancelled);

            if (!isValidStaffTransition)
            {
                return BadRequest(new { message = $"Admin/Staff không thể chuyển đơn từ {currentStatus} sang {newStatus}." });
            }
        }

        // ==========================================
        // 3. KIỂM SOÁT THANH TOÁN KHI HOÀN TẤT ĐƠN
        // ==========================================
        using var tx = await _context.Database.BeginTransactionAsync();
        try
        {
            var payment = await _context.Payments.FirstOrDefaultAsync(p => p.OrderId == order.Id);

            if (newStatus == OrderStatus.Completed)
            {
                if (payment != null)
                {
                    if (payment.Status != PaymentStatus.Paid)
                    {
                        // Nếu là COD hoặc tiền mặt tại quầy, staff/shipper xác nhận hoàn tất đồng thời ghi nhận đã thu tiền
                        if (order.PaymentMethod == "COD" || payment.Method == PaymentMethod.Cash || order.OrderType == "StorePickup")
                        {
                            payment.Status = PaymentStatus.Paid;
                            payment.PaidAt = DateTime.UtcNow;
                            payment.PaymentNote = payment.PaymentNote ?? (currentUserRole == "Shipper" ? "Shipper thu COD khi giao đồ." : "Thu tiền mặt trực tiếp tại quầy khi trả đồ sạch cho khách.");
                        }
                        else
                        {
                            return BadRequest(new
                            {
                                message = "Đơn hàng chưa hoàn tất thanh toán trực tuyến. Vui lòng hướng dẫn khách chuyển khoản hoặc xác nhận tiền vào trước khi hoàn thành đơn."
                            });
                        }
                    }
                }
            }

            // Khi shipper hoàn tất lấy đồ (Received), giải phóng shipper để ghép phân công nhiệm vụ giao đồ sau
            order.Status = newStatus;
            if (newStatus == OrderStatus.Received && currentStatus == OrderStatus.PickingUp)
            {
                order.ShipperId = null;
            }
            order.UpdatedAt = DateTime.UtcNow;

            _context.OrderStatusHistories.Add(new OrderStatusHistory
            {
                OrderId = order.Id,
                Status = newStatus,
                Note = request.Note ?? $"Chuyển trạng thái sang {newStatus}",
                ChangedByUserId = currentUserId,
                ChangedAt = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();
            await tx.CommitAsync();

            return Ok(new
            {
                message = "Cập nhật trạng thái đơn hàng thành công.",
                orderId = order.Id,
                oldStatus = currentStatus.ToString(),
                newStatus = newStatus.ToString(),
                paymentStatus = payment?.Status.ToString(),
                updatedAt = order.UpdatedAt
            });
        }
        catch (Exception ex)
        {
            await tx.RollbackAsync();
            _logger.LogError(ex, "Lỗi cập nhật trạng thái đơn {OrderId}.", id);
            return StatusCode(500, new { message = "Lỗi cập nhật trạng thái đơn hàng: " + ex.Message });
        }
    }
}
