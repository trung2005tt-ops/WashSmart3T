using System.ComponentModel.DataAnnotations;
using WashSmart.API.Models;

namespace WashSmart.API.DTOs;

public class CreatePaymentRequest
{
    [Required]
    public string Method { get; set; } = string.Empty;

    public string? Note { get; set; }
}

public class ConfirmPaymentRequest
{
    public string? Note { get; set; }
}

public class UpdatePaymentStatusRequest
{
    [Required]
    public string Status { get; set; } = string.Empty;

    public string? Note { get; set; }
}
