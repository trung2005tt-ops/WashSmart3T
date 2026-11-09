using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using System.Text.Json;
using WashSmart.API.Data;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize] // BẮT BUỘC ĐĂNG NHẬP CHO TOÀN BỘ ENDPOINTS KHIẾU NẠI
public class ComplaintsController : ControllerBase
{
    private static readonly string ComplaintsFilePath = Path.Combine(AppContext.BaseDirectory, "complaints.json");
    private static readonly object _fileLock = new();
    private readonly ApplicationDbContext _context;

    public ComplaintsController(ApplicationDbContext context)
    {
        _context = context;
        EnsureInitialData();
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
    public IActionResult GetComplaints([FromQuery] string? status, [FromQuery] string? search)
    {
        var (userId, role, phone, _) = GetCurrentUser();

        lock (_fileLock)
        {
            var list = LoadComplaints();

            // Phân quyền dữ liệu: Customer chỉ xem khiếu nại do mình gửi
            if (role != "Admin" && role != "Staff")
            {
                list = list.Where(c => (c.UserId.HasValue && c.UserId == userId) ||
                                       (!string.IsNullOrEmpty(phone) && c.CustomerPhone == phone)).ToList();
            }

            if (!string.IsNullOrWhiteSpace(status) && status.ToLower() != "all")
            {
                if (status.ToLower() == "pending")
                    list = list.Where(c => c.Status == "Pending" || c.Status == "Chờ xử lý").ToList();
                else if (status.ToLower() == "completed")
                    list = list.Where(c => c.Status == "Completed" || c.Status == "Approved" || c.Status == "Rejected" || c.Status == "Đã hoàn tất").ToList();
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var s = search.ToLower().Trim();
                list = list.Where(c => 
                    c.TicketCode.ToLower().Contains(s) || 
                    c.CustomerName.ToLower().Contains(s) || 
                    c.CustomerPhone.Contains(s) || 
                    c.OrderCode.ToLower().Contains(s)).ToList();
            }

            return Ok(list);
        }
    }

    // ============================================================
    // GET: api/Complaints/{id}
    // Lấy chi tiết khiếu nại (có kiểm tra quyền sở hữu).
    // ============================================================
    [HttpGet("{id}")]
    public IActionResult GetById(int id)
    {
        var (userId, role, phone, _) = GetCurrentUser();

        lock (_fileLock)
        {
            var list = LoadComplaints();
            var item = list.FirstOrDefault(c => c.Id == id);
            if (item == null) return NotFound(new { message = "Không tìm thấy khiếu nại." });

            // Kiểm tra quyền: nếu là Customer thì phải là chủ khiếu nại
            if (role != "Admin" && role != "Staff")
            {
                var isOwner = (item.UserId.HasValue && item.UserId == userId) ||
                              (!string.IsNullOrEmpty(phone) && item.CustomerPhone == phone);
                if (!isOwner)
                {
                    return Forbid();
                }
            }

            return Ok(item);
        }
    }

    // ============================================================
    // POST: api/Complaints
    // Tạo khiếu nại mới:
    // 1. Gắn trực tiếp với UserId của người dùng đang đăng nhập.
    // 2. Nếu có OrderId, xác thực đơn hàng tồn tại và thuộc về người dùng này.
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
        if (request.OrderId.HasValue && request.OrderId.Value > 0)
        {
            var order = await _context.Orders.AsNoTracking().FirstOrDefaultAsync(o => o.Id == request.OrderId.Value);
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

            orderCode = $"#WS3T-{order.Id:D4}";
        }

        lock (_fileLock)
        {
            var list = LoadComplaints();
            int nextId = list.Any() ? list.Max(c => c.Id) + 1 : 1;

            var ticket = new ComplaintModel
            {
                Id = nextId,
                TicketCode = $"KN-{DateTime.Now:yyyyMMdd}-{nextId:D3}",
                UserId = userId.Value,
                OrderId = request.OrderId,
                OrderCode = orderCode,
                CustomerName = effectiveName,
                CustomerPhone = effectivePhone,
                IncidentType = string.IsNullOrWhiteSpace(request.IncidentType) ? "Hỏng / Rách vải" : request.IncidentType.Trim(),
                Severity = request.Severity ?? "Medium",
                ItemDescription = request.ItemDescription.Trim(),
                PhotoUrl = request.PhotoUrl ?? "",
                CustomerNote = request.CustomerNote ?? "",
                RequestedRefund = request.RequestedRefund ?? 0,
                Status = "Pending",
                CreatedAt = DateTime.UtcNow.ToString("o")
            };

            list.Insert(0, ticket);
            SaveComplaints(list);

            return Ok(new
            {
                message = "Gửi khiếu nại thành công! Chuyên viên bảo hiểm sẽ phản hồi trong vòng 15 phút.",
                complaint = ticket
            });
        }
    }

