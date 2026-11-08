namespace WashSmart.API.Models;

public class OrderDetail
{
    public int Id { get; set; }

    public int OrderId { get; set; }

    public Order? Order { get; set; }

    // Dịch vụ được chọn
    public int ServiceId { get; set; }

    public Service? Service { get; set; }

    // Số lượng
    public decimal Quantity { get; set; }

    // Đơn vị tại thời điểm đặt hàng
    public string Unit { get; set; } = string.Empty;

    // Giá tại thời điểm khách đặt
    public decimal UnitPrice { get; set; }

    // Thành tiền
    public decimal TotalPrice { get; set; }
}