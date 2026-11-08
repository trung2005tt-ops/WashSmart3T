using System.ComponentModel.DataAnnotations;
using WashSmart.API.Models;

namespace WashSmart.API.DTOs;

// ============================================================
// REQUEST TẠO THANH TOÁN CHO ĐƠN HÀNG
// ============================================================

public class CreatePaymentRequest
{
    // Phương thức thanh toán: Cash, MoMo, BankTransfer
    [Required]
    public string Method { get; set; } = string.Empty;
}

// ============================================================
// REQUEST CẬP NHẬT TRẠNG THÁI THANH TOÁN
// (Staff/Admin xác nhận đã thu tiền, hoàn tiền...)
// ============================================================

// ============================================================
// Request shipper/admin xác nhận đã thu tiền
// ============================================================

public class ConfirmPaymentRequest
{
    public string? Note { get; set; }
}

public class UpdatePaymentStatusRequest
{
    // Trạng thái mới: Pending, Paid, Failed, Refunded
    [Required]
    public string Status { get; set; } = string.Empty;

    public string? Note { get; set; }
}
