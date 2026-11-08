namespace WashSmart.API.DTOs;

public class ServicePriceUpdateRequest
{
    public decimal Price { get; set; }

    public string Unit { get; set; } = string.Empty;

    public decimal? MinimumPrice { get; set; }
}