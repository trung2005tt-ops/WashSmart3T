namespace WashSmart.API.DTOs;

public class UpdateOrderStatusRequest
{
    public string Status { get; set; } = string.Empty;
    public string? Note { get; set; }
}