using System.ComponentModel.DataAnnotations;

namespace WashSmart.API.DTOs;

public class LoginRequest
{
    [Required(ErrorMessage = "Số điện thoại không được để trống.")]
    [RegularExpression(@"^0(3|5|7|8|9)[0-9]{8}$", ErrorMessage = "Số điện thoại không đúng định dạng di động Việt Nam.")]
    public string Phone { get; set; } = string.Empty;

    [Required(ErrorMessage = "Mật khẩu không được để trống.")]
    public string Password { get; set; } = string.Empty;
}
