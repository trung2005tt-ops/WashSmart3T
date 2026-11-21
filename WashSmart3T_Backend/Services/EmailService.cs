using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;

namespace WashSmart.API.Services;

public static class EmailService
{
    /// <summary>
    /// Gửi mã xác thực OTP qua Gmail SMTP bằng Email HTML Template thương hiệu WashSmart 3T
    /// </summary>
    public static async Task<(bool success, string message, bool isSimulated)> SendOtpEmailAsync(
        string toEmail,
        string otpCode,
        string purpose,
        IConfiguration config,
        string? recipientName = null)
    {
        var cleanEmail = (toEmail ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(cleanEmail))
        {
            return (false, "Địa chỉ email không được để trống.", true);
        }

        var host = config["Smtp:Host"] ?? "smtp.gmail.com";
        var portStr = config["Smtp:Port"] ?? "587";
        int.TryParse(portStr, out var port);
        if (port <= 0) port = 587;

        var senderEmail = config["Smtp:SenderEmail"] ?? "washsmart3t.system@gmail.com";
        var senderName = config["Smtp:SenderName"] ?? "WashSmart 3T - Hệ Thống Giặt Sấy Thông Minh";
        var appPassword = (config["Smtp:AppPassword"] ?? string.Empty).Trim().Replace(" ", "");
        var enableSsl = bool.Parse(config["Smtp:EnableSsl"] ?? "true");

        var purposeTitle = purpose == "Register" ? "Đăng ký tài khoản mới" : "Đặt lại mật khẩu";
        var subject = $"[WashSmart 3T] Mã xác thực OTP {purposeTitle}";

        var htmlBody = GenerateOtpEmailTemplate(cleanEmail, otpCode, purposeTitle, recipientName);

        // Kiểm tra nếu có AppPassword hợp lệ thì gửi thật qua Gmail SMTP
        bool hasValidConfig = !string.IsNullOrWhiteSpace(appPassword) &&
                              !appPassword.Contains("YOUR_") &&
                              appPassword.Length >= 12;

        if (hasValidConfig)
        {
            try
            {
                using var client = new SmtpClient(host, port)
                {
                    Credentials = new NetworkCredential(senderEmail, appPassword),
                    EnableSsl = enableSsl,
                    Timeout = 10000
                };

                using var mailMessage = new MailMessage
                {
                    From = new MailAddress(senderEmail, senderName),
                    Subject = subject,
                    Body = htmlBody,
                    IsBodyHtml = true
                };
                mailMessage.To.Add(cleanEmail);

                await client.SendMailAsync(mailMessage);

                Console.WriteLine($"[EmailService] Đã gửi OTP THẬT qua Gmail SMTP thành công tới: {cleanEmail}");
                return (true, $"Mã OTP xác thực đã được gửi tới email {cleanEmail}. Vui lòng kiểm tra hộp thư đến (Inbox) hoặc thư mục Thư rác (Spam).", false);
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"[EmailService] Gửi qua Gmail SMTP thất bại ({ex.Message}). Tự động kích hoạt Fallback Console/Demo.");
                Console.ResetColor();
            }
        }

        // Chế độ Mô phỏng / Demo (khi chưa điền App Password hoặc test offline)
        Console.WriteLine("=================================================================");
        Console.WriteLine($"[GMAIL OTP SIMULATION] Gửi tới: {cleanEmail}");
        Console.WriteLine($"Tiêu đề: {subject}");
        Console.WriteLine($"MÃ XÁC THỰC OTP CỦA BẠN LÀ: {otpCode} (Hiệu lực: 5 phút)");
        Console.WriteLine("=================================================================");

