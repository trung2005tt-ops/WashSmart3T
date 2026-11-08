namespace WashSmart.API.Models;

public class Order
{
    public int Id { get; set; }

    // ============================
    // CUSTOMER
    // ============================

    public int CustomerId { get; set; }

    public User? Customer { get; set; }

    // ============================
    // SHIPPER
    // ============================

    public int? ShipperId { get; set; }

    public User? Shipper { get; set; }

    // ============================
    // ORDER
    // ============================

    public OrderStatus Status { get; set; } = OrderStatus.Pending;

    public string PickupAddress { get; set; } = string.Empty;

    public string DeliveryAddress { get; set; } = string.Empty;

    public string ContactPhone { get; set; } = string.Empty;

    public string? Note { get; set; }

    public decimal TotalAmount { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public DateTime? UpdatedAt { get; set; }

    public ICollection<OrderDetail> OrderDetails { get; set; }
        = new List<OrderDetail>();
}