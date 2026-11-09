using System.Collections.Concurrent;

namespace WashSmart.API.Services;

public class LockoutInfo
{
    public int FailedAttempts { get; set; } = 0;
    public DateTime? LockoutUntil { get; set; } = null;
    public DateTime LastAttemptAt { get; set; } = DateTime.UtcNow;

    public bool IsLocked => LockoutUntil.HasValue && DateTime.UtcNow < LockoutUntil.Value;
    public int RemainingMinutes => LockoutUntil.HasValue && LockoutUntil.Value > DateTime.UtcNow
        ? (int)Math.Ceiling((LockoutUntil.Value - DateTime.UtcNow).TotalMinutes)
        : 0;
}

public static class AccountLockoutManager
{
    private static readonly ConcurrentDictionary<string, LockoutInfo> _lockouts = new();
    private const int MaxFailedAttempts = 5;
    private static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);

    private static string Normalize(string phone)
    {
        return new string(phone.Where(char.IsDigit).ToArray());
    }

    /// <summary>
    /// Kiểm tra tài khoản có đang trong thời gian bị khóa do đăng nhập sai hay không
    /// </summary>
    public static (bool isLocked, int remainingMinutes) CheckLockout(string phone)
    {
        var key = Normalize(phone);
        if (_lockouts.TryGetValue(key, out var info))
        {
            if (info.IsLocked)
            {
                return (true, info.RemainingMinutes);
            }
            // Hết hạn khóa thì reset trạng thái
            if (info.LockoutUntil.HasValue && DateTime.UtcNow >= info.LockoutUntil.Value)
            {
                _lockouts.TryRemove(key, out _);
            }
        }
        return (false, 0);
    }

    /// <summary>
    /// Ghi nhận 1 lần đăng nhập thất bại
    /// </summary>
    public static (bool isLockedNow, int remainingAttempts, int remainingMinutes) RecordFailedAttempt(string phone)
    {
        var key = Normalize(phone);
        var info = _lockouts.GetOrAdd(key, _ => new LockoutInfo());

        info.FailedAttempts++;
        info.LastAttemptAt = DateTime.UtcNow;

        if (info.FailedAttempts >= MaxFailedAttempts)
        {
            info.LockoutUntil = DateTime.UtcNow.Add(LockoutDuration);
            return (true, 0, (int)LockoutDuration.TotalMinutes);
        }

        return (false, MaxFailedAttempts - info.FailedAttempts, 0);
    }

    /// <summary>
    /// Reset bộ đếm khi đăng nhập thành công
    /// </summary>
    public static void RecordSuccessfulLogin(string phone)
    {
        var key = Normalize(phone);
        _lockouts.TryRemove(key, out _);
    }
}
