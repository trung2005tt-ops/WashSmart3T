namespace WashSmart.API.Models;

public enum OrderStatus
{
    Pending = 0,        // Chờ xác nhận
    Confirmed = 1,      // Đã xác nhận
    PickingUp = 2,      // Đang lấy đồ
    Received = 3,      // Đã nhận đồ
    Washing = 4,       // Đang giặt
    Ready = 5,         // Đã giặt xong
    Delivering = 6,    // Đang giao
    Completed = 7,     // Hoàn thành
    Cancelled = 8      // Đã hủy
}