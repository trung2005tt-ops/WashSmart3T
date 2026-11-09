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
    // ORDER STATUS & TYPE
    // ============================
    public OrderStatus Status { get; set; } = OrderStatus.Pending;
    public string OrderType { get; set; } = "Delivery"; // Delivery / StorePickup

    // ============================
    // ADDRESS & CONTACT
    // ============================
    public string PickupAddress { get; set; } = string.Empty;
    public string DeliveryAddress { get; set; } = string.Empty;
    public string ContactPhone { get; set; } = string.Empty;
    public string? Note { get; set; }

    // ============================
    // FINANCIAL BREAKDOWN (SINGLE SOURCE OF TRUTH)
    // ============================
    public decimal ShippingFee { get; set; } = 0;
    public decimal AddonFee { get; set; } = 0;
    public decimal DiscountAmount { get; set; } = 0;
    public decimal TotalAmount { get; set; }
    public string PaymentMethod { get; set; } = "COD"; // Cash / COD / MoMo / BankTransfer

    // ============================
    // AUDIT & DELIVERY PROOF
    // ============================
    public string? DeliveryProofPhotoUrl { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }

    public ICollection<OrderDetail> OrderDetails { get; set; }
        = new List<OrderDetail>();
}
