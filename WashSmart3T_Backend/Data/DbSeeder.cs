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
                    LoyaltyPoints = c.Phone == "0999222111" ? 350 : 120,
                    MembershipTier = c.Phone == "0999222111" ? "Gold" : "Silver",
                    TotalSpent = c.Phone == "0999222111" ? 1250000 : 480000,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                u.PasswordHash = passwordHash;
                if (u.LoyaltyPoints == 0) u.LoyaltyPoints = c.Phone == "0999222111" ? 350 : 120;
                if (u.MembershipTier == "Bronze") u.MembershipTier = c.Phone == "0999222111" ? "Gold" : "Silver";
                if (u.TotalSpent == 0) u.TotalSpent = c.Phone == "0999222111" ? 1250000 : 480000;
            }
        }

        // =========================
        // SEED STORE CONFIG
        // Lưu trữ trực tiếp trong CSDL SQL Server (Singleton Id=1)
        // =========================
        if (!await context.StoreConfigs.AnyAsync())
        {
            context.StoreConfigs.Add(new StoreConfig
            {
                StoreName = "Cửa hàng WashSmart 3T - Trụ sở chính",
                Address = "140 Lê Trọng Tấn, phường Tây Thạnh, TP. Hồ Chí Minh",
                Latitude = 10.8070,
                Longitude = 106.6287,
                Hotline = "0900000000",
                OpenHours = "07:00 - 22:00",
                BaseShippingFee = 20000,
                Tier2ShippingFee = 30000,
                Tier3ShippingFee = 45000,
                Tier1MaxKm = 2.0,
                Tier2MaxKm = 5.0,
                Tier3MaxKm = 10.0,
                ExpressExtraFee = 25000,
                AddonComfortFee = 10000,
                AddonBagFee = 5000,
                FreeShipMinAmount = 250000,
                BankName = "MBBank (Ngân hàng Quân Đội)",
                BankBin = "970422",
                BankAccountNo = "0818606505",
                BankAccountHolder = "TRAN DIEP MINH TRUNG",
                SmsApiKey = "DEV_DEMO_KEY",
                SmsApiSecret = "DEV_DEMO_SECRET",
                SmsBrandName = "WASHSMART3T",
                SmsOtpTemplate = "Ma OTP xac thuc WashSmart 3T cua ban la {OTP}. Hieu luc trong 5 phut.",
                UpdatedAt = DateTime.UtcNow
            });
        }

        // =========================
        // SEED PROMOTIONS / VOUCHERS
        // =========================
        if (!await context.Promotions.AnyAsync())
        {
            context.Promotions.AddRange(
                new Promotion
                {
                    Code = "CHAOBANMOI",
                    Title = "Giảm 20% cho đơn hàng đầu tiên",
                    Description = "Áp dụng cho khách hàng mới đặt giặt sấy qua ứng dụng",
                    DiscountType = "Percentage",
                    DiscountValue = 20,
                    MinOrderAmount = 50000,
                    MaxDiscountAmount = 50000,
                    StartDate = DateTime.UtcNow.AddDays(-7),
                    EndDate = DateTime.UtcNow.AddMonths(6),
                    UsageLimit = 500,
                    UsedCount = 42,
                    IsActive = true
                },
                new Promotion
                {
                    Code = "FREESHIP50K",
                    Title = "Miễn phí vận chuyển 2 chiều",
                    Description = "Freeship tối đa 30k cho đơn hàng từ 200.000đ",
                    DiscountType = "FixedAmount",
                    DiscountValue = 20000,
                    MinOrderAmount = 200000,
                    MaxDiscountAmount = 20000,
                    StartDate = DateTime.UtcNow.AddDays(-3),
                    EndDate = DateTime.UtcNow.AddMonths(3),
                    UsageLimit = 1000,
                    UsedCount = 85,
                    IsActive = true
                },
                new Promotion
                {
                    Code = "GIAT3T15",
                    Title = "Ưu đãi khách hàng thân thiết 15K",
                    Description = "Giảm trực tiếp 15.000đ cho đơn giặt sấy từ 100.000đ",
                    DiscountType = "FixedAmount",
                    DiscountValue = 15000,
                    MinOrderAmount = 100000,
                    MaxDiscountAmount = 15000,
                    StartDate = DateTime.UtcNow.AddDays(-10),
                    EndDate = DateTime.UtcNow.AddMonths(2),
                    UsageLimit = 300,
                    UsedCount = 18,
                    IsActive = true
                }
            );
        }

        // =========================
        // SEED COMPLAINTS (BẢO HIỂM 3T CARE TRONG CSDL)
        // =========================
        if (!await context.Complaints.AnyAsync())
        {
            var customer1 = await context.Users.FirstOrDefaultAsync(u => u.Phone == "0999222111");
            var customer2 = await context.Users.FirstOrDefaultAsync(u => u.Phone == "0944444444");
            var latestOrder = await context.Orders.OrderByDescending(o => o.Id).FirstOrDefaultAsync();
            var prevOrder = await context.Orders.Where(o => o.Id != (latestOrder != null ? latestOrder.Id : 0)).OrderByDescending(o => o.Id).FirstOrDefaultAsync();

            context.Complaints.AddRange(
                new Complaint
                {
                    TicketCode = "KN-20261104-001",
                    CustomerId = customer1?.Id,
                    OrderId = latestOrder?.Id,
                    OrderCode = latestOrder != null ? $"#WS3T-{latestOrder.Id:D4}" : "#WS3T-0019",
                    IncidentType = "Bung chỉ mép áo sơ mi",
                    Severity = "Low",
                    ItemDescription = "Áo sơ mi trắng lụa công sở bị sờn mép chỉ cổ tay sau khi giặt sấy.",
                    CustomerNote = "Nhờ xưởng giặt hỗ trợ may dằn chỉ lại hoặc bồi thường phí sửa áo.",
                    RequestedRefund = 50000,
                    Status = "Pending",
                    SealCode = "WS-SEAL-0019",
                    SealStatus = "Intact",
                    DrumInfo = "Lồng giặt sấy thông minh LG Turbo #02",
                    ShipperName = "Lê Minh Hoàng (0922222222)",
                    CreatedAt = DateTime.UtcNow.AddMinutes(-45)
                },
                new Complaint
                {
                    TicketCode = "KN-20261103-002",
                    CustomerId = customer2?.Id,
                    OrderId = prevOrder?.Id,
                    OrderCode = prevOrder != null ? $"#WS3T-{prevOrder.Id:D4}" : "#WS3T-0018",
                    IncidentType = "Lem màu khăn tắm",
                    Severity = "Medium",
                    ItemDescription = "Khăn tắm cotton màu trắng bị phai màu xanh nhạt từ đồ giặt chung.",
                    CustomerNote = "Đã giặt hấp xử lý màu lại, khách hàng hài lòng.",
                    RequestedRefund = 120000,
                    ApprovedAmount = 120000,
                    Status = "Completed",
                    Resolution = "Approved",
                    StaffNote = "Đã chi trả đền bù 100% giá trị khăn tắm qua ví WashPoints và tặng mã freeship.",
                    ResolvedAt = DateTime.UtcNow.AddHours(-18),
                    ResolvedBy = "Nguyễn Kiều Như",
                    SealCode = "WS-SEAL-0018",
                    SealStatus = "Inspected",
                    DrumInfo = "Lồng hấp chuyên dụng Electrolux #01",
                    ShipperName = "Lê Minh Hoàng (0922222222)",
                    CreatedAt = DateTime.UtcNow.AddDays(-1)
                }
            );
        }

        await context.SaveChangesAsync();
    }
}