        return (true, $"Mã OTP đã được cấp phát cho email {cleanEmail}.", true);
    }

    /// <summary>
    /// Tạo mẫu HTML Email chuyên nghiệp, chuẩn responsive, hiển thị đẹp trên cả điện thoại và máy tính
    /// </summary>
    private static string GenerateOtpEmailTemplate(string toEmail, string otpCode, string purposeTitle, string? recipientName)
    {
        var displayName = string.IsNullOrWhiteSpace(recipientName) ? "Quý khách" : recipientName;

        const string template = @"
<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>Mã Xác Thực OTP - WashSmart 3T</title>
</head>
<body style=""margin: 0; padding: 0; background-color: #F8F9FA; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #2D3748;"">
    <table border=""0"" cellpadding=""0"" cellspacing=""0"" width=""100%"" style=""max-width: 600px; margin: 30px auto; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08);"">
        <tr>
            <td style=""background: linear-gradient(135deg, #8E0028 0%, #BA1A1A 100%); padding: 32px 24px; text-align: center;"">
                <div style=""display: inline-block; background-color: rgba(255, 255, 255, 0.2); width: 56px; height: 56px; line-height: 56px; border-radius: 50%; font-size: 26px; color: #FFFFFF; font-weight: bold; margin-bottom: 12px;"">
                    3T
                </div>
                <h1 style=""margin: 0; color: #FFFFFF; font-size: 22px; font-weight: 800; letter-spacing: 0.5px;"">WashSmart 3T</h1>
                <p style=""margin: 6px 0 0; color: rgba(255,255,255,0.9); font-size: 13px;"">Hệ Thống Giặt Sấy Tự Động & Giao Nhận Thông Minh</p>
            </td>
        </tr>
        <tr>
            <td style=""padding: 36px 32px;"">
                <p style=""margin: 0 0 16px; font-size: 16px; font-weight: 600; color: #1A202C;"">
                    Xin chào {{DISPLAY_NAME}},
                </p>
                <p style=""margin: 0 0 20px; font-size: 14px; line-height: 1.6; color: #4A5568;"">
                    Bạn vừa gửi yêu cầu lấy mã xác thực OTP để <strong>{{PURPOSE_TITLE}}</strong> trên ứng dụng <strong>WashSmart 3T</strong>.
                </p>
                <div style=""margin: 28px 0; background-color: #FFF0F2; border: 2px dashed #FFD9DC; border-radius: 12px; padding: 24px; text-align: center;"">
                    <span style=""display: block; font-size: 12px; text-transform: uppercase; color: #8E0028; font-weight: 700; letter-spacing: 1px; margin-bottom: 8px;"">
                        MÃ XÁC THỰC CỦA BẠN LÀ
                    </span>
                    <div style=""font-size: 38px; font-weight: 800; letter-spacing: 10px; color: #8E0028; font-family: 'Courier New', Courier, monospace;"">
                        {{OTP_CODE}}
                    </div>
                    <span style=""display: block; font-size: 12px; color: #718096; margin-top: 10px;"">
                        Mã này có hiệu lực trong vòng <strong>5 phút</strong>
                    </span>
                </div>
                <p style=""margin: 0 0 12px; font-size: 13px; line-height: 1.6; color: #718096;"">
                    Tuyệt đối không chia sẻ mã xác thực này cho bất kỳ ai, kể cả nhân viên của tiệm giặt.
                </p>
                <p style=""margin: 0; font-size: 13px; line-height: 1.6; color: #718096;"">
                    Nếu bạn không thực hiện yêu cầu này, vui lòng bỏ qua email hoặc liên hệ hotline cửa hàng để được hỗ trợ.
                </p>
            </td>
        </tr>
        <tr>
            <td style=""background-color: #F7FAFC; padding: 24px 32px; border-top: 1px solid #EDF2F7; text-align: center; font-size: 12px; color: #A0AEC0;"">
                <p style=""margin: 0 0 6px; font-weight: 600; color: #4A5568;"">Cửa hàng Giặt Sấy WashSmart 3T</p>
                <p style=""margin: 0 0 6px;"">140 Lê Trọng Tấn, P. Tây Thạnh, Q. Tân Phú, TP. Hồ Chí Minh</p>
                <p style=""margin: 0;"">Hotline: 0900.000.000 | Website: washsmart3t.com</p>
            </td>
        </tr>
    </table>
</body>
</html>";

        return template
            .Replace("{{DISPLAY_NAME}}", WebUtility.HtmlEncode(displayName))
            .Replace("{{PURPOSE_TITLE}}", WebUtility.HtmlEncode(purposeTitle))
            .Replace("{{OTP_CODE}}", otpCode);
    }
}