    // ============================================================
    // PUT: api/Complaints/{id}/resolve
    // Chỉ Quản trị viên (Admin) hoặc Nhân viên cửa hàng (Staff) mới được duyệt bồi hoàn.
    // LƯU Ý BẢO MẬT: ResolvedBy được lấy tự động từ tài khoản nhân viên đang đăng nhập,
    // nghiêm cấm client tự khai khống hoặc tự duyệt số tiền bồi hoàn.
    // ============================================================
    [HttpPut("{id}/resolve")]
    [Authorize(Roles = "Admin,Staff")]
    public IActionResult ResolveComplaint(int id, [FromBody] ResolveComplaintRequest request)
    {
        var (_, role, _, staffName) = GetCurrentUser();
        if (string.IsNullOrWhiteSpace(staffName))
        {
            staffName = role == "Admin" ? "Quản trị viên" : "Nhân viên tiếp nhận";
        }

        lock (_fileLock)
        {
            var list = LoadComplaints();
            var item = list.FirstOrDefault(c => c.Id == id);
            if (item == null) return NotFound(new { message = "Không tìm thấy hồ sơ khiếu nại." });

            // Kiểm tra số tiền bồi hoàn không được âm
            var amount = request.ApprovedAmount ?? item.RequestedRefund;
            if (amount < 0)
            {
                return BadRequest(new { message = "Số tiền bồi hoàn không hợp lệ." });
            }

            item.Status = "Completed";
            item.Resolution = request.Resolution ?? "Approved"; // Approved, Rejected, Refunded
            item.ApprovedAmount = amount;
            item.StaffNote = request.StaffNote ?? "Đã giải quyết theo quy chuẩn bảo hành WashSmart 3T.";
            item.ResolvedAt = DateTime.UtcNow.ToString("o");
            item.ResolvedBy = staffName; // Lấy danh tính nhân viên thực tế đã đăng nhập

            SaveComplaints(list);

            return Ok(new
            {
                message = "Hồ sơ khiếu nại đã được phê duyệt xử lý thành công!",
                complaint = item
            });
        }
    }

    private static void EnsureInitialData()
    {
        lock (_fileLock)
        {
            if (!System.IO.File.Exists(ComplaintsFilePath))
            {
                var initial = new List<ComplaintModel>
                {
                    new ComplaintModel
                    {
                        Id = 1,
                        TicketCode = "KN-20261104-001",
                        UserId = 1,
                        OrderId = 19,
                        OrderCode = "#WS3T-0019",
                        CustomerName = "Như Nguyễn",
                        CustomerPhone = "0999222111",
                        IncidentType = "Bung chỉ mép áo sơ mi",
                        Severity = "Low",
                        ItemDescription = "Áo sơ mi trắng lụa công sở bị sờn mép chỉ cổ tay sau khi giặt sấy.",
                        PhotoUrl = "",
                        CustomerNote = "Nhờ xưởng giặt hỗ trợ may dằn chỉ lại hoặc bồi thường phí sửa áo.",
                        RequestedRefund = 50000,
                        Status = "Pending",
                        CreatedAt = DateTime.UtcNow.AddMinutes(-45).ToString("o")
                    },
                    new ComplaintModel
                    {
                        Id = 2,
                        TicketCode = "KN-20261103-002",
                        UserId = 2,
                        OrderId = 18,
                        OrderCode = "#WS3T-0018",
                        CustomerName = "Hoàng Tuấn Kiên",
                        CustomerPhone = "0944444444",
                        IncidentType = "Lem màu khăn tắm",
                        Severity = "Medium",
                        ItemDescription = "Khăn tắm cotton màu trắng bị phai màu xanh nhạt từ đồ giặt chung.",
                        PhotoUrl = "",
                        CustomerNote = "Đã giặt hấp xử lý màu lại, khách hàng hài lòng.",
                        RequestedRefund = 120000,
                        ApprovedAmount = 120000,
                        Status = "Completed",
                        Resolution = "Approved",
                        StaffNote = "Đã chi trả đền bù 100% giá trị khăn tắm qua ví WashPoints và tặng mã freeship.",
                        ResolvedAt = DateTime.UtcNow.AddHours(-18).ToString("o"),
                        ResolvedBy = "Nguyễn Kiều Như",
                        CreatedAt = DateTime.UtcNow.AddDays(-1).ToString("o")
                    }
                };
                SaveComplaints(initial);
            }
        }
    }

    private static List<ComplaintModel> LoadComplaints()
    {
        try
        {
            if (!System.IO.File.Exists(ComplaintsFilePath)) return new List<ComplaintModel>();
            var json = System.IO.File.ReadAllText(ComplaintsFilePath);
            return JsonSerializer.Deserialize<List<ComplaintModel>>(json, new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new List<ComplaintModel>();
        }
        catch
        {
            return new List<ComplaintModel>();
        }
    }

    private static void SaveComplaints(List<ComplaintModel> list)
    {
        var json = JsonSerializer.Serialize(list, new JsonSerializerOptions { WriteIndented = true });
        System.IO.File.WriteAllText(ComplaintsFilePath, json);
    }
}

public class ComplaintModel
{
    public int Id { get; set; }
    public string TicketCode { get; set; } = string.Empty;
    public int? UserId { get; set; }
    public int? OrderId { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public string CustomerName { get; set; } = string.Empty;
    public string CustomerPhone { get; set; } = string.Empty;
    public string IncidentType { get; set; } = string.Empty;
    public string Severity { get; set; } = "Low";
    public string ItemDescription { get; set; } = string.Empty;
    public string PhotoUrl { get; set; } = string.Empty;
    public string CustomerNote { get; set; } = string.Empty;
    public decimal RequestedRefund { get; set; }
    public decimal? ApprovedAmount { get; set; }
    public string Status { get; set; } = "Pending";
    public string? Resolution { get; set; }
    public string? StaffNote { get; set; }
    public string? ResolvedBy { get; set; }
    public string? ResolvedAt { get; set; }
    public string CreatedAt { get; set; } = string.Empty;
}

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
}
