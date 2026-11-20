namespace WashSmart.API.Models;

public class ShiftHandover
{
    public int Id { get; set; }

    // ============================
    // SHIPPER
    // ============================
    public int ShipperId { get; set; }
    public User? Shipper { get; set; }

    // ============================
    // STATS & TOTALS
    // ============================
    public int TotalOrders { get; set; }
    public int CashOrdersCount { get; set; }
    public int OnlineOrdersCount { get; set; }
    public decimal CashAmount { get; set; } // Tiền mặt shipper nộp lại cho quầy
    public decimal OnlineAmount { get; set; } // Tiền khách thanh toán online/VietQR

    // ============================
    // STATUS & NOTES
    // ============================
    public string Status { get; set; } = "Pending"; // Pending / Confirmed / Rejected
    public string? Note { get; set; } // Ghi chú của shipper khi nộp tiền
    public string? ManagerNote { get; set; } // Ghi chú của quản lý khi nhận tiền

    // ============================
    // AUDIT & RECONCILIATION
    // ============================
    public int? ConfirmedByUserId { get; set; }
    public User? ConfirmedByUser { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ConfirmedAt { get; set; }

    // Danh sách các OrderId thuộc ca này dạng JSON, ví dụ: [10, 12, 14]
    public string? OrderIdsJson { get; set; }
}
