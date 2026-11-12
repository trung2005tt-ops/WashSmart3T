namespace WashSmart.API.Models;

public class StoreConfig
{
    public int Id { get; set; }

    public string StoreName { get; set; } = "Cửa hàng WashSmart 3T - Trụ sở chính";
    public string Address { get; set; } = "140 Lê Trọng Tấn, phường Tây Thạnh, TP. Hồ Chí Minh";
    public double Latitude { get; set; } = 10.8070;
    public double Longitude { get; set; } = 106.6287;
    public string Hotline { get; set; } = "0900000000";
    public string OpenHours { get; set; } = "07:00 - 22:00";

    public decimal BaseShippingFee { get; set; } = 20000;
    public decimal Tier2ShippingFee { get; set; } = 30000;
    public decimal Tier3ShippingFee { get; set; } = 45000;

    public double Tier1MaxKm { get; set; } = 2.0;
    public double Tier2MaxKm { get; set; } = 5.0;
    public double Tier3MaxKm { get; set; } = 10.0;

    public decimal ExpressExtraFee { get; set; } = 25000;
    public decimal AddonComfortFee { get; set; } = 10000;
    public decimal AddonBagFee { get; set; } = 5000;
    public decimal FreeShipMinAmount { get; set; } = 250000;

    public string BankName { get; set; } = "MBBank (Ngân hàng Quân Đội)";
    public string BankBin { get; set; } = "970422";
    public string BankAccountNo { get; set; } = "0818606505";
    public string BankAccountHolder { get; set; } = "TRAN DIEP MINH TRUNG";

    public string SmsApiKey { get; set; } = "DEV_DEMO_KEY";
    public string SmsApiSecret { get; set; } = "DEV_DEMO_SECRET";
    public string SmsBrandName { get; set; } = "WASHSMART3T";
    public string SmsOtpTemplate { get; set; } = "Ma OTP xac thuc WashSmart 3T cua ban la {OTP}. Hieu luc trong 5 phut.";

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
