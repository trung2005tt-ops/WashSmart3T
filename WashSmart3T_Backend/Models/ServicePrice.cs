namespace WashSmart.API.Models;

public class ServicePrice
{
    public int Id { get; set; }

    public int ServiceId { get; set; }

    public Service? Service { get; set; }

    public decimal Price { get; set; }

    public string Unit { get; set; } = string.Empty;

    public decimal? MinimumPrice { get; set; }

    public DateTime EffectiveFrom { get; set; }

    public DateTime? EffectiveTo { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}