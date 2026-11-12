using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.Models;
using WashSmart.API.Services;
using System.Collections.Concurrent;

namespace WashSmart.API.Controllers;

public class StorePublicConfigDto
{
    public string StoreName { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public string Hotline { get; set; } = string.Empty;
    public string OpenHours { get; set; } = string.Empty;

    public decimal BaseShippingFee { get; set; }
    public decimal Tier2ShippingFee { get; set; }
    public decimal Tier3ShippingFee { get; set; }
    public double Tier1MaxKm { get; set; }
    public double Tier2MaxKm { get; set; }
    public double Tier3MaxKm { get; set; }

    public decimal ExpressExtraFee { get; set; }
    public decimal AddonComfortFee { get; set; }
    public decimal AddonBagFee { get; set; }
    public decimal FreeShipMinAmount { get; set; }

    public string BankName { get; set; } = string.Empty;
    public string BankBin { get; set; } = string.Empty;
    public string BankAccountNo { get; set; } = string.Empty;
    public string BankAccountHolder { get; set; } = string.Empty;
    public DateTime UpdatedAt { get; set; }
}

public class TestSmsRequest
{
    public string Phone { get; set; } = string.Empty;
    public string? Message { get; set; }
}

[ApiController]
[Route("api/[controller]")]
public class StoreConfigController : ControllerBase
{
    private static readonly ConcurrentDictionary<string, DateTime> _smsRateLimits = new();
    private readonly ApplicationDbContext _context;

    public StoreConfigController(ApplicationDbContext context)
    {
        _context = context;
    }

    [NonAction]
    public async Task<StoreConfig> GetOrCreateConfigAsync()
    {
        var cfg = await _context.StoreConfigs.FirstOrDefaultAsync();
        if (cfg == null)
        {
            cfg = new StoreConfig();
            _context.StoreConfigs.Add(cfg);
            await _context.SaveChangesAsync();
        }
        return cfg;
    }

    // ============================================================
    // GET: api/StoreConfig
    // Dành cho Khách hàng & Mobile & Web POS
    // LƯU Ý BẢO MẬT: TUYỆT ĐỐI KHÔNG TRẢ VỀ SmsApiKey & SmsApiSecret
    // ============================================================
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetPublicConfig()
    {
        var config = await GetOrCreateConfigAsync();

        var publicConfig = new StorePublicConfigDto
        {
            StoreName = config.StoreName,
            Address = config.Address,
            Latitude = config.Latitude,
            Longitude = config.Longitude,
            Hotline = config.Hotline,
            OpenHours = config.OpenHours,
            BaseShippingFee = config.BaseShippingFee,
            Tier2ShippingFee = config.Tier2ShippingFee,
            Tier3ShippingFee = config.Tier3ShippingFee,
            Tier1MaxKm = config.Tier1MaxKm,
            Tier2MaxKm = config.Tier2MaxKm,
            Tier3MaxKm = config.Tier3MaxKm,
            ExpressExtraFee = config.ExpressExtraFee,
            AddonComfortFee = config.AddonComfortFee,
            AddonBagFee = config.AddonBagFee,
            FreeShipMinAmount = config.FreeShipMinAmount,
            BankName = config.BankName,
            BankBin = config.BankBin,
            BankAccountNo = config.BankAccountNo,
            BankAccountHolder = config.BankAccountHolder,
            UpdatedAt = config.UpdatedAt
        };

        return Ok(publicConfig);
    }

