using System.Collections.Concurrent;
using System.Security.Cryptography;

namespace WashSmart.API.Services;

public class OtpEntry
{
    public string Code { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddMinutes(5);
    public int AttemptCount { get; set; } = 0;
    public string Phone { get; set; } = string.Empty;
    public string Purpose { get; set; } = string.Empty;

    public bool IsExpired => DateTime.UtcNow > ExpiresAt;
}

public static class OtpManager
{
    private static readonly ConcurrentDictionary<string, OtpEntry> _otpStore = new();

    private static string BuildKey(string purpose, string phone)
    {
        var (_, _, cleanLocal) = SmsService.NormalizePhone(phone);
        return $"{purpose.Trim().ToLower()}:{cleanLocal}";
    }

    /// <summary>
    /// Sinh mã OTP 6 số bảo mật và lưu vào bộ nhớ cache (thời hạn 5 phút)
    /// </summary>
    public static string GenerateOtp(string purpose, string phone)
    {
        var key = BuildKey(purpose, phone);

        // Sinh 6 số ngẫu nhiên bằng RandomNumberGenerator
        var randomInt = RandomNumberGenerator.GetInt32(100000, 1000000);
        var code = randomInt.ToString("D6");

        var entry = new OtpEntry
        {
            Code = code,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddMinutes(5),
            AttemptCount = 0,
            Phone = phone,
            Purpose = purpose
        };

        _otpStore.AddOrUpdate(key, entry, (_, _) => entry);
        return code;
    }

    /// <summary>
    /// Xác thực mã OTP người dùng nhập
    /// </summary>
    public static (bool isValid, string message) VerifyOtp(string purpose, string phone, string inputCode)
    {
        if (string.IsNullOrWhiteSpace(inputCode))
        {
            return (false, "Vui lòng nhập mã OTP.");
        }

        var key = BuildKey(purpose, phone);

        if (!_otpStore.TryGetValue(key, out var entry))
        {
            return (false, "Không tìm thấy mã OTP hoặc mã đã hết hạn. Vui lòng yêu cầu gửi lại mã mới.");
        }

        if (entry.IsExpired)
        {
            _otpStore.TryRemove(key, out _);
            return (false, "Mã OTP đã hết hiệu lực (quá 5 phút). Vui lòng yêu cầu mã mới.");
        }

        entry.AttemptCount++;
        if (entry.AttemptCount > 5)
        {
            _otpStore.TryRemove(key, out _);
            return (false, "Bạn đã nhập sai mã OTP quá 5 lần. Vui lòng yêu cầu gửi mã mới để bảo mật.");
        }

        var cleanInput = inputCode.Trim();
        if (entry.Code != cleanInput)
        {
            return (false, $"Mã OTP không chính xác. Bạn còn {5 - entry.AttemptCount} lần thử.");
        }

        // Hợp lệ -> Xóa mã để không tái sử dụng (Replay Attack)
        _otpStore.TryRemove(key, out _);
        return (true, "Xác thực mã OTP thành công.");
    }

    /// <summary>
    /// Lấy mã OTP đang kích hoạt (phục vụ hiển thị gợi ý hỗ trợ test)
    /// </summary>
    public static string? GetActiveOtp(string purpose, string phone)
    {
        var key = BuildKey(purpose, phone);
        if (_otpStore.TryGetValue(key, out var entry) && !entry.IsExpired)
        {
            return entry.Code;
        }
        return null;
    }
}
