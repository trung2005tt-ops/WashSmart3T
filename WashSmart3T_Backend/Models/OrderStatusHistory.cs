namespace WashSmart.API.Models;

public class OrderStatusHistory
{
    public int Id { get; set; }

    public int OrderId { get; set; }
    public Order? Order { get; set; }

    public OrderStatus Status { get; set; }

    public string? Note { get; set; }

    public int? ChangedByUserId { get; set; }
    public User? ChangedByUser { get; set; }

    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;
}