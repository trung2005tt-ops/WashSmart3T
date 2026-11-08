using WashSmart.API.Services;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace WashSmart.API.Controllers;

public class StoreConfigModel
{
    public string StoreName { get; set; } = "Cửa hàng WashSmart 3T - Trụ sở chính";
    public string Address { get; set; } = "140 Lê Trọng Tấn, phường Tây Thạnh, TP. Hồ Chí Minh";
    public double Latitude { get; set; } = 10.8070;
    public double Longitude { get; set; } = 106.6287;
    public string Hotline { get; set; } = "0900000000";
    public string OpenHours { get; set; } = "07:00 - 22:00";
    public int BaseShippingFee { get; set; } = 20000;
    public int Tier2ShippingFee { get; set; } = 30000;
    public int Tier3ShippingFee { get; set; } = 45000;
    public int ExpressExtraFee { get; set; } = 15000;
    public double Tier1MaxKm { get; set; } = 3.0;
    public double Tier2MaxKm { get; set; } = 6.0;

    // ==========================================
    // TÀI KHOẢN NGÂN HÀNG THẬT (VIETQR NAPAS 247)
    // ==========================================
    public string BankName { get; set; } = "MBBank (Ngân hàng Quân Đội)";
    public string BankBin { get; set; } = "970422"; // MBBank NAPAS BIN
    public string BankAccountNo { get; set; } = "0908123456"; // STK thật
    public string BankAccountHolder { get; set; } = "NGUYEN THI KIEU NHU"; // Tên chủ tài khoản in hoa

    // ==========================================
    // CỔNG GỬI TIN NHẮN SMS XÁC THỰC SĐT THẬT
    // ==========================================
    public string SmsProvider { get; set; } = "Simulated"; // SpeedSMS / Twilio / eSMS / Simulated
    public string SmsApiKey { get; set; } = "";
    public string SmsApiSecret { get; set; } = "";
    public string SmsSenderId { get; set; } = "WashSmart3T";

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

[ApiController]
[Route("api/[controller]")]
public class StoreConfigController : ControllerBase
{
    private static readonly object _fileLock = new();
    private readonly IWebHostEnvironment _env;

    public StoreConfigController(IWebHostEnvironment env)
    {
        _env = env;
    }

    private string GetConfigFilePath()
    {
        return Path.Combine(_env.ContentRootPath, "store_config.json");
    }

    [NonAction]
    public StoreConfigModel LoadConfig()
    {
        lock (_fileLock)
        {
            var path = GetConfigFilePath();
            if (System.IO.File.Exists(path))
            {
                try
                {
                    var json = System.IO.File.ReadAllText(path);
                    var cfg = JsonSerializer.Deserialize<StoreConfigModel>(json, new JsonSerializerOptions
                    {
                        PropertyNameCaseInsensitive = true
                    });
                    if (cfg != null) return cfg;
                }
                catch { }
            }

            var defaultCfg = new StoreConfigModel();
            SaveConfig(defaultCfg);
            return defaultCfg;
        }
    }

    private void SaveConfig(StoreConfigModel cfg)
    {
        lock (_fileLock)
        {
            var path = GetConfigFilePath();
            var json = JsonSerializer.Serialize(cfg, new JsonSerializerOptions { WriteIndented = true });
            System.IO.File.WriteAllText(path, json);
        }
    }

    // ==========================================
    // GET: api/StoreConfig
    // Mọi client (App khách, App shipper, Web) đều đọc được cấu hình
    // ==========================================
    [HttpGet]
    [AllowAnonymous]
    public IActionResult GetStoreConfig()
    {
        var config = LoadConfig();
        return Ok(config);
    }

