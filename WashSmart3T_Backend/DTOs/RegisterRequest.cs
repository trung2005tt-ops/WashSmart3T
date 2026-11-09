using System.ComponentModel.DataAnnotations;

namespace WashSmart.API.DTOs;

public class RegisterRequest
{
    [Required(ErrorMessage = "Họ tên không được để trống.")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Họ tên phải từ 2 đến 100 ký tự.")]
    public string FullName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Số điện thoại không được để trống.")]
    [RegularExpression(@"^0(3|5|7|8|9)[0-9]{8}$", ErrorMessage = "Số điện thoại không đúng định dạng di động Việt Nam (10 số, bắt đầu bằng 03, 05, 07, 08, 09).")]
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
    [RegularExpression(@"^0(3|5|7|8|9)[0-9]{8}$", ErrorMessage = "Số điện thoại không đúng định dạng di động Việt Nam (10 số).")]
    public string Phone { get; set; } = string.Empty;

    public string Purpose { get; set; } = "Register";
}
