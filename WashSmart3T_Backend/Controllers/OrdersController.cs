using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Models;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class OrdersController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public OrdersController(ApplicationDbContext context)
    {
        _context = context;
    }

    // GET: api/Orders/management
    // Admin/Staff xem toàn bộ đơn hàng
    [HttpGet("management")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> GetOrdersForManagement()
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
                customerName = o.Customer != null
                    ? o.Customer.FullName : "",
                customerPhone = o.Customer != null
                    ? o.Customer.Phone : o.ContactPhone,

                o.ShipperId,
                shipperName = o.Shipper != null
                    ? o.Shipper.FullName : null,

                status = o.Status.ToString(),
                o.PickupAddress,
                o.DeliveryAddress,
                o.ContactPhone,
                o.Note,
                o.TotalAmount,
                o.CreatedAt,
                o.UpdatedAt,

                items = o.OrderDetails.Select(d => new
                {
                    d.ServiceId,
                    serviceName = d.Service != null
                        ? d.Service.Name : "",
                    d.Quantity,
                    d.Unit,
                    d.UnitPrice,
                    d.TotalPrice
                })
            })
            .ToListAsync();

        return Ok(orders);
    }


    // GET: api/Orders/management/shippers
    // Danh sách shipper cho Admin/Staff phân công
    [HttpGet("management/shippers")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> GetActiveShippers()
    {
        var shipperUsers = await _context.Users
            .AsNoTracking()
            .Where(u =>
                u.IsActive &&
                u.Role != null &&
                u.Role.Name == "Shipper")
            .OrderBy(u => u.FullName)
            .Select(u => new
            {
                u.Id,
                u.FullName,
                u.Phone
            })
            .ToListAsync();

        // Một shipper chỉ bận khi có nhiệm vụ lấy/giao đang hoạt động.
        // Received/Washing không khóa shipper; nhiệm vụ lấy đồ kết thúc ở Received.
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
            var currentOrder = await _context.Orders
                .AsNoTracking()
                .Where(o => o.ShipperId == shipper.Id &&
                            activeStatuses.Contains(o.Status))
                .OrderBy(o => o.CreatedAt)
                .Select(o => new
                {
                    orderId = o.Id,
                    status = o.Status.ToString()
                })
                .FirstOrDefaultAsync();

            string? currentTask = currentOrder?.status switch
            {
                "Confirmed" or "PickingUp" => "Lấy đồ",
                "Ready" or "Delivering" => "Giao đồ",
                _ => null
            };

            shippers.Add(new
            {
                shipper.Id,
                shipper.FullName,
                shipper.Phone,
                isBusy = currentOrder != null,
                currentOrderId = currentOrder?.orderId,
                currentTask
            });
        }

        return Ok(shippers);
    }

    public class AssignShipperRequest
    {
        public int ShipperId { get; set; }
    }


    // POST: api/Orders/{id}/assign-shipper
    // Admin/Staff phân công shipper cụ thể
    [HttpPost("{id}/assign-shipper")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> AssignShipper(
        int id,
        [FromBody] AssignShipperRequest request)
    {
        if (request.ShipperId <= 0)
        {
            return BadRequest(new
            {
                message = "ShipperId không hợp lệ."
            });
        }

        var order = await _context.Orders
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        // Đơn lấy đồ được phân công ở Confirmed; đơn giao đồ ở Ready.
        if (order.Status != OrderStatus.Confirmed &&
            order.Status != OrderStatus.Ready)
        {
            return BadRequest(new
            {
                message =
                    $"Chỉ phân công đơn ở trạng thái Confirmed hoặc Ready. " +
                    $"Trạng thái hiện tại: {order.Status}."
            });
        }

        var shipper = await _context.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u =>
                u.Id == request.ShipperId &&
                u.IsActive &&
                u.Role != null &&
                u.Role.Name == "Shipper");

        if (shipper == null)
        {
            return BadRequest(new
            {
                message =
                    "Shipper không tồn tại, đã bị khóa " +
                    "hoặc không có đúng vai trò Shipper."
            });
        }

        // Không phân công nếu shipper đang có nhiệm vụ lấy/giao đơn khác.
        var shipperBusy = await _context.Orders.AnyAsync(o =>
            o.Id != order.Id &&
            o.ShipperId == shipper.Id &&
            (o.Status == OrderStatus.Confirmed ||
             o.Status == OrderStatus.PickingUp ||
             o.Status == OrderStatus.Delivering));

        if (shipperBusy)
        {
            return Conflict(new
            {
                message = "Shipper đang có nhiệm vụ lấy/giao đơn khác. Vui lòng chọn shipper khác."
            });
        }

        order.ShipperId = shipper.Id;
        order.UpdatedAt = DateTime.UtcNow;

        var userIdClaim =
            User.FindFirst(
                System.Security.Claims.ClaimTypes.NameIdentifier
            )?.Value;

        int? changedByUserId =
            int.TryParse(userIdClaim, out var userId)
                ? userId
                : null;

        _context.OrderStatusHistories.Add(
            new OrderStatusHistory
            {
                OrderId = order.Id,
                Status = order.Status,
                Note = $"Phân công shipper: {shipper.FullName}",
                ChangedByUserId = changedByUserId,
                ChangedAt = DateTime.UtcNow
            });

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Phân công shipper thành công.",
            orderId = order.Id,
            shipperId = shipper.Id,
            shipperName = shipper.FullName,
            status = order.Status.ToString()
        });
    }


    // ============================
    // POST: api/Orders
    // Khách tạo đơn
    // ============================
    [HttpPost]
    public async Task<IActionResult> CreateOrder(CreateOrderRequest request)
    {
        if (request.Items == null || request.Items.Count == 0)
        {
            return BadRequest(new
            {
                message = "Đơn hàng phải có ít nhất một dịch vụ."
            });
        }

        if (string.IsNullOrWhiteSpace(request.PickupAddress))
        {
            return BadRequest(new
            {
                message = "Vui lòng nhập địa chỉ lấy đồ."
            });
        }

        if (string.IsNullOrWhiteSpace(request.DeliveryAddress))
        {
            return BadRequest(new
            {
                message = "Vui lòng nhập địa chỉ giao đồ."
            });
        }

        // ============================
        // Lấy CustomerId từ JWT
        // ============================

        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null)
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        if (!int.TryParse(userIdClaim.Value, out int customerId))
        {
            return Unauthorized(new
            {
                message = "Thông tin người dùng không hợp lệ."
            });
        }

        // Kiểm tra user tồn tại
        var customer = await _context.Users
            .FirstOrDefaultAsync(x =>
                x.Id == customerId &&
                x.IsActive);

        if (customer == null)
        {
            return Unauthorized(new
            {
                message = "Tài khoản không tồn tại hoặc đã bị khóa."
            });
        }

        // ============================
        // Tạo Order
        // ============================

        var order = new Order
        {
            CustomerId = customerId,
            PickupAddress = request.PickupAddress,
            DeliveryAddress = request.DeliveryAddress,
            ContactPhone = request.ContactPhone,
            Note = request.Note,
            Status = OrderStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            TotalAmount = 0
        };

        // ============================
        // Xử lý từng dịch vụ
        // ============================

        foreach (var item in request.Items)
        {
            // Khách hàng chưa cân/đếm đồ ở thời điểm đặt đơn.
            // Cho phép Quantity = 0 để đánh dấu số lượng chưa xác định;
            // chỉ shipper mới nhập số liệu thực tế tại bước nhận đồ.
            if (item.Quantity < 0)
            {
                return BadRequest(new
                {
                    message =
                        $"Số lượng dịch vụ {item.ServiceId} không được âm."
                });
            }

            var service = await _context.Services
                .Include(x => x.Prices)
                .FirstOrDefaultAsync(x =>
                    x.Id == item.ServiceId &&
                    x.IsActive);

            if (service == null)
            {
                return BadRequest(new
                {
                    message =
                        $"Dịch vụ ID {item.ServiceId} không tồn tại hoặc đã ngưng hoạt động."
                });
            }

            // ============================
            // Lấy giá hiện tại
            // ============================

            var currentPrice = service.Prices
                .Where(x =>
                    x.IsActive &&
                    x.EffectiveTo == null)
                .OrderByDescending(x => x.EffectiveFrom)
                .FirstOrDefault();

            if (currentPrice == null)
            {
                return BadRequest(new
                {
                    message =
                        $"Dịch vụ '{service.Name}' chưa có giá."
                });
            }

            // ============================
            // Tính tiền
            // ============================

            // ============================================================
            // TÍNH GIÁ DỊCH VỤ
            // ============================================================

            // Chưa có số lượng thực tế thì chưa áp dụng giá tối thiểu,
            // tránh hiển thị nhầm một mức giá giặt trước khi shipper cân/đếm.
            var calculatedPrice = item.Quantity * currentPrice.Price;
            var totalPrice = item.Quantity == 0
                ? 0
                : currentPrice.MinimumPrice.HasValue
                    ? Math.Max(calculatedPrice, currentPrice.MinimumPrice.Value)
                    : calculatedPrice;

            // Giá thực tế trên một đơn vị sau khi áp dụng
            // giá tối thiểu.
            // Lưu giá này để đảm bảo lịch sử đơn không thay đổi
            // nếu bảng giá dịch vụ được cập nhật sau này.
            var effectiveUnitPrice = item.Quantity > 0
                ? totalPrice / item.Quantity
                : currentPrice.Price;

            var detail = new OrderDetail
            {
                ServiceId = service.Id,
                Quantity = item.Quantity,

                // Giá thực tế tại thời điểm đặt
                UnitPrice = effectiveUnitPrice,

                Unit = currentPrice.Unit,

                TotalPrice = totalPrice
            };

            order.OrderDetails.Add(detail);

            order.TotalAmount += totalPrice;
        }

        // ============================
        // Lưu database
        // ============================

        _context.Orders.Add(order);

        await _context.SaveChangesAsync();

        // Lưu lịch sử trạng thái đầu tiên
        var history = new OrderStatusHistory
        {
            OrderId = order.Id,
            Status = OrderStatus.Pending,
            Note = "Đơn hàng được tạo",
            ChangedByUserId = customerId,
            ChangedAt = DateTime.UtcNow
        };

        _context.OrderStatusHistories.Add(history);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Tạo đơn hàng thành công.",

            orderId = order.Id,

            status = order.Status.ToString(),

            totalAmount = order.TotalAmount,

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


    // ============================================================
    // POS quầy: tạo đơn cho khách đến cửa hàng, dùng tài khoản Admin/Staff
    // POST: api/Orders/pos
    // ============================================================
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
        public List<CreateOrderDetailRequest> Items { get; set; } = new();
    }

    [HttpGet("pos/customer")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> FindPosCustomer([FromQuery] string phone)
    {
        var normalizedPhone = new string((phone ?? string.Empty).Where(char.IsDigit).ToArray());
        if (normalizedPhone.Length < 9 || normalizedPhone.Length > 11)
            return BadRequest(new { message = "Số điện thoại không hợp lệ." });

        var customer = await _context.Users
            .Include(u => u.Role)
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Phone == normalizedPhone && u.Role != null && u.Role.Name == "Customer");

        if (customer == null) return Ok(new { found = false });
        return Ok(new { found = true, customer.Id, fullName = customer.FullName, phone = customer.Phone });
    }

    [HttpPost("pos")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> CreatePosOrder([FromBody] PosCreateOrderRequest request)
    {
        var staffClaim = User.FindFirst(ClaimTypes.NameIdentifier);
        if (staffClaim == null || !int.TryParse(staffClaim.Value, out var staffId))
            return Unauthorized(new { message = "Không xác định được nhân viên đang đăng nhập." });

        var name = (request.CustomerName ?? string.Empty).Trim();
        var phone = new string((request.ContactPhone ?? string.Empty).Where(char.IsDigit).ToArray());
        if (name.Length < 2) return BadRequest(new { message = "Vui lòng nhập họ tên khách hàng." });
        if (phone.Length < 9 || phone.Length > 11) return BadRequest(new { message = "Số điện thoại khách hàng không hợp lệ." });
        if (request.Items == null || request.Items.Count == 0) return BadRequest(new { message = "Vui lòng chọn ít nhất một dịch vụ." });
        if (request.Items.Any(i => i.ServiceId <= 0 || i.Quantity <= 0)) return BadRequest(new { message = "Dịch vụ và số lượng thực tế phải hợp lệ, lớn hơn 0." });
        if (string.IsNullOrWhiteSpace(request.PickupAddress) || string.IsNullOrWhiteSpace(request.DeliveryAddress))
            return BadRequest(new { message = "Thiếu địa chỉ nhận hoặc trả đồ." });
        if (request.AddonFee < 0 || request.CashReceived < 0) return BadRequest(new { message = "Số tiền không hợp lệ." });
        if (request.DeliveryMethod != "HomeDelivery" && request.DeliveryMethod != "StorePickup")
            return BadRequest(new { message = "Hình thức nhận đồ không hợp lệ." });
        if (request.DeliveryMethod == "HomeDelivery" && string.Equals(request.DeliveryAddress.Trim(), request.PickupAddress.Trim(), StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { message = "Vui lòng nhập địa chỉ giao tận nhà khác địa chỉ cửa hàng." });
        if (request.PaymentMethod != "Cash" && request.PaymentMethod != "BankTransfer")
            return BadRequest(new { message = "Phương thức thanh toán không hợp lệ." });
        if (request.PaymentTiming != "PayNow" && request.PaymentTiming != "COD")
            return BadRequest(new { message = "Thời điểm thanh toán không hợp lệ." });

        // Phí giao tận nhà do backend quyết định, không tin giá gửi từ trình duyệt.
        var actualDeliveryFee = request.DeliveryMethod == "HomeDelivery" ? 20000m : 0m;

        var customerRole = await _context.Roles.FirstOrDefaultAsync(r => r.Name == "Customer");
        if (customerRole == null) return BadRequest(new { message = "Database chưa có vai trò Customer." });

        var customer = await _context.Users.Include(u => u.Role).FirstOrDefaultAsync(u => u.Phone == phone);
        if (customer != null && customer.Role?.Name != "Customer")
            return Conflict(new { message = "Số điện thoại này đang được dùng cho tài khoản nhân viên hoặc shipper." });
        if (customer == null)
        {
            customer = new User
            {
                FullName = name,
                Phone = phone,
                Email = $"pos-{phone}@customer.washsmart.local",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString("N")),
                RoleId = customerRole.Id,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };
            _context.Users.Add(customer);
            await _context.SaveChangesAsync();
        }
        else if (string.IsNullOrWhiteSpace(customer.FullName) || customer.FullName == phone)
        {
            customer.FullName = name;
        }

        var deliveryModeText = request.DeliveryMethod == "HomeDelivery" ? "Giao tận nhà sau khi giặt" : "Khách tự đến cửa hàng lấy";
        var paymentTimingText = request.PaymentTiming == "COD" ? "COD khi giao đồ" : "Thanh toán tại quầy";
        var paymentMethodText = request.PaymentMethod == "BankTransfer" ? "Chuyển khoản/VietQR" : "Tiền mặt";
        var note = string.Join("\n", new[]
        {
            "Nguồn: POS quầy",
            $"Hình thức nhận đồ: {deliveryModeText}",
            $"Phương thức thanh toán: {paymentMethodText}",
            $"Thời điểm thanh toán: {paymentTimingText}",
            $"Phụ phí tiện ích: {request.AddonFee:N0}đ",
            $"Phí giao hàng: {actualDeliveryFee:N0}đ",
            request.Note?.Trim()
        }.Where(x => !string.IsNullOrWhiteSpace(x)));

        var order = new Order
        {
            CustomerId = customer.Id,
            PickupAddress = request.PickupAddress.Trim(),
            DeliveryAddress = request.DeliveryAddress.Trim(),
            ContactPhone = phone,
            Note = note,
            Status = OrderStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            TotalAmount = 0
        };

        foreach (var item in request.Items)
        {
            var service = await _context.Services.Include(s => s.Prices)
                .FirstOrDefaultAsync(s => s.Id == item.ServiceId && s.IsActive);
            if (service == null) return BadRequest(new { message = $"Dịch vụ ID {item.ServiceId} không tồn tại hoặc đã ngưng hoạt động." });
            var price = service.Prices.Where(p => p.IsActive && p.EffectiveTo == null)
                .OrderByDescending(p => p.EffectiveFrom).FirstOrDefault();
            if (price == null) return BadRequest(new { message = $"Dịch vụ '{service.Name}' chưa có giá." });
            var lineTotal = item.Quantity * price.Price;
            if (price.MinimumPrice.HasValue) lineTotal = Math.Max(lineTotal, price.MinimumPrice.Value);
            var effectiveUnitPrice = item.Quantity > 0 ? lineTotal / item.Quantity : price.Price;
            order.OrderDetails.Add(new OrderDetail
            {
                ServiceId = service.Id,
                Quantity = item.Quantity,
                UnitPrice = effectiveUnitPrice,
                Unit = price.Unit,
                TotalPrice = lineTotal
            });
            order.TotalAmount += lineTotal;
        }

        order.TotalAmount += request.AddonFee + actualDeliveryFee;
        if (request.PaymentTiming == "PayNow" && request.PaymentMethod == "Cash" && request.CashReceived < order.TotalAmount)
            return BadRequest(new { message = "Tiền mặt khách đưa chưa đủ tổng thanh toán." });

        _context.Orders.Add(order);
        await _context.SaveChangesAsync();
        _context.OrderStatusHistories.Add(new OrderStatusHistory
        {
            OrderId = order.Id,
            Status = OrderStatus.Pending,
            Note = "Đơn được tạo tại POS quầy",
            ChangedByUserId = staffId,
            ChangedAt = DateTime.UtcNow
        });

        // Chuyển khoản giữ Pending đến khi đối soát; COD cũng chưa thu tiền.
        if (!Enum.TryParse<PaymentMethod>(request.PaymentMethod, true, out var paymentMethod)) paymentMethod = PaymentMethod.Cash;
        var paidAtCounter = request.PaymentTiming == "PayNow" && paymentMethod == PaymentMethod.Cash;
        var payment = new Payment
        {
            OrderId = order.Id,
            Method = paymentMethod,
            Amount = order.TotalAmount,
            Status = paidAtCounter ? PaymentStatus.Paid : PaymentStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            PaidAt = paidAtCounter ? DateTime.UtcNow : null
        };
        _context.Payments.Add(payment);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Tạo đơn POS thành công.",
            orderId = order.Id,
            customerId = customer.Id,
            customerName = customer.FullName,
            customerPhone = customer.Phone,
            status = order.Status.ToString(),
            totalAmount = order.TotalAmount,
            paymentStatus = payment.Status.ToString(),
            items = order.OrderDetails.Select(d => new { d.ServiceId, d.Quantity, d.Unit, d.UnitPrice, d.TotalPrice })
        });
    }

    // ============================================================
    // GET: api/Orders/shipper-orders
    // Shipper xem các đơn được giao cho mình
    // và các đơn đang chờ shipper nhận
    // ============================================================

    [HttpGet("shipper-orders")]
    [Authorize(Roles = "Shipper,Admin,Staff")]
    public async Task<IActionResult> GetShipperOrders()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null ||
            !int.TryParse(userIdClaim.Value, out int shipperId))
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var orders = await _context.Orders
            .Where(x =>
                // Đơn chưa có shipper và đang sẵn sàng nhận
                (
                    x.ShipperId == null &&
                    (
                        x.Status == OrderStatus.Confirmed ||
                        x.Status == OrderStatus.Ready
                    )
                )

                ||

                // Hoặc đơn đã được giao cho shipper hiện tại
                x.ShipperId == shipperId
            )
            .Include(x => x.Customer)
            .Include(x => x.OrderDetails)
                .ThenInclude(x => x.Service)
            .OrderByDescending(x => x.CreatedAt)
            .Select(x => new
            {
                x.Id,

                status = x.Status.ToString(),

                x.CustomerId,

                customerName = x.Customer != null
                    ? x.Customer.FullName
                    : string.Empty,

                customerPhone = x.Customer != null
                    ? x.Customer.Phone
                    : x.ContactPhone,

                x.PickupAddress,

                x.DeliveryAddress,

                x.ContactPhone,

                x.Note,

                x.TotalAmount,

                x.CreatedAt,

                x.UpdatedAt,

                isAssignedToCurrentShipper =
                    x.ShipperId == shipperId,

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
    // Shipper nhận đơn
    // ============================================================

    [HttpPost("{id}/assign")]
    [Authorize(Roles = "Shipper")]
    public async Task<IActionResult> AssignOrderToShipper(int id)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null ||
            !int.TryParse(userIdClaim.Value, out int shipperId))
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var order = await _context.Orders
            .FirstOrDefaultAsync(x => x.Id == id);

        if (order == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        // Đơn đã có shipper khác
        if (order.ShipperId.HasValue &&
            order.ShipperId.Value != shipperId)
        {
            return BadRequest(new
            {
                message = "Đơn hàng đã được shipper khác nhận."
            });
        }

        // Chỉ được nhận đơn ở các trạng thái phù hợp
        if (order.Status != OrderStatus.Confirmed &&
            order.Status != OrderStatus.Ready)
        {
            return BadRequest(new
            {
                message =
                    $"Không thể nhận đơn ở trạng thái {order.Status}."
            });
        }

        // Một shipper chỉ được có một nhiệm vụ lấy/giao đang hoạt động.
        var shipperBusy = await _context.Orders.AnyAsync(x =>
            x.Id != order.Id &&
            x.ShipperId == shipperId &&
            (x.Status == OrderStatus.Confirmed ||
             x.Status == OrderStatus.PickingUp ||
             x.Status == OrderStatus.Delivering));

        if (shipperBusy)
        {
            return Conflict(new
            {
                message = "Bạn đang có nhiệm vụ lấy/giao đơn khác. Hoàn tất nhiệm vụ đó trước khi nhận đơn mới."
            });
        }

        order.ShipperId = shipperId;
        order.UpdatedAt = DateTime.UtcNow;

        _context.OrderStatusHistories.Add(new OrderStatusHistory
        {
            OrderId = order.Id,
            Status = order.Status,
            Note = "Shipper nhận nhiệm vụ đơn hàng",
            ChangedByUserId = shipperId,
            ChangedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Nhận đơn thành công.",
            orderId = order.Id,
            shipperId,
            status = order.Status.ToString()
        });
    }
    // ============================================================
    // PUT: api/Orders/{id}/pickup-details
    // Lưu số lượng/cân nặng thực tế sau khi shipper đối chiếu với khách.
    // Trạng thái Received chỉ được cập nhật khi đồ đã về cửa hàng.
    // ============================================================
    [HttpPut("{id}/pickup-details")]
    [Authorize(Roles = "Shipper")]
    public async Task<IActionResult> ConfirmPickupDetails(
        int id,
        [FromBody] PickupConfirmationRequest request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);
        if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out var shipperId))
            return Unauthorized(new { message = "Không xác định được shipper." });

        var order = await _context.Orders
            .Include(o => o.OrderDetails)
                .ThenInclude(d => d.Service)
            .FirstOrDefaultAsync(o => o.Id == id);

        if (order == null)
            return NotFound(new { message = "Không tìm thấy đơn hàng." });
        if (order.ShipperId != shipperId)
            return Forbid();
        if (order.Status != OrderStatus.PickingUp)
            return BadRequest(new { message = "Chỉ xác nhận số lượng/cân nặng khi đơn đang ở trạng thái PickingUp." });
        if (request.Items == null || request.Items.Count == 0)
            return BadRequest(new { message = "Vui lòng nhập số lượng/cân nặng thực tế." });
        if (!request.CustomerConfirmed)
            return BadRequest(new { message = "Vui lòng xác nhận đã đối chiếu số liệu với khách hàng." });
        if (request.Items.Any(i => i.Quantity <= 0))
            return BadRequest(new { message = "Số lượng/cân nặng phải lớn hơn 0." });

        if (request.Items.Select(i => i.ServiceId).Distinct().Count() != request.Items.Count)
            return BadRequest(new { message = "Mỗi dịch vụ chỉ được xuất hiện một lần trong danh sách cân đồ." });

        decimal newTotal = 0;
        foreach (var input in request.Items)
        {
            // Cho phép shipper bổ sung dịch vụ khách yêu cầu tại điểm lấy hàng.
            var service = await _context.Services
                .FirstOrDefaultAsync(s => s.Id == input.ServiceId && s.IsActive);
            if (service == null)
                return BadRequest(new { message = $"Dịch vụ ID {input.ServiceId} không tồn tại hoặc đã ngừng hoạt động." });

            var currentPrice = await _context.ServicePrices
                .Where(p => p.ServiceId == input.ServiceId && p.IsActive && p.EffectiveTo == null)
                .OrderByDescending(p => p.EffectiveFrom)
                .FirstOrDefaultAsync();
            if (currentPrice == null)
                return BadRequest(new { message = $"Dịch vụ '{service.Name}' chưa có bảng giá hiện hành." });

            var calculated = input.Quantity * currentPrice.Price;
            var lineTotal = currentPrice.MinimumPrice.HasValue
                ? Math.Max(calculated, currentPrice.MinimumPrice.Value)
                : calculated;

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
            detail.UnitPrice = lineTotal / input.Quantity;
            detail.TotalPrice = lineTotal;
            newTotal += lineTotal;
        }

        order.TotalAmount = newTotal;
        order.UpdatedAt = DateTime.UtcNow;
        var note = string.IsNullOrWhiteSpace(request.Note)
            ? "Shipper đã đối chiếu số lượng/cân nặng với khách hàng; tiền đang là dự tính."
            : $"Đã đối chiếu với khách hàng. {request.Note.Trim()}";
        _context.OrderStatusHistories.Add(new OrderStatusHistory
        {
            OrderId = order.Id,
            Status = order.Status,
            Note = note,
            ChangedByUserId = shipperId,
            ChangedAt = DateTime.UtcNow
        });
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Đã lưu số lượng/cân nặng và tiền dự tính.",
            orderId = order.Id,
            status = order.Status.ToString(),
            totalAmount = order.TotalAmount,
            updatedAt = order.UpdatedAt,
            items = order.OrderDetails.Select(d => new
            {
                d.ServiceId,
                serviceName = d.Service?.Name ?? string.Empty,
                d.Quantity,
                d.Unit,
                d.UnitPrice,
                d.TotalPrice
            })
        });
    }




    // ============================
    // GET: api/Orders/my-orders
    // Khách xem đơn của mình
    // ============================
    [HttpGet("my-orders")]
    public async Task<IActionResult> GetMyOrders()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null ||
            !int.TryParse(userIdClaim.Value, out int customerId))
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
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
                x.PickupAddress,
                x.DeliveryAddress,
                x.TotalAmount,
                x.CreatedAt,

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

    // ============================
    // GET: api/Orders/{id}/history
    // Khách xem lịch sử trạng thái đơn
    // ============================
    [HttpGet("{id}/history")]
    public async Task<IActionResult> GetOrderHistory(int id)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null ||
            !int.TryParse(userIdClaim.Value, out int customerId))
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        // Kiểm tra đơn hàng có thuộc về khách hiện tại không
        var orderExists = await _context.Orders
            .AnyAsync(x =>
                x.Id == id &&
                x.CustomerId == customerId);

        if (!orderExists)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        var history = await _context.OrderStatusHistories
            .Where(x => x.OrderId == id)
            .OrderBy(x => x.ChangedAt)
            .Select(x => new
            {
                x.Id,
                status = x.Status.ToString(),
                x.Note,
                x.ChangedAt,
                x.ChangedByUserId
            })
            .ToListAsync();

        return Ok(new
        {
            orderId = id,
            history
        });
    }

    // ============================
    // POST: api/Orders/{id}/cancel
    // Khách hủy đơn hàng
    // ============================
    [HttpPost("{id}/cancel")]
    public async Task<IActionResult> CancelOrder(int id)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null ||
            !int.TryParse(userIdClaim.Value, out int customerId))
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        // Tìm đơn của chính khách hàng
        var order = await _context.Orders
            .FirstOrDefaultAsync(x =>
                x.Id == id &&
                x.CustomerId == customerId);

        if (order == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        // Chỉ cho hủy khi Pending hoặc Confirmed
        if (order.Status != OrderStatus.Pending &&
            order.Status != OrderStatus.Confirmed)
        {
            return BadRequest(new
            {
                message =
                    $"Không thể hủy đơn hàng đang ở trạng thái {order.Status}."
            });
        }

        // Cập nhật trạng thái
        order.Status = OrderStatus.Cancelled;
        order.UpdatedAt = DateTime.UtcNow;

        // Lưu lịch sử
        var history = new OrderStatusHistory
        {
            OrderId = order.Id,
            Status = OrderStatus.Cancelled,
            Note = "Khách hàng hủy đơn hàng",
            ChangedByUserId = customerId,
            ChangedAt = DateTime.UtcNow
        };

        _context.OrderStatusHistories.Add(history);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Hủy đơn hàng thành công.",
            orderId = order.Id,
            status = order.Status.ToString(),
            cancelledAt = order.UpdatedAt
        });
    }

    // ============================
    // GET: api/Orders/{id}
    // Chi tiết đơn hàng
    // ============================
    [HttpGet("{id}")]
    public async Task<IActionResult> GetOrder(int id)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null ||
            !int.TryParse(userIdClaim.Value, out int customerId))
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var order = await _context.Orders
            .Where(x =>
                x.Id == id &&
                x.CustomerId == customerId)
            .Include(x => x.OrderDetails)
                .ThenInclude(x => x.Service)
            .FirstOrDefaultAsync();

        if (order == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        return Ok(new
        {
            order.Id,

            status = order.Status.ToString(),

            order.PickupAddress,

            order.DeliveryAddress,

            order.ContactPhone,

            order.Note,

            order.TotalAmount,

            order.CreatedAt,

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

    [HttpPut("{id}/status")]
    [Authorize(Roles = "Admin,Staff,Shipper")]
    public async Task<IActionResult> UpdateOrderStatus(int id, UpdateOrderStatusRequest request)
    {
        var order = await _context.Orders
            .FirstOrDefaultAsync(x => x.Id == id);

        if (order == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        if (!Enum.TryParse<OrderStatus>(
                request.Status,
                true,
                out var newStatus))
        {
            return BadRequest(new
            {
                message = "Trạng thái đơn hàng không hợp lệ."
            });
        }

        var currentStatus = order.Status;

        var currentUserRole =
            User.FindFirst(ClaimTypes.Role)?.Value;

        var currentUserIdClaim =
            User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        int.TryParse(
            currentUserIdClaim,
            out var currentUserId);

        // Không cho cập nhật sang cùng trạng thái
        if (currentStatus == newStatus)
        {
            return BadRequest(new
            {
                message = "Đơn hàng đã ở trạng thái này."
            });
        }

        // ============================================================
        // PHÂN QUYỀN SHIPPER
        // ============================================================

        if (currentUserRole == "Shipper")
        {
            if (order.ShipperId != currentUserId)
            {
                return Forbid();
            }

            var isValidShipperTransition =
                (currentStatus == OrderStatus.Confirmed &&
                 newStatus == OrderStatus.PickingUp)

                ||

                (currentStatus == OrderStatus.PickingUp &&
                 newStatus == OrderStatus.Received)

                ||

                (currentStatus == OrderStatus.Ready &&
                 newStatus == OrderStatus.Delivering)

                ||

                (currentStatus == OrderStatus.Delivering &&
                 newStatus == OrderStatus.Completed);

            if (!isValidShipperTransition)
            {
                return BadRequest(new
                {
                    message =
                        $"Shipper không thể chuyển từ " +
                        $"{currentStatus} sang {newStatus}."
                });
            }
        }

        // Kiểm tra chuyển trạng thái hợp lệ
        var isValidTransition = IsValidStatusTransition(
            currentStatus,
            newStatus);

        if (!isValidTransition)
        {
            return BadRequest(new
            {
                message =
                    $"Không thể chuyển từ {currentStatus} sang {newStatus}."
            });
        }

        // Admin/Staff chỉ xử lý xác nhận đơn và các bước tại cửa hàng.
        // Các bước lấy/giao đồ chỉ được cập nhật bởi shipper được phân công.
        if (currentUserRole == "Admin" || currentUserRole == "Staff")
        {
            var isValidStaffTransition =
                (currentStatus == OrderStatus.Pending &&
                 newStatus == OrderStatus.Confirmed) ||
                (currentStatus == OrderStatus.Received &&
                 newStatus == OrderStatus.Washing) ||
                (currentStatus == OrderStatus.Washing &&
                 newStatus == OrderStatus.Ready) ||
                // Web Admin có nút hủy đơn; chỉ cho hủy trước khi lấy đồ.
                ((currentStatus == OrderStatus.Pending ||
                  currentStatus == OrderStatus.Confirmed) &&
                 newStatus == OrderStatus.Cancelled);

            if (!isValidStaffTransition)
            {
                return BadRequest(new
                {
                    message = $"Admin/Staff không thể chuyển đơn từ {currentStatus} sang {newStatus}."
                });
            }
        }

        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        int? changedByUserId = null;

        if (userIdClaim != null &&
            int.TryParse(userIdClaim.Value, out var userId))
        {
            changedByUserId = userId;
        }

        // Khi shipper hoàn tất nhiệm vụ lấy đồ (Received), giải phóng shipper.
        // Đơn sẽ được phân công lại ở trạng thái Ready cho nhiệm vụ giao đồ.
        order.Status = newStatus;
        if (newStatus == OrderStatus.Received && currentStatus == OrderStatus.PickingUp)
        {
            order.ShipperId = null;
        }
        order.UpdatedAt = DateTime.UtcNow;

        // Lưu lịch sử
        var history = new OrderStatusHistory
        {
            OrderId = order.Id,
            Status = newStatus,
            Note = request.Note,
            ChangedByUserId = changedByUserId,
            ChangedAt = DateTime.UtcNow
        };

        _context.OrderStatusHistories.Add(history);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật trạng thái đơn hàng thành công.",
            orderId = order.Id,
            oldStatus = currentStatus.ToString(),
            newStatus = newStatus.ToString(),
            note = request.Note,
            updatedAt = order.UpdatedAt
        });
    }
    private bool IsValidStatusTransition(
    OrderStatus currentStatus,
    OrderStatus newStatus)
    {
        return currentStatus switch
        {
            OrderStatus.Pending =>
                newStatus == OrderStatus.Confirmed ||
                newStatus == OrderStatus.Cancelled,

            OrderStatus.Confirmed =>
                newStatus == OrderStatus.PickingUp ||
                newStatus == OrderStatus.Cancelled,

            OrderStatus.PickingUp =>
                newStatus == OrderStatus.Received,

            OrderStatus.Received =>
                newStatus == OrderStatus.Washing,

            OrderStatus.Washing =>
                newStatus == OrderStatus.Ready,

            OrderStatus.Ready =>
                newStatus == OrderStatus.Delivering,

            OrderStatus.Delivering =>
                newStatus == OrderStatus.Completed,

            OrderStatus.Completed =>
                false,

            OrderStatus.Cancelled =>
                false,

            _ => false
        };
    }
}