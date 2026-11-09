using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Models;
using WashSmart.API.Services;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using System.Collections.Concurrent;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private static readonly ConcurrentDictionary<string, DateTime> _otpCooldowns = new();
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _env;

    public AuthController(
        ApplicationDbContext context,
        IConfiguration configuration,
        IWebHostEnvironment env)
    {
        _context = context;
        _configuration = configuration;
        _env = env;
    }

    private StoreConfigModel GetStoreConfig()
    {
        var path = Path.Combine(_env.ContentRootPath, "store_config.json");
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
        return new StoreConfigModel();
    }

    // ============================================================
    // POST: api/Auth/send-registration-otp
    // Gửi mã OTP xác thực trước khi đăng ký tài khoản khách hàng mới.
    // Giới hạn tần suất 60s/lần gửi để chống SMS toll fraud & spam.
    // ============================================================
    [HttpPost("send-registration-otp")]
    [AllowAnonymous]
    public async Task<IActionResult> SendRegistrationOtp([FromBody] SendOtpRequest request)
    {
        if (!ModelState.IsValid)
        {
            var firstError = ModelState.Values.SelectMany(v => v.Errors).FirstOrDefault()?.ErrorMessage;
            return BadRequest(new { message = firstError ?? "Dữ liệu không hợp lệ." });
        }

        var (_, _, cleanPhone) = SmsService.NormalizePhone(request.Phone);
        var phone = cleanPhone;

        // 1. Kiểm tra số điện thoại đã đăng ký tài khoản chưa (cho phép nếu là tài khoản vãng lai POS)
        var existingUser = await _context.Users.FirstOrDefaultAsync(x => x.Phone == phone);
        if (existingUser != null)
        {
            bool isPosGhost = existingUser.Email.EndsWith("@customer.washsmart.local") ||
                              existingUser.Email.StartsWith("pos-");
            if (!isPosGhost)
            {
                return BadRequest(new
                {
                    message = "Số điện thoại này đã được đăng ký tài khoản. Vui lòng đăng nhập hoặc dùng chức năng Quên mật khẩu."
                });
            }
        }

        // 2. Chống spam SMS: giới hạn 60 giây giữa các lần yêu cầu
        if (_otpCooldowns.TryGetValue(phone, out var lastSent))
        {
            var elapsed = DateTime.UtcNow - lastSent;
            if (elapsed < TimeSpan.FromSeconds(60))
            {
                var remain = 60 - (int)elapsed.TotalSeconds;
                return StatusCode(StatusCodes.Status429TooManyRequests, new
                {
                    message = $"Vui lòng đợi {remain} giây trước khi yêu cầu gửi lại mã OTP mới."
                });
            }
        }

        _otpCooldowns[phone] = DateTime.UtcNow;

        // 3. Sinh mã OTP bảo mật 6 số và lưu cache (hạn 5 phút, tối đa 5 lần thử)
        var otpCode = OtpManager.GenerateOtp("Register", phone);
        var storeConfig = GetStoreConfig();

        // 4. Gửi SMS đến số điện thoại thật
        var smsResult = await SmsService.SendOtpSmsAsync(phone, otpCode, "Register", storeConfig);

        return Ok(new
        {
            success = true,
            message = $"Mã OTP xác thực đã được gửi tới số {phone}. Mã có hiệu lực trong 5 phút.",
            phone = phone,
            isSimulated = smsResult.IsSimulated,
            // Hỗ trợ hiển thị devHint khi đang ở chế độ Simulation để chấm đồ án/thử nghiệm thuận lợi
            devHint = smsResult.IsSimulated ? $"[Chế độ Demo] Mã OTP của bạn là: {otpCode}" : null
        });
    }

    // ============================================================
    // POST: api/Auth/register
    // Đăng ký tài khoản: BẮT BUỘC xác thực mã OTP trước khi tạo User
    // ============================================================
    [HttpPost("register")]
    [AllowAnonymous]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        if (!ModelState.IsValid)
        {
            var firstError = ModelState.Values.SelectMany(v => v.Errors).FirstOrDefault()?.ErrorMessage;
            return BadRequest(new { message = firstError ?? "Dữ liệu đăng ký không hợp lệ." });
        }

        var (_, _, cleanPhone) = SmsService.NormalizePhone(request.Phone);
        var phone = cleanPhone;

        // 1. Xác thực mã OTP
        var (isValidOtp, otpError) = OtpManager.VerifyOtp("Register", phone, request.OtpCode);
        if (!isValidOtp)
        {
            return BadRequest(new
            {
                message = otpError
            });
        }

        // 2. Kiểm tra số điện thoại đã tồn tại (hỗ trợ chuyển đổi tài khoản vãng lai POS)
        var existingUser = await _context.Users
            .FirstOrDefaultAsync(x => x.Phone == phone);

        if (existingUser != null)
        {
            bool isPosGhost = existingUser.Email.EndsWith("@customer.washsmart.local") ||
                              existingUser.Email.StartsWith("pos-");

            if (isPosGhost)
            {
                existingUser.FullName = request.FullName.Trim();
                existingUser.Email = request.Email.Trim();
                existingUser.PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);
                existingUser.IsActive = true;
                await _context.SaveChangesAsync();

                return Ok(new
                {
                    message = "Kích hoạt và đồng bộ lịch sử đơn hàng từ quầy POS thành công! Bạn có thể đăng nhập ngay.",
                    userId = existingUser.Id
                });
            }

            return BadRequest(new
            {
                message = "Số điện thoại đã được đăng ký tài khoản."
            });
        }

        // 3. Tìm Role Customer
        var customerRole = await _context.Roles
            .FirstOrDefaultAsync(x => x.Name == "Customer");

        if (customerRole == null)
        {
            return BadRequest(new
            {
                message = "Chưa có vai trò Customer trong hệ thống."
            });
        }

        // 4. Tạo tài khoản với mật khẩu hash BCrypt an toàn
        var user = new User
        {
            FullName = request.FullName.Trim(),
            Phone = phone,
            Email = request.Email.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            RoleId = customerRole.Id,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Đăng ký tài khoản thành công! Bạn có thể đăng nhập ngay bây giờ.",
            userId = user.Id
        });
    }

    // ============================================================
    // POST: api/Auth/create-shipper
    // Chỉ Quản trị viên (Admin) mới có quyền tạo tài khoản Shipper
    // ============================================================
    [Authorize(Roles = "Admin")]
    [HttpPost("create-shipper")]
    public async Task<IActionResult> CreateShipper([FromBody] CreateShipperRequest request)
    {
        var existingPhone = await _context.Users
            .AnyAsync(x => x.Phone == request.Phone);

        if (existingPhone)
        {
            return BadRequest(new
            {
                message = "Số điện thoại đã được sử dụng."
            });
        }

        var existingEmail = await _context.Users
            .AnyAsync(x => x.Email == request.Email);

        if (existingEmail)
        {
            return BadRequest(new
            {
                message = "Email đã được sử dụng."
            });
        }

        var shipperRole = await _context.Roles
            .FirstOrDefaultAsync(x => x.Name == "Shipper");

        if (shipperRole == null)
        {
            return BadRequest(new
            {
                message = "Chưa có vai trò Shipper trong hệ thống."
            });
        }

        var user = new User
        {
            FullName = request.FullName.Trim(),
            Phone = request.Phone.Trim(),
            Email = request.Email.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            RoleId = shipperRole.Id,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Tạo tài khoản Shipper thành công.",
            userId = user.Id,
            role = "Shipper"
        });
    }

    // ============================================================
    // POST: api/Auth/login
    // Đăng nhập: Áp dụng cơ chế khóa tài khoản (Account Lockout)
    // khi nhập sai mật khẩu quá 5 lần (khóa 15 phút chống brute-force)
    // ============================================================
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        if (!ModelState.IsValid)
        {
            var firstError = ModelState.Values.SelectMany(v => v.Errors).FirstOrDefault()?.ErrorMessage;
            return BadRequest(new { message = firstError ?? "Thông tin đăng nhập không hợp lệ." });
        }

        var (_, _, cleanPhone) = SmsService.NormalizePhone(request.Phone);
        var phone = cleanPhone;

        // 1. Kiểm tra tài khoản có đang bị khóa do nhập sai nhiều lần không
        var (isLocked, remainingMinutes) = AccountLockoutManager.CheckLockout(phone);
        if (isLocked)
        {
            return StatusCode(StatusCodes.Status423Locked, new
            {
                message = $"Tài khoản tạm thời bị khóa do nhập sai mật khẩu quá 5 lần. Vui lòng thử lại sau {remainingMinutes} phút để đảm bảo an toàn."
            });
        }

        var user = await _context.Users
            .Include(x => x.Role)
            .FirstOrDefaultAsync(x => x.Phone == phone);

        if (user == null)
        {
            AccountLockoutManager.RecordFailedAttempt(phone);
            return Unauthorized(new
            {
                message = "Số điện thoại hoặc mật khẩu không đúng."
            });
        }

        if (!user.IsActive)
        {
            return Unauthorized(new
            {
                message = "Tài khoản của bạn đã bị khóa hoặc ngừng hoạt động. Vui lòng liên hệ quản trị viên."
            });
        }

        var passwordValid = BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash);

        if (!passwordValid)
        {
            var (isLockedNow, remainingAttempts, lockMinutes) = AccountLockoutManager.RecordFailedAttempt(phone);
            if (isLockedNow)
            {
                return StatusCode(StatusCodes.Status423Locked, new
                {
                    message = $"Bạn đã nhập sai mật khẩu 5 lần. Tài khoản tạm thời bị khóa trong {lockMinutes} phút."
                });
            }

            return Unauthorized(new
            {
                message = $"Số điện thoại hoặc mật khẩu không đúng. Bạn còn {remainingAttempts} lần thử trước khi bị khóa tạm thời."
            });
        }

        // Đăng nhập thành công -> Xóa bộ đếm số lần sai
        AccountLockoutManager.RecordSuccessfulLogin(phone);

        // Sinh JWT token bảo mật
        var token = GenerateJwtToken(user);

        return Ok(new
        {
            message = "Đăng nhập thành công.",
            token = token,
            user = new
            {
                id = user.Id,
                fullName = user.FullName,
                phone = user.Phone,
                email = user.Email,
                role = user.Role?.Name,
                isActive = user.IsActive
            }
        });
    }

    // ============================================================
    // GET: api/Auth/me
    // Lấy thông tin phiên đăng nhập hiện tại từ CSDL (kiểm tra IsActive tươi)
    // ============================================================
    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userIdClaim == null || !int.TryParse(userIdClaim, out int userId))
        {
            return Unauthorized(new { message = "Token không hợp lệ hoặc đã hết hạn." });
        }

        var user = await _context.Users
            .Include(x => x.Role)
            .FirstOrDefaultAsync(x => x.Id == userId);

        if (user == null)
        {
            return NotFound(new { message = "Không tìm thấy người dùng." });
        }

        if (!user.IsActive)
        {
            return Unauthorized(new { message = "Tài khoản đã bị quản trị viên khóa hoặc vô hiệu hóa." });
        }

        return Ok(new
        {
            id = user.Id,
            fullName = user.FullName,
            phone = user.Phone,
            email = user.Email,
            role = user.Role?.Name,
            isActive = user.IsActive
        });
    }

    private string GenerateJwtToken(User user)
    {
        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.FullName),
            new Claim(ClaimTypes.MobilePhone, user.Phone),
            new Claim(ClaimTypes.Role, user.Role?.Name ?? "Customer"),
            new Claim("isActive", user.IsActive.ToString())
        };

        var jwtKey = _configuration["Jwt:Key"] ?? "WashSmart3T_SuperSecretKey_2026_VeryLongKey_DefaultFallbackForSecurityCheck";
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        // JWT token thời hạn 2 giờ (thay vì 8 giờ vô hạn định) để hạn chế rủi ro token bị đánh cắp
        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"] ?? "WashSmart.API",
            audience: _configuration["Jwt:Audience"] ?? "WashSmart.Client",
            claims: claims,
            expires: DateTime.UtcNow.AddHours(2),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    // ============================================================
    // PUT: api/Auth/profile
    // Cập nhật thông tin cá nhân
    // ============================================================
    [Authorize]
    [HttpPut("profile")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null || !int.TryParse(userIdClaim.Value, out int userId))
        {
            return Unauthorized(new { message = "Không xác định được người dùng." });
        }

        var user = await _context.Users
            .Include(x => x.Role)
            .FirstOrDefaultAsync(x => x.Id == userId && x.IsActive);

        if (user == null)
        {
            return NotFound(new { message = "Tài khoản không tồn tại hoặc đã bị khóa." });
        }

        if (string.IsNullOrWhiteSpace(request.FullName))
        {
            return BadRequest(new { message = "Họ tên không được để trống." });
        }

        if (string.IsNullOrWhiteSpace(request.Phone))
        {
            return BadRequest(new { message = "Số điện thoại không được để trống." });
        }

        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new { message = "Email không được để trống." });
        }

        var phoneExists = await _context.Users.AnyAsync(x => x.Phone == request.Phone && x.Id != userId);
        if (phoneExists)
        {
            return BadRequest(new { message = "Số điện thoại đã được sử dụng bởi tài khoản khác." });
        }

        var emailExists = await _context.Users.AnyAsync(x => x.Email == request.Email && x.Id != userId);
        if (emailExists)
        {
            return BadRequest(new { message = "Email đã được sử dụng bởi tài khoản khác." });
        }

        user.FullName = request.FullName.Trim();
        user.Phone = request.Phone.Trim();
        user.Email = request.Email.Trim();

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật thông tin cá nhân thành công.",
            user = new
            {
                user.Id,
                user.FullName,
                user.Phone,
                user.Email,
                role = user.Role?.Name,
                user.IsActive
            }
        });
    }
}
