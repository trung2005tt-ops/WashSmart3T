namespace WashSmart.API.Models;

public enum PaymentMethod
{
    Cash = 0,
    MoMo = 1,
    BankTransfer = 2
}

public enum PaymentStatus
{
    Pending = 0,
    Paid = 1,
    Failed = 2,
    Refunded = 3
}

public class Payment
{
    public int Id { get; set; }

    // ============================
    // ORDER (unique)
    // ============================
    public int OrderId { get; set; }
    public Order? Order { get; set; }

    // ============================
    // PAYMENT DETAILS
    // ============================
    public decimal Amount { get; set; }
    public PaymentMethod Method { get; set; } = PaymentMethod.Cash;
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? PaidAt { get; set; }
    public string? PaymentNote { get; set; }

    // ============================
    // REFUND AUDIT TRAIL
    // ============================
    public decimal? RefundedAmount { get; set; }
    public string? RefundReason { get; set; }
    public DateTime? RefundedAt { get; set; }
    public string? RefundedBy { get; set; }
    public int? ComplaintId { get; set; }
}
