using System.Text;

namespace WashSmart.API.Services;

public class VietQrResult
{
    public string EmvCoString { get; set; } = string.Empty;
    public string QrImageUrl { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string OrderCode { get; set; } = string.Empty;
    public string BankBin { get; set; } = string.Empty;
    public string BankAccountNo { get; set; } = string.Empty;
    public string BankAccountHolder { get; set; } = string.Empty;
}

public static class VietQrService
{
    private static string FormatTlv(string tag, string value)
    {
        if (string.IsNullOrEmpty(value)) return string.Empty;
        var bytes = Encoding.UTF8.GetBytes(value);
        return $"{tag}{bytes.Length:D2}{value}";
    }

    /// <summary>
    /// Tính mã CRC-16 CCITT (Chuẩn EMVCo với seed 0xFFFF và đa thức 0x1021)
    /// </summary>
    public static string CalculateCrc16(string data)
    {
        var bytes = Encoding.UTF8.GetBytes(data);
        ushort crc = 0xFFFF;
        const ushort polynomial = 0x1021;

        foreach (var b in bytes)
        {
            crc ^= (ushort)(b << 8);
            for (var i = 0; i < 8; i++)
            {
                if ((crc & 0x8000) != 0)
                {
                    crc = (ushort)((crc << 1) ^ polynomial);
                }
                else
                {
                    crc <<= 1;
                }
            }
        }

        return crc.ToString("X4");
    }

    /// <summary>
    /// Sinh chuỗi VietQR chuẩn EMVCo khóa cứng số tiền và mã đơn hàng #WS3T-XXXX
    /// </summary>
    public static VietQrResult GenerateVietQr(
        string bankBin,
        string accountNo,
        string accountHolder,
        decimal amount,
        string orderCode)
    {
        var cleanBin = string.IsNullOrWhiteSpace(bankBin) ? "970422" : bankBin.Trim();
        var cleanAccount = string.IsNullOrWhiteSpace(accountNo) ? "0908123456" : accountNo.Trim();
        var cleanHolder = string.IsNullOrWhiteSpace(accountHolder) ? "WASH SMART 3T" : accountHolder.Trim().ToUpperInvariant();
        var cleanOrderCode = string.IsNullOrWhiteSpace(orderCode) ? "WS3T" : orderCode.Trim();

        // 1. Tag 38: Thông tin người thụ hưởng NAPAS
        var subTag00 = FormatTlv("00", cleanBin);
        var subTag01 = FormatTlv("01", cleanAccount);
        var subNapasOrg = FormatTlv("00", "A000000727") + FormatTlv("01", subTag00 + subTag01);
        var tag38 = FormatTlv("38", subNapasOrg + FormatTlv("02", "QRIBFTTA"));

        // 2. Các tag tiêu chuẩn EMVCo
        var tag00 = FormatTlv("00", "01"); // Payload Format Indicator
        var tag01 = FormatTlv("01", "12"); // 12: Dynamic QR (có số tiền cố định)
        var tag53 = FormatTlv("53", "704"); // Đồng Việt Nam (VND)
        var intAmount = ((long)Math.Round(amount)).ToString();
        var tag54 = FormatTlv("54", intAmount); // Số tiền thanh toán
        var tag58 = FormatTlv("58", "VN"); // Quốc gia
        var tag59 = FormatTlv("59", cleanHolder); // Tên người thụ hưởng
        var tag60 = FormatTlv("60", "HO CHI MINH"); // Thành phố

        // 3. Tag 62: Mã đơn hàng khóa nội dung thanh toán #WS3T-XXXX
        var tag62Sub08 = FormatTlv("08", cleanOrderCode);
        var tag62 = FormatTlv("62", tag62Sub08);

        // 4. Ghép toàn bộ chuỗi trước khi tính CRC (bắt đầu bằng 6304)
        var rawPayload = $"{tag00}{tag01}{tag38}{tag53}{tag54}{tag58}{tag59}{tag60}{tag62}6304";
        var crc = CalculateCrc16(rawPayload);
        var emvCoString = rawPayload + crc;

        // 5. Ảnh QR VietQR động khóa nội dung
        var encodedOrderCode = Uri.EscapeDataString(cleanOrderCode);
        var encodedHolder = Uri.EscapeDataString(cleanHolder);
        var qrImageUrl = $"https://img.vietqr.io/image/{cleanBin}-{cleanAccount}-compact2.png?amount={intAmount}&addInfo={encodedOrderCode}&accountName={encodedHolder}";

        return new VietQrResult
        {
            EmvCoString = emvCoString,
            QrImageUrl = qrImageUrl,
            Amount = amount,
            OrderCode = cleanOrderCode,
            BankBin = cleanBin,
            BankAccountNo = cleanAccount,
            BankAccountHolder = cleanHolder
        };
    }
}
