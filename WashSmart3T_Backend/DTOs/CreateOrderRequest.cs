namespace WashSmart.API.DTOs;

public class CreateOrderRequest
{
    public string PickupAddress { get; set; } = string.Empty;

    public string DeliveryAddress { get; set; } = string.Empty;

    public string ContactPhone { get; set; } = string.Empty;

    public string? Note { get; set; }

    public List<CreateOrderDetailRequest> Items { get; set; }
        = new();
}

public class CreateOrderDetailRequest
{
    public int ServiceId { get; set; }

    public decimal Quantity { get; set; }
}