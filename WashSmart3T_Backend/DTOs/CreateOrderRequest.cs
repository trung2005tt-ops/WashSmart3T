using System.ComponentModel.DataAnnotations;

namespace WashSmart.API.DTOs;

public class CreateOrderRequest
{
    [Required(ErrorMessage = "Địa chỉ nhận đồ không được để trống.")]
    [StringLength(255, MinimumLength = 5, ErrorMessage = "Địa chỉ nhận đồ phải từ 5 đến 255 ký tự.")]
    public string PickupAddress { get; set; } = string.Empty;

    [Required(ErrorMessage = "Địa chỉ giao đồ không được để trống.")]
    [StringLength(255, MinimumLength = 5, ErrorMessage = "Địa chỉ giao đồ phải từ 5 đến 255 ký tự.")]
    public string DeliveryAddress { get; set; } = string.Empty;

    [Required(ErrorMessage = "Số điện thoại liên hệ không được để trống.")]
    [RegularExpression(@"^0(3|5|7|8|9)[0-9]{8}$", ErrorMessage = "Số điện thoại không đúng định dạng di động Việt Nam.")]
    public string ContactPhone { get; set; } = string.Empty;

    [StringLength(1000, ErrorMessage = "Ghi chú không được vượt quá 1000 ký tự.")]
    public string? Note { get; set; }

    [Required(ErrorMessage = "Đơn hàng phải có ít nhất 1 dịch vụ.")]
    [MinLength(1, ErrorMessage = "Đơn hàng phải có ít nhất 1 dịch vụ.")]
    public List<CreateOrderDetailRequest> Items { get; set; } = new();
}

public class CreateOrderDetailRequest
{
    [Required(ErrorMessage = "Dịch vụ không hợp lệ.")]
    [Range(1, int.MaxValue, ErrorMessage = "Dịch vụ không hợp lệ.")]
    public int ServiceId { get; set; }

    [Required(ErrorMessage = "Số lượng/khối lượng không hợp lệ.")]
    [Range(0.1, 1000.0, ErrorMessage = "Số lượng/khối lượng phải từ 0.1 đến 1000.")]
    public decimal Quantity { get; set; }
}
