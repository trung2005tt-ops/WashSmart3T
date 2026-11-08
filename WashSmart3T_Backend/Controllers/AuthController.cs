using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Models;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{

    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    public AuthController(ApplicationDbContext context, IConfiguration configuration)
    {
        _context = context;
        _configuration = configuration;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest request)
    {
        // Kiểm tra số điện thoại đã tồn tại
        var existingUser = await _context.Users
            .FirstOrDefaultAsync(x => x.Phone == request.Phone);

        if (existingUser != null)
        {
            return BadRequest(new
            {
                message = "Số điện thoại đã được đăng ký."
            });
        }

        // Tìm Role Customer
        var customerRole = await _context.Roles
            .FirstOrDefaultAsync(x => x.Name == "Customer");

        if (customerRole == null)
        {
            return BadRequest(new
            {
                message = "Chưa có vai trò Customer."
            });
        }

        // Tạo tài khoản
        var user = new User
        {
            FullName = request.FullName,
            Phone = request.Phone,
            Email = request.Email,

            PasswordHash = BCrypt.Net.BCrypt.HashPassword(
                request.Password
            ),

            RoleId = customerRole.Id,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Đăng ký tài khoản thành công.",
            userId = user.Id
        });
    }

    // ============================================================
    // POST: api/Auth/create-shipper
    // Chỉ Admin mới được tạo tài khoản Shipper
    // ============================================================
    [Authorize(Roles = "Admin")]
    [HttpPost("create-shipper")]
    public async Task<IActionResult> CreateShipper(CreateShipperRequest request)
    {
        // Kiểm tra số điện thoại
        var existingPhone = await _context.Users
            .AnyAsync(x => x.Phone == request.Phone);

        if (existingPhone)
        {
            return BadRequest(new
            {
                message = "Số điện thoại đã được sử dụng."
            });
        }

        // Kiểm tra email
        var existingEmail = await _context.Users
            .AnyAsync(x => x.Email == request.Email);

        if (existingEmail)
        {
            return BadRequest(new
            {
                message = "Email đã được sử dụng."
            });
        }

        // Tìm Role Shipper
        var shipperRole = await _context.Roles
            .FirstOrDefaultAsync(x => x.Name == "Shipper");

        if (shipperRole == null)
        {
            return BadRequest(new
            {
                message = "Chưa có vai trò Shipper trong hệ thống."
            });
        }

        // Tạo tài khoản
        var user = new User
        {
            FullName = request.FullName.Trim(),
            Phone = request.Phone.Trim(),
            Email = request.Email.Trim(),

            PasswordHash = BCrypt.Net.BCrypt.HashPassword(
                request.Password
            ),

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

    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest request)
    {
        var user = await _context.Users
            .Include(x => x.Role)
            .FirstOrDefaultAsync(x => x.Phone == request.Phone);

        if (user == null)
        {
            return Unauthorized(new
            {
                message = "Số điện thoại hoặc mật khẩu không đúng."
            });
        }

        if (!user.IsActive)
        {
            return Unauthorized(new
            {
                message = "Tài khoản đã bị khóa."
            });
        }

        var passwordValid = BCrypt.Net.BCrypt.Verify(
            request.Password,
            user.PasswordHash
        );

        if (!passwordValid)
        {
            return Unauthorized(new
            {
                message = "Số điện thoại hoặc mật khẩu không đúng."
            });
        }

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
                role = user.Role?.Name
            }
        });
    }
    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (userIdClaim == null)
        {
            return Unauthorized(new
            {
                message = "Token không hợp lệ."
            });
        }

        if (!int.TryParse(userIdClaim, out int userId))
        {
            return Unauthorized(new
            {
                message = "User ID không hợp lệ."
            });
        }

        var user = await _context.Users
            .Include(x => x.Role)
            .FirstOrDefaultAsync(x => x.Id == userId);

        if (user == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy người dùng."
            });
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
        new Claim(
            ClaimTypes.NameIdentifier,
            user.Id.ToString()
        ),

        new Claim(
            ClaimTypes.Name,
            user.FullName
        ),

        new Claim(
            ClaimTypes.MobilePhone,
            user.Phone
        ),

        new Claim(
            ClaimTypes.Role,
            user.Role?.Name ?? "Customer"
        )
    };

        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(
                _configuration["Jwt:Key"]!
            )
        );

        var credentials = new SigningCredentials(
            key,
            SecurityAlgorithms.HmacSha256
        );

        var token = new JwtSecurityToken(
            issuer: _configuration["Jwt:Issuer"],
            audience: _configuration["Jwt:Audience"],
            claims: claims,
            expires: DateTime.UtcNow.AddHours(8),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler()
            .WriteToken(token);
    }
    // ============================
    // PUT: api/Auth/profile
    // Cập nhật thông tin cá nhân
    // ============================
    [Authorize]
    [HttpPut("profile")]

    public async Task<IActionResult> UpdateProfile(UpdateProfileRequest request)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier);

        if (userIdClaim == null ||
            !int.TryParse(userIdClaim.Value, out int userId))
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var user = await _context.Users
            .Include(x => x.Role)
            .FirstOrDefaultAsync(x =>
                x.Id == userId &&
                x.IsActive);

        if (user == null)
        {
            return NotFound(new
            {
                message = "Tài khoản không tồn tại hoặc đã bị khóa."
            });
        }

        // Kiểm tra dữ liệu
        if (string.IsNullOrWhiteSpace(request.FullName))
        {
            return BadRequest(new
            {
                message = "Họ tên không được để trống."
            });
        }

        if (string.IsNullOrWhiteSpace(request.Phone))
        {
            return BadRequest(new
            {
                message = "Số điện thoại không được để trống."
            });
        }

        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new
            {
                message = "Email không được để trống."
            });
        }

        // Kiểm tra phone đã thuộc user khác chưa
        var phoneExists = await _context.Users
            .AnyAsync(x =>
                x.Phone == request.Phone &&
                x.Id != userId);

        if (phoneExists)
        {
            return BadRequest(new
            {
                message = "Số điện thoại đã được sử dụng."
            });
        }

        // Kiểm tra email đã thuộc user khác chưa
        var emailExists = await _context.Users
            .AnyAsync(x =>
                x.Email == request.Email &&
                x.Id != userId);

        if (emailExists)
        {
            return BadRequest(new
            {
                message = "Email đã được sử dụng."
            });
        }

        // Cập nhật
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