    // ============================================================
    // GET: api/StoreConfig/admin
    // Chỉ Quản trị viên (Admin) mới có quyền đọc cấu hình đầy đủ (bao gồm cấu hình SMS Gateway).
    // ============================================================
    [HttpGet("admin")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAdminConfig()
    {
        var config = await GetOrCreateConfigAsync();
        return Ok(config);
    }

    // ============================================================
    // PUT: api/StoreConfig
    // Chỉ Quản trị viên (Admin) mới có quyền đổi địa chỉ và tài khoản nhận tiền VietQR.
    // Dữ liệu được lưu trực tiếp vào CSDL SQL Server, an toàn đa tiến trình/container.
    // ============================================================
    [HttpPut]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateStoreConfig([FromBody] StoreConfig model)
    {
        if (model == null)
        {
            return BadRequest(new { message = "Dữ liệu cấu hình không hợp lệ." });
        }

        if (string.IsNullOrWhiteSpace(model.Address))
        {
            return BadRequest(new { message = "Địa chỉ cửa hàng không được để trống." });
        }

        var config = await GetOrCreateConfigAsync();

        config.StoreName = !string.IsNullOrWhiteSpace(model.StoreName) ? model.StoreName.Trim() : config.StoreName;
        config.Address = model.Address.Trim();
        config.Hotline = !string.IsNullOrWhiteSpace(model.Hotline) ? model.Hotline.Trim() : config.Hotline;
        config.OpenHours = !string.IsNullOrWhiteSpace(model.OpenHours) ? model.OpenHours.Trim() : config.OpenHours;

        config.Latitude = model.Latitude != 0 ? model.Latitude : config.Latitude;
        config.Longitude = model.Longitude != 0 ? model.Longitude : config.Longitude;

        // Tự động khớp tọa độ theo địa chỉ nếu tọa độ chưa được cập nhật từ giao diện web
        var addrLower = config.Address.ToLowerInvariant();
        if ((addrLower.Contains("lê trọng tấn") || addrLower.Contains("tây thạnh") || addrLower.Contains("tân phú")) && Math.Abs(config.Latitude - 10.7380) < 0.001)
        {
            config.Latitude = 10.8070;
            config.Longitude = 106.6287;
        }
        else if ((addrLower.Contains("bến thành") || addrLower.Contains("lê lợi") || addrLower.Contains("quận 1")) && Math.Abs(config.Latitude - 10.7380) < 0.001)
        {
            config.Latitude = 10.7725;
            config.Longitude = 106.6980;
        }
        else if ((addrLower.Contains("vinhomes") || addrLower.Contains("bình thạnh")) && Math.Abs(config.Latitude - 10.7380) < 0.001)
        {
            config.Latitude = 10.7930;
            config.Longitude = 106.7215;
        }
        else if ((addrLower.Contains("thủ đức") || addrLower.Contains("võ văn ngân")) && Math.Abs(config.Latitude - 10.7380) < 0.001)
        {
            config.Latitude = 10.8512;
            config.Longitude = 106.7720;
        }

        config.BaseShippingFee = model.BaseShippingFee > 0 ? model.BaseShippingFee : config.BaseShippingFee;
        config.Tier2ShippingFee = model.Tier2ShippingFee > 0 ? model.Tier2ShippingFee : config.Tier2ShippingFee;
        config.Tier3ShippingFee = model.Tier3ShippingFee > 0 ? model.Tier3ShippingFee : config.Tier3ShippingFee;
        config.ExpressExtraFee = model.ExpressExtraFee >= 0 ? model.ExpressExtraFee : config.ExpressExtraFee;

        // Chuẩn hóa thông tin ngân hàng
        config.BankName = !string.IsNullOrWhiteSpace(model.BankName) ? model.BankName.Trim() : config.BankName;
        config.BankBin = !string.IsNullOrWhiteSpace(model.BankBin) ? model.BankBin.Trim() : "970422";
        config.BankAccountNo = !string.IsNullOrWhiteSpace(model.BankAccountNo) ? model.BankAccountNo.Trim() : "0908123456";
        config.BankAccountHolder = !string.IsNullOrWhiteSpace(model.BankAccountHolder)
            ? model.BankAccountHolder.Trim().ToUpperInvariant()
            : "WASH SMART 3T";

        if (!string.IsNullOrWhiteSpace(model.SmsApiKey)) config.SmsApiKey = model.SmsApiKey.Trim();
        if (!string.IsNullOrWhiteSpace(model.SmsApiSecret)) config.SmsApiSecret = model.SmsApiSecret.Trim();
        if (!string.IsNullOrWhiteSpace(model.SmsBrandName)) config.SmsBrandName = model.SmsBrandName.Trim();
        if (!string.IsNullOrWhiteSpace(model.SmsOtpTemplate)) config.SmsOtpTemplate = model.SmsOtpTemplate.Trim();

        config.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật cấu hình cửa hàng, tài khoản ngân hàng và SMS vào CSDL thành công!",
            config
        });
    }