    // ==========================================
    // PUT: api/StoreConfig
    // Admin/Staff cập nhật địa chỉ, tài khoản ngân hàng và SMS gateway từ Web
    // ==========================================
    [HttpPut]
    [AllowAnonymous]
    public IActionResult UpdateStoreConfig([FromBody] StoreConfigModel model)
    {
        if (model == null)
        {
            return BadRequest(new { message = "Dữ liệu cấu hình không hợp lệ." });
        }

        if (string.IsNullOrWhiteSpace(model.Address))
        {
            return BadRequest(new { message = "Địa chỉ cửa hàng không được để trống." });
        }

        if (model.Latitude == 0 && model.Longitude == 0)
        {
            model.Latitude = 10.7380;
            model.Longitude = 106.7130;
        }

        // Tự động khớp tọa độ theo địa chỉ nếu tọa độ chưa được cập nhật từ giao diện web
        var addrLower = model.Address.ToLowerInvariant();
        if ((addrLower.Contains("lê trọng tấn") || addrLower.Contains("tây thạnh") || addrLower.Contains("tân phú")) && Math.Abs(model.Latitude - 10.7380) < 0.001)
        {
            model.Latitude = 10.8070;
            model.Longitude = 106.6287;
        }
        else if ((addrLower.Contains("bến thành") || addrLower.Contains("lê lợi") || addrLower.Contains("quận 1")) && Math.Abs(model.Latitude - 10.7380) < 0.001)
        {
            model.Latitude = 10.7725;
            model.Longitude = 106.6980;
        }
        else if ((addrLower.Contains("vinhomes") || addrLower.Contains("bình thạnh")) && Math.Abs(model.Latitude - 10.7380) < 0.001)
        {
            model.Latitude = 10.7930;
            model.Longitude = 106.7215;
        }
        else if ((addrLower.Contains("thủ đức") || addrLower.Contains("võ văn ngân")) && Math.Abs(model.Latitude - 10.7380) < 0.001)
        {
            model.Latitude = 10.8512;
            model.Longitude = 106.7720;
        }

        if (model.BaseShippingFee <= 0) model.BaseShippingFee = 20000;
        if (model.Tier2ShippingFee <= 0) model.Tier2ShippingFee = 30000;
        if (model.Tier3ShippingFee <= 0) model.Tier3ShippingFee = 45000;
        if (model.ExpressExtraFee < 0) model.ExpressExtraFee = 15000;

        // Chuẩn hóa thông tin ngân hàng
        if (string.IsNullOrWhiteSpace(model.BankBin)) model.BankBin = "970422";
        if (string.IsNullOrWhiteSpace(model.BankAccountNo)) model.BankAccountNo = "0908123456";
        if (string.IsNullOrWhiteSpace(model.BankAccountHolder)) model.BankAccountHolder = "NGUYEN THI KIEU NHU";
        model.BankAccountHolder = model.BankAccountHolder.Trim().ToUpperInvariant();

        model.UpdatedAt = DateTime.UtcNow;
        SaveConfig(model);

        return Ok(new
        {
            message = "Cập nhật cấu hình cửa hàng, tài khoản ngân hàng và SMS thành công!",
            config = model
        });
    }

    // ==========================================
    // POST: api/StoreConfig/test-sms
    // Gửi thử tin nhắn SMS đến SĐT thật
    // ==========================================
    [HttpPost("test-sms")]
    [AllowAnonymous]
    public async Task<IActionResult> TestSms([FromBody] TestSmsRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Phone))
        {
            return BadRequest(new { message = "Vui lòng nhập số điện thoại cần gửi thử." });
        }

        var config = LoadConfig();
        var otpCode = OtpManager.GenerateOtp("Test", req.Phone);
        var result = await SmsService.SendOtpSmsAsync(req.Phone, otpCode, "Test", config);

        return Ok(new
        {
            success = result.Success,
            message = result.Message,
            provider = result.Provider,
            phone = result.NormalizedPhone,
            otp = otpCode,
            content = result.Content,
            isSimulated = result.IsSimulated
        });
    }

    // ==========================================
    // POST: api/StoreConfig/reset
    // Khôi phục về địa chỉ trụ sở mặc định
    // ==========================================
    [HttpPost("reset")]
    [AllowAnonymous]
    public IActionResult ResetDefault()
    {
        var defaultCfg = new StoreConfigModel();
        SaveConfig(defaultCfg);
        return Ok(new
        {
            message = "Đã khôi phục cấu hình cửa hàng mặc định thành công!",
            config = defaultCfg
        });
    }
}

public class TestSmsRequest
{
    public string Phone { get; set; } = string.Empty;
}
