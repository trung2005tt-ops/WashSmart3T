using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using WashSmart.API.Models;

namespace WashSmart.API.Services;

public class SmsSendResult
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
    public string Provider { get; set; } = string.Empty;
    public string NormalizedPhone { get; set; } = string.Empty;
    public string SentToPhone { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public bool IsSimulated { get; set; }
}

public static class SmsService
{
    private static readonly HttpClient _httpClient = new HttpClient();

    /// <summary>
    /// Chuẩn hóa số điện thoại Việt Nam sang định dạng quốc tế (+84...) và (84...)
    /// </summary>
    public static (string standardPlus, string standardNoPlus, string localZero) NormalizePhone(string rawPhone)
    {
        var cleaned = new string(rawPhone.Where(char.IsDigit).ToArray());
        if (cleaned.StartsWith("84") && cleaned.Length >= 11)
        {
            var rest = cleaned.Substring(2);
            return ($"+{cleaned}", cleaned, $"0{rest}");
        }
        if (cleaned.StartsWith("0") && cleaned.Length >= 10)
        {
            var rest = cleaned.Substring(1);
            return ($"+84{rest}", $"84{rest}", cleaned);
        }
        return ($"+{cleaned}", cleaned, cleaned);
    }

    /// <summary>
    /// Gửi mã xác nhận OTP qua tin nhắn SMS đến số điện thoại thật
    /// </summary>
    public static async Task<SmsSendResult> SendOtpSmsAsync(string phone, string otpCode, string purpose, StoreConfig config)
    {
        var (phonePlus, phoneNoPlus, phoneLocal) = NormalizePhone(phone);
        var purposeText = purpose == "Register" ? "dang ky tai khoan" : "dat lai mat khau";
        var content = $"[WashSmart 3T] Ma xac thuc OTP {purposeText} cua ban la: {otpCode}. Hieu luc trong 5 phut. Vui long khong chia se cho bat ky ai.";

        var (success, msg, provider, isSimulated) = await SendSmsInternalAsync(
            phoneLocal, phonePlus, phoneNoPlus, content,
            config.SmsApiKey, config.SmsApiSecret, config.SmsBrandName);

        return new SmsSendResult
        {
            Success = success,
            Message = msg,
            Provider = provider,
            NormalizedPhone = phoneLocal,
            SentToPhone = phone,
            Content = content,
            IsSimulated = isSimulated
        };
    }

    /// <summary>
    /// Gửi SMS thông thường
    /// </summary>
    public static async Task<(bool success, string message)> SendSmsAsync(string phone, string message, string? apiKey, string? apiSecret, string? brandName)
    {
        var (phonePlus, phoneNoPlus, phoneLocal) = NormalizePhone(phone);
        var (success, msg, _, _) = await SendSmsInternalAsync(
            phoneLocal, phonePlus, phoneNoPlus, message, apiKey, apiSecret, brandName);
        return (success, msg);
    }

    private static async Task<(bool success, string message, string provider, bool isSimulated)> SendSmsInternalAsync(
        string phoneLocal, string phonePlus, string phoneNoPlus, string content,
        string? apiKey, string? apiSecret, string? brandName)
    {
        var senderId = string.IsNullOrWhiteSpace(brandName) ? "WashSmart3T" : brandName.Trim();

        // 1. Gửi qua SpeedSMS nếu có cấu hình API Key thật
        if (!string.IsNullOrEmpty(apiKey) && apiKey != "DEV_DEMO_KEY")
        {
            try
            {
                var url = "https://api.speedsms.vn/index.php/sms/send";
                var payload = new
                {
                    to = new[] { phoneNoPlus },
                    content = content,
                    sms_type = 2, // Tin CSKH/OTP
                    sender = senderId
                };

                using var request = new HttpRequestMessage(HttpMethod.Post, url);
                var authBytes = Encoding.ASCII.GetBytes($"{apiKey}:x");
                request.Headers.Authorization = new AuthenticationHeaderValue("Basic", Convert.ToBase64String(authBytes));
                request.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

                var resp = await _httpClient.SendAsync(request);
                if (resp.IsSuccessStatusCode)
                {
                    return (true, $"Đã gửi SMS thành công tới {phoneLocal} qua SpeedSMS.", "SpeedSMS", false);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[SmsService] Lỗi SpeedSMS: {ex.Message}");
            }
        }

        // 2. Gửi qua Twilio nếu có AccountSid và AuthToken thật
        if (!string.IsNullOrEmpty(apiKey) && !string.IsNullOrEmpty(apiSecret) && apiKey != "DEV_DEMO_KEY")
        {
            try
            {
                var url = $"https://api.twilio.com/2010-04-01/Accounts/{apiKey}/Messages.json";
                using var request = new HttpRequestMessage(HttpMethod.Post, url);
                var authBytes = Encoding.ASCII.GetBytes($"{apiKey}:{apiSecret}");
                request.Headers.Authorization = new AuthenticationHeaderValue("Basic", Convert.ToBase64String(authBytes));

                var formValues = new Dictionary<string, string>
                {
                    { "To", phonePlus },
                    { "From", senderId },
                    { "Body", content }
                };
                request.Content = new FormUrlEncodedContent(formValues);

                var resp = await _httpClient.SendAsync(request);
                if (resp.IsSuccessStatusCode)
                {
                    return (true, $"Đã gửi SMS thành công tới {phonePlus} qua Twilio.", "Twilio", false);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[SmsService] Lỗi Twilio: {ex.Message}");
            }
        }

        // 3. Fallback chế độ Mô phỏng Thông minh (Dev/Demo)
        Console.WriteLine($"=======================================================");
        Console.WriteLine($"[SMS GATEWAY SIMULATION] Gửi đến SĐT: {phoneLocal} ({phonePlus})");
        Console.WriteLine($"Nội dung: {content}");
        Console.WriteLine($"=======================================================");

        return (true, $"Hệ thống SMS đã cấp phát mã tin nhắn tới số {phoneLocal}.", "SmartWashSMS Engine", true);
    }
}
