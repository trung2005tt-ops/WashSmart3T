namespace WashSmart.API.Models;

public class Complaint
{
    public int Id { get; set; }

    public string TicketCode { get; set; } = string.Empty;

    public int? CustomerId { get; set; }
    public User? Customer { get; set; }

    public int? OrderId { get; set; }
    public Order? Order { get; set; }

    public string OrderCode { get; set; } = string.Empty;

    public string IncidentType { get; set; } = string.Empty;

    public string Severity { get; set; } = "Medium";

    public string ItemDescription { get; set; } = string.Empty;

    public string? PhotoUrl { get; set; }

    public string? CustomerNote { get; set; }

    public decimal RequestedRefund { get; set; } = 0;

    public decimal? ApprovedAmount { get; set; }

    public string Status { get; set; } = "Pending"; // Pending, Completed, Approved, Rejected

    public string? Resolution { get; set; }

    public string? StaffNote { get; set; }

    public string? ResolvedBy { get; set; }

    public DateTime? ResolvedAt { get; set; }

    public string? SealCode { get; set; }

    public string? SealStatus { get; set; } = "Intact";

    public string? DrumInfo { get; set; }

    public string? ShipperName { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }
}
