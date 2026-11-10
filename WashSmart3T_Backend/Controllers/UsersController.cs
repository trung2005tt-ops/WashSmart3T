using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.Models;
using WashSmart.API.Services;

namespace WashSmart.API.Controllers;

public class CreateUserRequest
{
    public string FullName { get; set; } = string.Empty;
    public string Phone { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string? Password { get; set; }
    public string Role { get; set; } = "Staff"; // Staff, Shipper, Customer, Admin
    public string? Branch { get; set; }
}

public class UpdateUserRequest
{
    public string? FullName { get; set; }
    public string? Phone { get; set; }
    public string? Email { get; set; }
    public string? Role { get; set; }
    public bool? IsActive { get; set; }
    public string? Branch { get; set; }
}

public class ResetPasswordRequest
{
    public string NewPassword { get; set; } = "123456";
}

public class UpgradeTierRequest
{
    public string Tier { get; set; } = "Silver";
}

public class AdjustPointsRequest
{
    public int PointsDelta { get; set; }
}

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin,Staff")]
public class UsersController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public UsersController(ApplicationDbContext context)
    {
        _context = context;
    }

    // ============================================================
    // GET: api/Users
    // Quản lý danh sách nhân sự (Admin, Lễ tân Staff, Shipper)
    // ============================================================
    [HttpGet]
    public async Task<IActionResult> GetAllUsers([FromQuery] string? role, [FromQuery] string? search)
    {
        var query = _context.Users
            .Include(u => u.Role)
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(role) && role.ToLower() != "all")
        {
            query = query.Where(u => u.Role != null && u.Role.Name.ToLower() == role.ToLower());
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(u => u.FullName.ToLower().Contains(s) || u.Phone.Contains(s) || u.Email.ToLower().Contains(s));
        }

        var list = await query
            .OrderBy(u => u.RoleId)
            .ThenBy(u => u.FullName)
            .Select(u => new
            {
                id = u.Id,
                fullName = u.FullName,
                phone = u.Phone,
                email = u.Email,
                roleId = u.RoleId,
                roleName = u.Role != null ? u.Role.Name : "Staff",
                isActive = u.IsActive,
                createdAt = u.CreatedAt,
                avatar = u.FullName.Length >= 2 ? u.FullName.Substring(0, 2).ToUpper() : "NV",
                plainPassword = "••••••"
            })
            .ToListAsync();