    // ============================================================
    // POST: api/StoreConfig/test-sms
    // Chỉ Quản trị viên (Admin) mới được kích hoạt kiểm tra cổng SMS.
    // LƯU Ý BẢO MẬT: KHÔNG TRẢ MÃ OTP TRONG JSON RESPONSE.
    // Giới hạn tần suất 1 lần / 60 giây để chống lạm dụng đốt tiền SMS.
    // ============================================================
    [HttpPost("test-sms")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> TestSms([FromBody] TestSmsRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Phone))
        {
            return BadRequest(new { message = "Vui lòng nhập số điện thoại người nhận." });
        }

        var (_, _, cleanPhone) = SmsService.NormalizePhone(req.Phone);
        if (string.IsNullOrEmpty(cleanPhone) || cleanPhone.Length < 10 || cleanPhone.Length > 11 || !cleanPhone.StartsWith("0"))
        {
            return BadRequest(new { message = "Số điện thoại không đúng định dạng di động Việt Nam." });
        }

        if (_smsRateLimits.TryGetValue(cleanPhone, out var lastSent))
        {
            var elapsed = DateTime.UtcNow - lastSent;
            if (elapsed < TimeSpan.FromSeconds(60))
            {
                var remain = 60 - (int)elapsed.TotalSeconds;
                return StatusCode(StatusCodes.Status429TooManyRequests, new
                {
                    message = $"Vui lòng đợi {remain} giây trước khi gửi SMS kiểm thử tiếp theo."
                });
            }
        }

        var config = await GetOrCreateConfigAsync();

        var (smsSuccess, smsMsg) = await SmsService.SendSmsAsync(
            cleanPhone,
            req.Message ?? "Day la tin nhan kiem tra he thong SMS Gateway tu WashSmart 3T.",
            config.SmsApiKey,
            config.SmsApiSecret,
            config.SmsBrandName
        );

        _smsRateLimits[cleanPhone] = DateTime.UtcNow;

        if (!smsSuccess)
        {
            return StatusCode(502, new
            {
                message = "Gửi SMS kiểm tra thất bại: " + smsMsg
            });
        }

        return Ok(new
        {
            message = $"Đã gửi tin nhắn SMS kiểm thử thành công tới số {cleanPhone}!",
            phone = cleanPhone,
            sentAt = DateTime.UtcNow
        });
    }

    // ============================================================
    // POST: api/StoreConfig/reset
    // Chỉ Quản trị viên (Admin) mới có quyền khôi phục về mặc định.
    // ============================================================
    [HttpPost("reset")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ResetDefault()
    {
        var config = await GetOrCreateConfigAsync();

        var defaultCfg = new StoreConfig();
        config.StoreName = defaultCfg.StoreName;
        config.Address = defaultCfg.Address;
        config.Latitude = defaultCfg.Latitude;
        config.Longitude = defaultCfg.Longitude;
        config.Hotline = defaultCfg.Hotline;
        config.OpenHours = defaultCfg.OpenHours;
        config.BaseShippingFee = defaultCfg.BaseShippingFee;
        config.Tier2ShippingFee = defaultCfg.Tier2ShippingFee;
        config.Tier3ShippingFee = defaultCfg.Tier3ShippingFee;
        config.Tier1MaxKm = defaultCfg.Tier1MaxKm;
        config.Tier2MaxKm = defaultCfg.Tier2MaxKm;
        config.Tier3MaxKm = defaultCfg.Tier3MaxKm;
        config.ExpressExtraFee = defaultCfg.ExpressExtraFee;
        config.AddonComfortFee = defaultCfg.AddonComfortFee;
        config.AddonBagFee = defaultCfg.AddonBagFee;
        config.FreeShipMinAmount = defaultCfg.FreeShipMinAmount;
        config.BankName = defaultCfg.BankName;
        config.BankBin = defaultCfg.BankBin;
        config.BankAccountNo = defaultCfg.BankAccountNo;
        config.BankAccountHolder = defaultCfg.BankAccountHolder;
        config.SmsApiKey = defaultCfg.SmsApiKey;
        config.SmsApiSecret = defaultCfg.SmsApiSecret;
        config.SmsBrandName = defaultCfg.SmsBrandName;
        config.SmsOtpTemplate = defaultCfg.SmsOtpTemplate;
        config.UpdatedAt = DateTime.UtcNow;

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Đã khôi phục cấu hình cửa hàng về mặc định trong CSDL thành công!",
            config
        });
    }
}
