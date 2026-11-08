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
        // SEED ADMIN
        // =========================

        var adminRole = await context.Roles
            .FirstAsync(x => x.Name == "Admin");

        var adminExists = await context.Users
            .AnyAsync(x => x.Phone == "0900000000");

        if (!adminExists)
        {
            var admin = new User
            {
                FullName = "System Administrator",
                Phone = "0900000000",
                Email = "admin@washsmart.com",

                PasswordHash = BCrypt.Net.BCrypt.HashPassword(
                    "Admin@123456"
                ),

                RoleId = adminRole.Id,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            context.Users.Add(admin);

            await context.SaveChangesAsync();
        }
    }
}