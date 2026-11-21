using System.ComponentModel.DataAnnotations;

namespace WashSmart.API.DTOs;

public class RegisterRequest
{
    [Required(ErrorMessage = "Họ tên không được để trống.")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Họ tên phải từ 2 đến 100 ký tự.")]
    public string FullName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Số điện thoại không được để trống.")]
    [RegularExpression(@"^(\+?84|0)[0-9\s\.\-]{8,15}$", ErrorMessage = "Số điện thoại không đúng định dạng di động Việt Nam.")]
    public string Phone { get; set; } = string.Empty;

    [Required(ErrorMessage = "Email không được để trống.")]
    [EmailAddress(ErrorMessage = "Email không đúng định dạng hợp lệ.")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Mật khẩu không được để trống.")]
    [StringLength(100, MinimumLength = 6, ErrorMessage = "Mật khẩu phải từ 6 đến 100 ký tự.")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "Vui lòng nhập mã OTP xác thực.")]
    [StringLength(6, MinimumLength = 6, ErrorMessage = "Mã OTP phải gồm đúng 6 chữ số.")]
    public string OtpCode { get; set; } = string.Empty;
}

public class SendOtpRequest
{
    [Required(ErrorMessage = "Vui lòng nhập số điện thoại.")]
    [RegularExpression(@"^(\+?84|0)[0-9\s\.\-]{8,15}$", ErrorMessage = "Số điện thoại không đúng định dạng di động Việt Nam.")]
    public string Phone { get; set; } = string.Empty;

    [EmailAddress(ErrorMessage = "Email không đúng định dạng hợp lệ.")]
    public string? Email { get; set; }

    public string? FullName { get; set; }

    public string Purpose { get; set; } = "Register";
}
