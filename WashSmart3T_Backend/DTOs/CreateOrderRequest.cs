using System.ComponentModel.DataAnnotations;

namespace WashSmart.API.DTOs;

public class CreateOrderRequest
{
    [Required(ErrorMessage = "Địa chỉ nhận đồ không được để trống.")]
    [StringLength(500, MinimumLength = 1, ErrorMessage = "Địa chỉ nhận đồ không hợp lệ.")]
    public string PickupAddress { get; set; } = string.Empty;

    [StringLength(500, ErrorMessage = "Địa chỉ giao đồ không được vượt quá 500 ký tự.")]
    public string? DeliveryAddress { get; set; }

    [StringLength(50, ErrorMessage = "Số điện thoại không được vượt quá 50 ký tự.")]
    public string? ContactPhone { get; set; }

    [StringLength(1000, ErrorMessage = "Ghi chú không được vượt quá 1000 ký tự.")]
    public string? Note { get; set; }

    // ============================
    // CÁC THÔNG SỐ TÀI CHÍNH CẤU TRÚC
    // ============================
    public decimal ShippingFee { get; set; } = 0;
    public decimal AddonFee { get; set; } = 0;
    public decimal DiscountAmount { get; set; } = 0;
    public string PaymentMethod { get; set; } = "COD"; // COD / BankTransfer / MoMo / Cash
    public string OrderType { get; set; } = "Delivery"; // Delivery / StorePickup
    public double? DistanceKm { get; set; }
    public bool IsExpress { get; set; } = false;

    [Required(ErrorMessage = "Đơn hàng phải có ít nhất 1 dịch vụ.")]
    [MinLength(1, ErrorMessage = "Đơn hàng phải có ít nhất 1 dịch vụ.")]
    public List<CreateOrderDetailRequest> Items { get; set; } = new();
}

public class CreateOrderDetailRequest
{
    [Required(ErrorMessage = "Dịch vụ không hợp lệ.")]
    [Range(1, int.MaxValue, ErrorMessage = "Dịch vụ không hợp lệ.")]
    public int ServiceId { get; set; }

    [Range(0, 1000.0, ErrorMessage = "Số lượng/khối lượng phải từ 0 đến 1000.")]
    public decimal Quantity { get; set; } = 0;
}

public class DeliveryProofRequest
{
    public string? PhotoUrl { get; set; }
    public string? ProofPhotoUrl { get; set; }
    public string? Note { get; set; }
    public bool ConfirmPaymentCollected { get; set; } = true;

    public string GetEffectivePhotoUrl()
    {
        if (!string.IsNullOrWhiteSpace(PhotoUrl)) return PhotoUrl.Trim();
        if (!string.IsNullOrWhiteSpace(ProofPhotoUrl)) return ProofPhotoUrl.Trim();
        return string.Empty;
    }
}
