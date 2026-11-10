namespace WashSmart.API.Models;

public class Promotion
{
    public int Id { get; set; }

    public string Code { get; set; } = string.Empty; // e.g. "CHAOBANMOI", "FREESHIP50K", "GIAT3T20"

    public string Title { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    public string DiscountType { get; set; } = "Percentage"; // "Percentage" or "FixedAmount"

    public decimal DiscountValue { get; set; } // 15 (%) or 30000 (VND)

    public decimal MinOrderAmount { get; set; } = 0;

    public decimal? MaxDiscountAmount { get; set; }

    public DateTime StartDate { get; set; } = DateTime.UtcNow;

    public DateTime EndDate { get; set; } = DateTime.UtcNow.AddMonths(3);

    public int UsageLimit { get; set; } = 1000;

    public int UsedCount { get; set; } = 0;

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
