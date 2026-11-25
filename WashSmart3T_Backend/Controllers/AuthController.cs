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

    private async Task<StoreConfig> GetStoreConfigAsync()
    {
        return await _context.StoreConfigs.AsNoTracking().FirstOrDefaultAsync(c => c.Id == 1) ?? new StoreConfig();
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

        // 1.1 Kiểm tra email đã đăng ký chưa nếu có truyền email
        if (!string.IsNullOrWhiteSpace(request.Email))
        {
            var cleanEmail = request.Email.Trim();
            var existingEmail = await _context.Users.FirstOrDefaultAsync(x => x.Email == cleanEmail);
            if (existingEmail != null)
            {
                bool isPosGhost = existingEmail.Email.EndsWith("@customer.washsmart.local") ||
                                  existingEmail.Email.StartsWith("pos-");
                if (!isPosGhost)
                {
                    return BadRequest(new
                    {
                        message = "Địa chỉ Email này đã được đăng ký tài khoản khác. Vui lòng dùng email khác hoặc Đăng nhập."
                    });
                }
            }
        }

        // 2. Chống spam SMS/Email: giới hạn 60 giây giữa các lần yêu cầu
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
        var storeConfig = await GetStoreConfigAsync();

        // 4. Gửi OTP qua Email (Gmail SMTP) nếu người dùng có cung cấp Email
        bool emailSuccess = false;
        string? emailAddress = request.Email?.Trim();
        if (!string.IsNullOrWhiteSpace(emailAddress))
        {
            var (eSuccess, eMsg, isESimulated) = await EmailService.SendOtpEmailAsync(
                emailAddress, otpCode, "Register", _configuration, request.FullName);
            emailSuccess = eSuccess;
        }

        // 5. Gửi SMS đến số điện thoại thật qua SmsService
        var smsResult = await SmsService.SendOtpSmsAsync(phone, otpCode, "Register", storeConfig);

        string returnMsg = !string.IsNullOrWhiteSpace(emailAddress)
            ? $"Mã OTP xác thực đã được gửi tới email {emailAddress} (và SMS số {phone}). Vui lòng kiểm tra hộp thư đến hoặc mục Thư rác/Spam!"
            : $"Mã OTP xác thực đã được gửi tới số {phone}. Mã có hiệu lực trong 5 phút.";

        return Ok(new
        {
            success = true,
            message = returnMsg,
            phone = phone,
            email = emailAddress,
            isSimulated = smsResult.IsSimulated,
            // Hỗ trợ hiển thị devHint khi đang ở chế độ Simulation để chấm đồ án/thử nghiệm thuận lợi
            devHint = smsResult.IsSimulated ? $"[Chế độ Demo/Email] Mã OTP của bạn là: {otpCode}" : null
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

                // Đồng bộ toàn bộ đơn hàng POS gắn số điện thoại này vào user
                var ghostOrders = await _context.Orders
                    .Where(o => o.ContactPhone == phone && o.CustomerId != existingUser.Id)
                    .ToListAsync();
                foreach (var ord in ghostOrders)
                {
                    ord.CustomerId = existingUser.Id;
                }

                var totalSpent = await _context.Orders
                    .Where(o => o.CustomerId == existingUser.Id && o.Status == OrderStatus.Completed)
                    .SumAsync(o => (decimal?)o.TotalAmount) ?? 0m;
                existingUser.TotalSpent = totalSpent;
                existingUser.MembershipTier = LoyaltyService.CalculateTier(existingUser.TotalSpent, existingUser.LoyaltyPoints);

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

        // Đồng bộ toàn bộ đơn hàng POS đã tạo trước đó gắn với số điện thoại này vào tài khoản mới
        var unlinkedOrders = await _context.Orders
            .Where(o => o.ContactPhone == phone && o.CustomerId != user.Id)
            .ToListAsync();
        if (unlinkedOrders.Any())
        {
            foreach (var ord in unlinkedOrders)
            {
                ord.CustomerId = user.Id;
            }
            var totalSpent = await _context.Orders
                .Where(o => o.CustomerId == user.Id && o.Status == OrderStatus.Completed)
                .SumAsync(o => (decimal?)o.TotalAmount) ?? 0m;
            user.TotalSpent = totalSpent;
            user.MembershipTier = LoyaltyService.CalculateTier(user.TotalSpent, user.LoyaltyPoints);
            await _context.SaveChangesAsync();
        }

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
    // POST: api/Auth/create-staff
    // Chỉ Quản trị viên (Admin) mới có quyền tạo tài khoản Lễ tân / Nhân viên tiếp nhận (Staff)
    // ============================================================
    [Authorize(Roles = "Admin")]
    [HttpPost("create-staff")]
    public async Task<IActionResult> CreateStaff([FromBody] CreateStaffRequest request)
    {
        var (_, _, cleanPhone) = SmsService.NormalizePhone(request.Phone);

        var existingPhone = await _context.Users.AnyAsync(x => x.Phone == cleanPhone);
        if (existingPhone)
        {
            return BadRequest(new { message = "Số điện thoại đã được sử dụng." });
        }

        var existingEmail = await _context.Users.AnyAsync(x => x.Email == request.Email);
        if (existingEmail)
        {
            return BadRequest(new { message = "Email đã được sử dụng." });
        }

        var staffRole = await _context.Roles.FirstOrDefaultAsync(x => x.Name == "Staff");
        if (staffRole == null)
        {
            return BadRequest(new { message = "Chưa có vai trò Staff trong hệ thống." });
        }

        var user = new User
        {
            FullName = request.FullName.Trim(),
            Phone = cleanPhone,
            Email = request.Email.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            RoleId = staffRole.Id,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Tạo tài khoản Nhân viên (Staff) thành công.",
            userId = user.Id,
            role = "Staff"
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

        // Nếu là Shipper đăng nhập -> Đánh dấu ngay lập tức là Online / Đang trực ca
        if (user.Role?.Name == "Shipper")
        {
            OrdersController.RecordShipperOnline(user.Id);
        }

        // Tự động đồng bộ các đơn POS đã tạo trước đó gắn với số điện thoại này vào user.Id
        if (user.Role?.Name == "Customer")
        {
            var unlinkedOrders = await _context.Orders
                .Where(o => o.ContactPhone == phone && o.CustomerId != user.Id)
                .ToListAsync();
            if (unlinkedOrders.Any())
            {
                foreach (var ord in unlinkedOrders)
                {
                    ord.CustomerId = user.Id;
                }
                var totalSpent = await _context.Orders
                    .Where(o => o.CustomerId == user.Id && o.Status == OrderStatus.Completed)
                    .SumAsync(o => (decimal?)o.TotalAmount) ?? 0m;
                user.TotalSpent = totalSpent;
                await _context.SaveChangesAsync();
            }
        }

        // Đồng bộ cấp bậc thành viên theo điểm và tổng chi tiêu
        var calculatedTier = LoyaltyService.CalculateTier(user.TotalSpent, user.LoyaltyPoints);
        if (user.MembershipTier != calculatedTier)
        {
            user.MembershipTier = calculatedTier;
            await _context.SaveChangesAsync();
        }

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
                address = user.Address,
                role = user.Role?.Name,
                isActive = user.IsActive,
                loyaltyPoints = user.LoyaltyPoints,
                membershipTier = user.MembershipTier,
                totalSpent = user.TotalSpent
            }
        });
    }

    // ============================================================
    // POST: api/Auth/logout
    // Đăng xuất: Đồng bộ tài xế offline khỏi hàng đợi điều phối
    // ============================================================
    [HttpPost("logout")]
    [Authorize]
    public IActionResult Logout()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (int.TryParse(userIdClaim, out int userId))
        {
            OrdersController.RecordShipperOffline(userId);
        }
        return Ok(new { message = "Đăng xuất thành công." });
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

        var calculatedTier = LoyaltyService.CalculateTier(user.TotalSpent, user.LoyaltyPoints);
        if (user.MembershipTier != calculatedTier)
        {
            user.MembershipTier = calculatedTier;
            await _context.SaveChangesAsync();
        }

        return Ok(new
        {
            id = user.Id,
            fullName = user.FullName,
            phone = user.Phone,
            email = user.Email,
            address = user.Address,
            role = user.Role?.Name,
            isActive = user.IsActive,
            loyaltyPoints = user.LoyaltyPoints,
            membershipTier = user.MembershipTier,
            totalSpent = user.TotalSpent
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

        // JWT token thời hạn 7 ngày cho ca làm việc của Shipper & Quản lý vận hành
        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"] ?? "WashSmart.API",
            audience: _configuration["Jwt:Audience"] ?? "WashSmart.Client",
            claims: claims,
            expires: DateTime.UtcNow.AddDays(7),
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
        if (request.Address != null)
        {
            user.Address = request.Address.Trim();
        }

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
                user.Address,
                role = user.Role?.Name,
                user.IsActive
            }
        });
    }

    // ============================================================
    // POST: api/Auth/forgot-password-otp
    // Gửi mã OTP đặt lại mật khẩu về Email đã đăng ký của tài khoản
    // ============================================================
    [HttpPost("forgot-password-otp")]
    [AllowAnonymous]
    public async Task<IActionResult> SendForgotPasswordOtp([FromBody] ForgotPasswordOtpRequest request)
    {
        var rawIdentifier = (request.Identifier ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(rawIdentifier))
        {
            return BadRequest(new { message = "Vui lòng nhập Email hoặc Số điện thoại tài khoản." });
        }

        User? user = null;
        if (rawIdentifier.Contains('@'))
        {
            var cleanEmail = rawIdentifier.ToLowerInvariant();
            user = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == cleanEmail);
        }
        else
        {
            var (_, _, normalizedPhone) = SmsService.NormalizePhone(rawIdentifier);
            var lookupPhone = !string.IsNullOrWhiteSpace(normalizedPhone) ? normalizedPhone : rawIdentifier;
            user = await _context.Users.FirstOrDefaultAsync(u => u.Phone == lookupPhone || u.Phone == rawIdentifier);
        }

        if (user == null)
        {
            return NotFound(new { message = "Không tìm thấy tài khoản nào với Email hoặc Số điện thoại này." });
        }

        if (!user.IsActive)
        {
            return BadRequest(new { message = "Tài khoản này đang bị tạm khóa. Vui lòng liên hệ quản trị viên." });
        }

        var userEmail = (user.Email ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(userEmail) || !userEmail.Contains('@') || userEmail.EndsWith("@customer.washsmart.local", StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new { message = "Tài khoản này chưa cập nhật địa chỉ Email thật để nhận OTP. Vui lòng liên hệ quầy WashSmart 3T để được hỗ trợ." });
        }

        var emailKey = userEmail.ToLowerInvariant();
        var cooldownKey = $"Reset:{emailKey}";

        if (_otpCooldowns.TryGetValue(cooldownKey, out var lastSent))
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

        _otpCooldowns[cooldownKey] = DateTime.UtcNow;

        var otpCode = OtpManager.GenerateOtp("ResetPassword", emailKey);
        var (emailSent, emailMsg, isSimulated) = await EmailService.SendOtpEmailAsync(
            userEmail, otpCode, "ResetPassword", _configuration, user.FullName);

        if (!emailSent)
        {
            return StatusCode(500, new { message = "Không thể gửi email OTP lúc này. Vui lòng thử lại sau." });
        }

        var maskedEmail = MaskEmail(userEmail);

        return Ok(new
        {
            success = true,
            message = $"Mã OTP xác thực đặt lại mật khẩu đã được gửi về email {maskedEmail}. Vui lòng kiểm tra hộp thư đến hoặc mục Spam và tự nhập mã OTP.",
            maskedEmail,
            isSimulated,
            devHint = isSimulated ? $"[Chế độ Demo] Mã OTP đặt lại mật khẩu là: {otpCode}" : null
        });
    }

    // ============================================================
    // POST: api/Auth/reset-password
    // Xác thực OTP khách hàng tự nhập & cập nhật mật khẩu mới
    // ============================================================
    [HttpPost("reset-password")]
    [AllowAnonymous]
    public async Task<IActionResult> ResetPassword([FromBody] ForgotPasswordResetRequest request)
    {
        var rawIdentifier = (request.Identifier ?? string.Empty).Trim();
        var otpCode = (request.OtpCode ?? string.Empty).Trim();
        var newPassword = request.NewPassword ?? string.Empty;

        if (string.IsNullOrWhiteSpace(rawIdentifier))
            return BadRequest(new { message = "Vui lòng nhập Email hoặc Số điện thoại tài khoản." });

        if (string.IsNullOrWhiteSpace(otpCode) || otpCode.Length != 6)
            return BadRequest(new { message = "Vui lòng nhập đầy đủ mã OTP gồm 6 chữ số." });

        if (newPassword.Length < 6)
            return BadRequest(new { message = "Mật khẩu mới phải có ít nhất 6 ký tự." });

        User? user = null;
        if (rawIdentifier.Contains('@'))
        {
            var cleanEmail = rawIdentifier.ToLowerInvariant();
            user = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == cleanEmail);
        }
        else
        {
            var (_, _, normalizedPhone) = SmsService.NormalizePhone(rawIdentifier);
            var lookupPhone = !string.IsNullOrWhiteSpace(normalizedPhone) ? normalizedPhone : rawIdentifier;
            user = await _context.Users.FirstOrDefaultAsync(u => u.Phone == lookupPhone || u.Phone == rawIdentifier);
        }

        if (user == null)
            return NotFound(new { message = "Không tìm thấy tài khoản tương ứng." });

        var emailKey = (user.Email ?? string.Empty).Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(emailKey))
            return BadRequest(new { message = "Tài khoản không có Email hợp lệ." });

        var (isValidOtp, otpError) = OtpManager.VerifyOtp("ResetPassword", emailKey, otpCode);
        if (!isValidOtp)
        {
            return BadRequest(new { message = otpError });
        }

        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPassword);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            success = true,
            message = "Đặt lại mật khẩu thành công! Bạn có thể đăng nhập bằng mật khẩu mới ngay bây giờ."
        });
    }

    private static string MaskEmail(string email)
    {
        var parts = email.Split('@');
        if (parts.Length != 2) return email;
        var local = parts[0];
        var domain = parts[1];
        if (local.Length <= 2) return $"{local[0]}***@{domain}";
        return $"{local.Substring(0, 2)}***{local.Substring(local.Length - 1)}@{domain}";
    }
}

public class ForgotPasswordOtpRequest
{
    public string Identifier { get; set; } = string.Empty;
}

public class ForgotPasswordResetRequest
{
    public string Identifier { get; set; } = string.Empty;
    public string OtpCode { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}
