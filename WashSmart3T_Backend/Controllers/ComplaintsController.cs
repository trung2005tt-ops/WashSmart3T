using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ComplaintsController : ControllerBase
{
    private static readonly string ComplaintsFilePath = Path.Combine(AppContext.BaseDirectory, "complaints.json");
    private static readonly object _fileLock = new();

    public ComplaintsController()
    {
        EnsureInitialData();
    }

    [HttpGet]
    public IActionResult GetComplaints([FromQuery] string? status, [FromQuery] string? search)
    {
        lock (_fileLock)
        {
            var list = LoadComplaints();

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

    [HttpGet("{id}")]
    public IActionResult GetById(int id)
    {
        lock (_fileLock)
        {
            var list = LoadComplaints();
            var item = list.FirstOrDefault(c => c.Id == id);
            if (item == null) return NotFound(new { message = "Không tìm thấy khiếu nại." });
            return Ok(item);
        }
    }

    [HttpPost]
    public IActionResult CreateComplaint([FromBody] CreateComplaintRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.CustomerPhone) || string.IsNullOrWhiteSpace(request.ItemDescription))
        {
            return BadRequest(new { message = "Vui lòng nhập đầy đủ số điện thoại và mô tả món đồ sự cố." });
        }

        lock (_fileLock)
        {
            var list = LoadComplaints();
            int nextId = list.Any() ? list.Max(c => c.Id) + 1 : 1;

            var ticket = new ComplaintModel
            {
                Id = nextId,
                TicketCode = $"KN-{DateTime.Now:yyyyMMdd}-{nextId:D3}",
                OrderId = request.OrderId,
                OrderCode = request.OrderId.HasValue ? $"#WS3T-{request.OrderId.Value:D4}" : "#WS3T-TRỰC TIẾP",
                CustomerName = string.IsNullOrWhiteSpace(request.CustomerName) ? "Khách hàng" : request.CustomerName.Trim(),
                CustomerPhone = request.CustomerPhone.Trim(),
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

    [HttpPut("{id}/resolve")]
    public IActionResult ResolveComplaint(int id, [FromBody] ResolveComplaintRequest request)
    {
        lock (_fileLock)
        {
            var list = LoadComplaints();
            var item = list.FirstOrDefault(c => c.Id == id);
            if (item == null) return NotFound(new { message = "Không tìm thấy hồ sơ khiếu nại." });

            item.Status = "Completed";
            item.Resolution = request.Resolution ?? "Approved"; // Approved, Rejected, Refunded
            item.ApprovedAmount = request.ApprovedAmount ?? item.RequestedRefund;
            item.StaffNote = request.StaffNote ?? "Đã giải quyết theo quy chuẩn bảo hành WashSmart 3T.";
            item.ResolvedAt = DateTime.UtcNow.ToString("o");
            item.ResolvedBy = request.ResolvedBy ?? "Quản lý cửa hàng";

            SaveComplaints(list);

            return Ok(new
            {
                message = "Hồ sơ khiếu nại đã được cập nhật thành công!",
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
    public string CustomerPhone { get; set; } = string.Empty;
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
    public string? ResolvedBy { get; set; }
}