        return Ok(list);
    }

    // ============================================================
    // GET: api/Users/customers
    // Quản lý danh sách khách hàng
    // ============================================================
    [HttpGet("customers")]
    public async Task<IActionResult> GetCustomers([FromQuery] string? search)
    {
        var query = _context.Users
            .Include(u => u.Role)
            .Where(u => u.Role != null && u.Role.Name == "Customer")
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var s = search.Trim().ToLower();
            query = query.Where(u => u.FullName.ToLower().Contains(s) || u.Phone.Contains(s) || u.Email.ToLower().Contains(s));
        }

        var customers = await query
            .OrderByDescending(u => u.CreatedAt)
            .Select(u => new
            {
                id = u.Id,
                fullName = u.FullName,
                phone = u.Phone,
                email = u.Email,
                isActive = u.IsActive,
                createdAt = u.CreatedAt,
                loyaltyPoints = u.LoyaltyPoints,
                membershipTier = u.MembershipTier,
                ordersCount = _context.Orders.Count(o => o.CustomerId == u.Id),
                totalSpent = u.TotalSpent > 0 ? u.TotalSpent : _context.Orders.Where(o => o.CustomerId == u.Id && o.Status == OrderStatus.Completed).Sum(o => o.TotalAmount)
            })
            .ToListAsync();

        return Ok(customers);
    }

    // ============================================================
    // POST: api/Users/customers/{id}/upgrade-tier
    // ============================================================
    [HttpPost("customers/{id}/upgrade-tier")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> UpgradeCustomerTier(int id, [FromBody] UpgradeTierRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == id);
        if (user == null) return NotFound(new { message = "Không tìm thấy khách hàng." });

        user.MembershipTier = request.Tier;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Đã nâng hạng thành viên của khách {user.FullName} lên '{user.MembershipTier}' thành công!",
            userId = user.Id,
            membershipTier = user.MembershipTier
        });
    }

    // ============================================================
    // POST: api/Users/customers/{id}/adjust-points
    // ============================================================
    [HttpPost("customers/{id}/adjust-points")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> AdjustCustomerPoints(int id, [FromBody] AdjustPointsRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == id);
        if (user == null) return NotFound(new { message = "Không tìm thấy khách hàng." });

        user.LoyaltyPoints += request.PointsDelta;
        if (user.LoyaltyPoints < 0) user.LoyaltyPoints = 0;
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Đã điều chỉnh điểm tích lũy của {user.FullName}: {(request.PointsDelta >= 0 ? "+" : "")}{request.PointsDelta} điểm. Điểm hiện tại: {user.LoyaltyPoints}.",
            userId = user.Id,
            loyaltyPoints = user.LoyaltyPoints
        });
    }

    // ============================================================
    // GET: api/Users/search?phone=...
    // Tìm kiếm khách hàng hoặc nhân viên qua số điện thoại
    // ============================================================
    [HttpGet("search")]
    public async Task<IActionResult> SearchByPhone([FromQuery] string phone)
    {
        if (string.IsNullOrWhiteSpace(phone))
        {
            return BadRequest(new { message = "Vui lòng nhập số điện thoại cần tìm." });
        }

        var (_, _, cleanPhone) = SmsService.NormalizePhone(phone);
        var user = await _context.Users
            .Include(u => u.Role)
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Phone == cleanPhone || u.Phone == phone);

        if (user == null)
        {
            return NotFound(new { message = "Không tìm thấy người dùng với số điện thoại này." });
        }

        return Ok(new
        {
            id = user.Id,
            fullName = user.FullName,
            phone = user.Phone,
            email = user.Email,
            role = user.Role?.Name ?? "Customer",
            isActive = user.IsActive
        });
    }

    // ============================================================
    // POST: api/Users
    // Admin tạo tài khoản nhân sự (Lễ tân Staff, Shipper...)
    // ============================================================
    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CreateUser([FromBody] CreateUserRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.FullName) || string.IsNullOrWhiteSpace(request.Phone))
        {
            return BadRequest(new { message = "Họ tên và số điện thoại là bắt buộc." });
        }

        var (_, _, cleanPhone) = SmsService.NormalizePhone(request.Phone);

        if (await _context.Users.AnyAsync(u => u.Phone == cleanPhone))
        {
            return BadRequest(new { message = "Số điện thoại này đã được đăng ký tài khoản khác." });
        }

        var targetRoleName = string.IsNullOrWhiteSpace(request.Role) ? "Staff" : request.Role.Trim();
        var role = await _context.Roles.FirstOrDefaultAsync(r => r.Name.ToLower() == targetRoleName.ToLower());
        if (role == null)
        {
            return BadRequest(new { message = $"Vai trò '{targetRoleName}' không hợp lệ trong hệ thống." });
        }

        var rawPassword = string.IsNullOrWhiteSpace(request.Password) ? "123456" : request.Password.Trim();
        var email = !string.IsNullOrWhiteSpace(request.Email)
            ? request.Email.Trim()
            : $"{targetRoleName.ToLower()}-{cleanPhone}@washsmart.local";

        var newUser = new User
        {
            FullName = request.FullName.Trim(),
            Phone = cleanPhone,
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(rawPassword),
            RoleId = role.Id,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(newUser);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Tạo tài khoản {role.Name} thành công!",
            user = new
            {
                id = newUser.Id,
                fullName = newUser.FullName,
                phone = newUser.Phone,
                email = newUser.Email,
                roleName = role.Name,
                plainPassword = rawPassword
            }
        });
    }

    // ============================================================
    // PUT: api/Users/{id}
    // Admin cập nhật thông tin tài khoản nhân sự
    // ============================================================
    [HttpPut("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateUser(int id, [FromBody] UpdateUserRequest request)
    {
        var user = await _context.Users.Include(u => u.Role).FirstOrDefaultAsync(u => u.Id == id);
        if (user == null)
        {
            return NotFound(new { message = "Không tìm thấy người dùng." });
        }

        if (!string.IsNullOrWhiteSpace(request.FullName))
            user.FullName = request.FullName.Trim();

        if (!string.IsNullOrWhiteSpace(request.Phone))
        {
            var (_, _, cleanPhone) = SmsService.NormalizePhone(request.Phone);
            if (cleanPhone != user.Phone && await _context.Users.AnyAsync(u => u.Phone == cleanPhone && u.Id != id))
            {
                return BadRequest(new { message = "Số điện thoại mới đã bị trùng với tài khoản khác." });
            }
            user.Phone = cleanPhone;
        }

        if (!string.IsNullOrWhiteSpace(request.Email))
            user.Email = request.Email.Trim();

        if (request.IsActive.HasValue)
            user.IsActive = request.IsActive.Value;

        if (!string.IsNullOrWhiteSpace(request.Role))
        {
            var role = await _context.Roles.FirstOrDefaultAsync(r => r.Name.ToLower() == request.Role.Trim().ToLower());
            if (role != null)
                user.RoleId = role.Id;
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Cập nhật tài khoản thành công.",
            user = new
            {
                id = user.Id,
                fullName = user.FullName,
                phone = user.Phone,
                email = user.Email,
                roleName = user.Role?.Name,
                isActive = user.IsActive
            }
        });
    }

    // ============================================================
    // DELETE: api/Users/{id}
    // Admin xóa hoặc vô hiệu hóa tài khoản
    // ============================================================
    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == id);
        if (user == null)
        {
            return NotFound(new { message = "Không tìm thấy tài khoản." });
        }

        // Thay vì xóa cứng có thể gây lỗi khóa ngoại với đơn hàng, ta vô hiệu hóa tài khoản
        user.IsActive = false;
        await _context.SaveChangesAsync();

        return Ok(new { message = $"Đã vô hiệu hóa tài khoản {user.FullName} ({user.Phone})." });
    }

    // ============================================================
    // POST: api/Users/{id}/reset-password
    // Admin đặt lại mật khẩu cho tài khoản
    // ============================================================
    [HttpPost("{id}/reset-password")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ResetPassword(int id, [FromBody] ResetPasswordRequest request)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == id);
        if (user == null)
        {
            return NotFound(new { message = "Không tìm thấy người dùng." });
        }

        var newPass = string.IsNullOrWhiteSpace(request.NewPassword) ? "123456" : request.NewPassword.Trim();
        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(newPass);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Đã đặt lại mật khẩu cho {user.FullName} thành '{newPass}' thành công!",
            userId = user.Id
        });
    }

    // ============================================================
    // POST: api/Users/reset-all-passwords
    // ============================================================
    [HttpPost("reset-all-passwords")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ResetAllPasswords([FromBody] ResetPasswordRequest request)
    {
        var newPass = string.IsNullOrWhiteSpace(request.NewPassword) ? "123456" : request.NewPassword.Trim();
        var newHash = BCrypt.Net.BCrypt.HashPassword(newPass);

        var users = await _context.Users.ToListAsync();
        foreach (var u in users)
        {
            u.PasswordHash = newHash;
        }

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Đã đồng bộ đặt lại mật khẩu '{newPass}' cho toàn bộ {users.Count} tài khoản!",
            totalAccounts = users.Count
        });
    }
}
