using Microsoft.EntityFrameworkCore;
using WashSmart.API.Models;

namespace WashSmart.API.Data;

public static class DbSeeder
{
    public static async Task SeedAsync(ApplicationDbContext context)
    {
        // =========================
        // SEED ROLES
        // =========================
        if (!await context.Roles.AnyAsync())
        {
            context.Roles.AddRange(
                new Role
                {
                    Name = "Admin",
                    Description = "Quản trị viên"
                },
                new Role
                {
                    Name = "Staff",
                    Description = "Nhân viên cửa hàng"
                },
                new Role
                {
                    Name = "Shipper",
                    Description = "Nhân viên giao nhận"
                },
                new Role
                {
                    Name = "Customer",
                    Description = "Khách hàng"
                }
            );

            await context.SaveChangesAsync();
        }

        // =========================
        // SEED ADMIN & RECEPTION STAFF
        // Mật khẩu khởi tạo có thể cấu hình an toàn qua biến môi trường INITIAL_SEED_PASSWORD
        // =========================
        var initialPassword = Environment.GetEnvironmentVariable("INITIAL_SEED_PASSWORD") ?? "WashSmart@2026!";
        var passwordHash = BCrypt.Net.BCrypt.HashPassword(initialPassword);

        var adminRole = await context.Roles.FirstAsync(x => x.Name == "Admin");
        var staffRole = await context.Roles.FirstAsync(x => x.Name == "Staff");

        var adminExists = await context.Users.AnyAsync(x => x.Phone == "0900000000");

        if (!adminExists)
        {
            var admin = new User
            {
                FullName = "Nguyễn Kiều Như",
                Phone = "0900000000",
                Email = "admin@washsmart.com",
                PasswordHash = passwordHash,
                RoleId = adminRole.Id,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            context.Users.Add(admin);
        }

        // Thêm các nhân viên tiếp nhận / lễ tân
        var staffList = new[]
        {
            new { Phone = "0911000001", Name = "Trần Tuyết Mai", Email = "mai.tran@washsmart.com" },
            new { Phone = "0911000002", Name = "Lê Hoài Nam", Email = "nam.le@washsmart.com" },
            new { Phone = "0911000003", Name = "Đặng Thu Thảo", Email = "thao.dang@washsmart.com" },
            new { Phone = "0965112233", Name = "Đặng Thùy Dương", Email = "duong.dang@washsmart.com" }
        };

        foreach (var s in staffList)
        {
            if (!await context.Users.AnyAsync(x => x.Phone == s.Phone))
            {
                context.Users.Add(new User
                {
                    FullName = s.Name,
                    Phone = s.Phone,
                    Email = s.Email,
                    PasswordHash = passwordHash,
                    RoleId = staffRole.Id,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                });
            }
        }

        await context.SaveChangesAsync();
    }
}
