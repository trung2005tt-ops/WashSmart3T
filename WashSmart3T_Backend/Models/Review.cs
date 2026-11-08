namespace WashSmart.API.Models;

public class Review
{
    public int Id { get; set; }

    // ============================
    // ORDER (unique)
    // ============================

    public int OrderId { get; set; }

    public Order? Order { get; set; }

    // ============================
    // REVIEW
    // ============================

    public int CustomerId { get; set; }

    public User? Customer { get; set; }

    /// <summary>1..5 sao</summary>
    public int Rating { get; set; }

    public string Comment { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
