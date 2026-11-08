
namespace WashSmart.API.DTOs;

public class PickupConfirmationRequest
{
    public bool CustomerConfirmed { get; set; }

    public string? Note { get; set; }

    public List<PickupConfirmationItemRequest> Items { get; set; }
        = new();
}

public class PickupConfirmationItemRequest
{
    public int ServiceId { get; set; }

    public decimal Quantity { get; set; }
}
