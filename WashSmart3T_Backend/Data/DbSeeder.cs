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
        // SEED ADMIN, STAFF, SHIPPER, CUSTOMER
        // Mật khẩu demo chuẩn README: 123456 (hoặc qua biến môi trường INITIAL_SEED_PASSWORD)
        // =========================
        var initialPassword = Environment.GetEnvironmentVariable("INITIAL_SEED_PASSWORD") ?? "123456";
        var passwordHash = BCrypt.Net.BCrypt.HashPassword(initialPassword);

        var adminRole = await context.Roles.FirstAsync(x => x.Name == "Admin");
        var staffRole = await context.Roles.FirstAsync(x => x.Name == "Staff");
        var shipperRole = await context.Roles.FirstAsync(x => x.Name == "Shipper");
        var customerRole = await context.Roles.FirstAsync(x => x.Name == "Customer");

        // 1. Admin
        var admin = await context.Users.FirstOrDefaultAsync(x => x.Phone == "0900000000");
        if (admin == null)
        {
            context.Users.Add(new User
            {
                FullName = "Nguyễn Kiều Như",
                Phone = "0900000000",
                Email = "admin@washsmart.com",
                PasswordHash = passwordHash,
                RoleId = adminRole.Id,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            });
        }
        else
        {
            admin.PasswordHash = passwordHash;
        }

        // 2. Nhân viên tiếp nhận / Lễ tân POS (Staff)
        var staffList = new[]
        {
            new { Phone = "0911000001", Name = "Trần Tuyết Mai", Email = "mai.tran@washsmart.com" },
            new { Phone = "0911000002", Name = "Lê Hoài Nam", Email = "nam.le@washsmart.com" },
            new { Phone = "0911000003", Name = "Đặng Thu Thảo", Email = "thao.dang@washsmart.com" },
            new { Phone = "0965112233", Name = "Đặng Thùy Dương", Email = "duong.dang@washsmart.com" }
        };

        foreach (var s in staffList)
        {
            var u = await context.Users.FirstOrDefaultAsync(x => x.Phone == s.Phone);
            if (u == null)
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
            else
            {
                u.PasswordHash = passwordHash;
            }
        }

        // 3. Nhân viên giao nhận (Shipper)
        var shipper = await context.Users.FirstOrDefaultAsync(x => x.Phone == "0922222222");
        if (shipper == null)
        {
            context.Users.Add(new User
            {
                FullName = "Lê Minh Hoàng",
                Phone = "0922222222",
                Email = "hoang.le@washsmart.com",
                PasswordHash = passwordHash,
                RoleId = shipperRole.Id,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            });
        }
        else
        {
            shipper.PasswordHash = passwordHash;
        }

        // 4. Khách hàng Demo (Customer)
        var customers = new[]
        {
            new { Phone = "0999222111", Name = "Như Nguyễn", Email = "nhu.nguyen@gmail.com" },
            new { Phone = "0944444444", Name = "Hoàng Tuấn Kiên", Email = "kien.hoang@gmail.com" }
        };

        foreach (var c in customers)
        {
            var u = await context.Users.FirstOrDefaultAsync(x => x.Phone == c.Phone);
            if (u == null)
            {
                context.Users.Add(new User
                {
                    FullName = c.Name,
                    Phone = c.Phone,
                    Email = c.Email,
                    PasswordHash = passwordHash,
                    RoleId = customerRole.Id,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                u.PasswordHash = passwordHash;
            }
        }

        await context.SaveChangesAsync();
    }
}
