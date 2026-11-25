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
        var admin = await context.Users.FirstOrDefaultAsync(x => x.Email == "admin@washsmart.com" || x.RoleId == adminRole.Id);
        if (admin == null)
        {
            context.Users.Add(new User
            {
                FullName = "Nguyễn Kiều Như",
                Phone = "0908123456",
                Email = "admin@washsmart.com",
                PasswordHash = passwordHash,
                PlainPassword = initialPassword,
                RoleId = adminRole.Id,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            });
        }
        else
        {
            admin.FullName = "Nguyễn Kiều Như";
            admin.Phone = "0908123456";
            admin.PasswordHash = passwordHash;
            admin.PlainPassword ??= initialPassword;
        }

        // 2. Nhân viên tiếp nhận / Lễ tân POS (Staff)
        var staffList = new[]
        {
            new { Phone = "0911223301", Name = "Trần Tuyết Mai", Email = "mai.tran@washsmart.com" },
            new { Phone = "0911223302", Name = "Lê Hoài Nam", Email = "nam.le@washsmart.com" },
            new { Phone = "0911223303", Name = "Đặng Thu Thảo", Email = "thao.dang@washsmart.com" },
            new { Phone = "0965112233", Name = "Đặng Thùy Dương", Email = "duong.dang@washsmart.com" }
        };

        foreach (var s in staffList)
        {
            var u = await context.Users.FirstOrDefaultAsync(x => x.Phone == s.Phone || x.Email == s.Email);
            if (u == null)
            {
                context.Users.Add(new User
                {
                    FullName = s.Name,
                    Phone = s.Phone,
                    Email = s.Email,
                    PasswordHash = passwordHash,
                    PlainPassword = initialPassword,
                    RoleId = staffRole.Id,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                u.FullName = s.Name;
                u.Phone = s.Phone;
                u.PasswordHash = passwordHash;
                u.PlainPassword ??= initialPassword;
            }
        }

        // 3. Nhân viên giao nhận (Shipper)
        var shipperList = new[]
        {
            new { Phone = "0818605505", Name = "Nguyễn Thành Trung", Email = "tt@gmail.com" }
        };

        foreach (var sh in shipperList)
        {
            var u = await context.Users.FirstOrDefaultAsync(x => x.Phone == sh.Phone || x.Email == sh.Email);
            if (u == null)
            {
                context.Users.Add(new User
                {
                    FullName = sh.Name,
                    Phone = sh.Phone,
                    Email = sh.Email,
                    PasswordHash = passwordHash,
                    PlainPassword = initialPassword,
                    RoleId = shipperRole.Id,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                u.FullName = sh.Name;
                u.Phone = sh.Phone;
                u.PasswordHash = passwordHash;
                u.PlainPassword ??= initialPassword;
            }
        }

        // 4. Khách hàng Demo (Customer)
        var customers = new[]
        {
            new { Phone = "0912306271", Name = "Nguyễn Bích Phương", Email = "phuong.nguyen@gmail.com" },
            new { Phone = "0977889911", Name = "Võ Văn Nam", Email = "nam.vo@gmail.com" }
        };

        foreach (var c in customers)
        {
            var u = await context.Users.FirstOrDefaultAsync(x => x.Phone == c.Phone || x.Email == c.Email);
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
                    LoyaltyPoints = 120,
                    MembershipTier = "Silver",
                    TotalSpent = 480000,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                u.FullName = c.Name;
                u.Phone = c.Phone;
                u.PasswordHash = passwordHash;
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
        var tierPromotions = new[]
        {
            new Promotion
            {
                Code = "3TCHAOBAN",
                Title = "Giảm 20.000 đ đơn đầu tiên",
                Description = "Áp dụng cho khách hàng mới của WashSmart 3T.",
                DiscountType = "FixedAmount",
                DiscountValue = 20000,
                MinOrderAmount = 0,
                MaxDiscountAmount = 20000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 2000,
                UsedCount = 0,
                IsActive = true
            },
            new Promotion
            {
                Code = "WASH3T30K",
                Title = "Giảm 30.000 đ đơn từ 100k",
                Description = "Ưu đãi giặt sấy nguyên mẻ tinh tươm cho đơn từ 100.000đ.",
                DiscountType = "FixedAmount",
                DiscountValue = 30000,
                MinOrderAmount = 100000,
                MaxDiscountAmount = 30000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 2000,
                UsedCount = 0,
                IsActive = true
            },
            new Promotion
            {
                Code = "3TTINHTUOM",
                Title = "Giặt Sấy Tinh Tươm Lấy Ngay (Hạng Vàng)",
                Description = "Giảm ngay 20.000đ cho đơn dịch vụ Giặt sấy gấp thơm tho chỉ từ 120.000đ.",
                DiscountType = "FixedAmount",
                DiscountValue = 20000,
                MinOrderAmount = 120000,
                MaxDiscountAmount = 20000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 2000,
                UsedCount = 38,
                IsActive = true
            },
            new Promotion
            {
                Code = "FREESHIP3T",
                Title = "Freeship Gom & Giao 2 Chiều (VIP Vàng)",
                Description = "Miễn phí giao nhận tận sảnh chung cư hoặc nhà riêng (tối đa 30.000đ).",
                DiscountType = "FixedAmount",
                DiscountValue = 30000,
                MinOrderAmount = 0,
                MaxDiscountAmount = 30000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 2000,
                UsedCount = 45,
                IsActive = true
            },
            new Promotion
            {
                Code = "SNEAKERNEW",
                Title = "Vệ Sinh Sneaker & Khử Trùng UV (Hạng Vàng)",
                Description = "Giặt hấp giày thể thao, phủ nano chống bám bẩn kèm khử khuẩn sâu. Đơn từ 150k.",
                DiscountType = "FixedAmount",
                DiscountValue = 30000,
                MinOrderAmount = 150000,
                MaxDiscountAmount = 30000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 1500,
                UsedCount = 20,
                IsActive = true
            },
            new Promotion
            {
                Code = "GIATKHOVIP",
                Title = "Giặt Khô Hấp Vest & Đầm Lụa (Hạng Vàng)",
                Description = "Công nghệ giặt hydrocacbon dịu nhẹ giữ form áo vest, suit và lụa tơ tằm. Tối đa 50k.",
                DiscountType = "Percentage",
                DiscountValue = 15,
                MinOrderAmount = 150000,
                MaxDiscountAmount = 50000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 1000,
                UsedCount = 12,
                IsActive = true
            },
            new Promotion
            {
                Code = "DIAMOND-VIP",
                Title = "Đặc Quyền Thượng Hạng Diamond",
                Description = "Giảm trực tiếp 50.000đ trên tổng hóa đơn và ưu tiên xử lý trong lồng giặt VIP.",
                DiscountType = "FixedAmount",
                DiscountValue = 50000,
                MinOrderAmount = 200000,
                MaxDiscountAmount = 50000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 1000,
                UsedCount = 9,
                IsActive = true
            },
            new Promotion
            {
                Code = "FREESHIPVIP",
                Title = "Freeship Không Giới Hạn Kim Cương",
                Description = "Miễn phí gom và giao tận cửa cho tất cả đơn hàng, không phụ thuộc khoảng cách.",
                DiscountType = "FixedAmount",
                DiscountValue = 50000,
                MinOrderAmount = 0,
                MaxDiscountAmount = 50000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 1000,
                UsedCount = 14,
                IsActive = true
            },
            new Promotion
            {
                Code = "3TBAC",
                Title = "Ưu Đãi Thành Viên Hạng Bạc",
                Description = "Giảm ngay 15.000đ cho đơn giặt sấy từ 100.000đ.",
                DiscountType = "FixedAmount",
                DiscountValue = 15000,
                MinOrderAmount = 100000,
                MaxDiscountAmount = 15000,
                StartDate = DateTime.UtcNow.AddDays(-30),
                EndDate = DateTime.UtcNow.AddMonths(12),
                UsageLimit = 1000,
                UsedCount = 22,
                IsActive = true
            },
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
        };

        foreach (var p in tierPromotions)
        {
            var existing = await context.Promotions.FirstOrDefaultAsync(x => x.Code == p.Code);
            if (existing == null)
            {
                context.Promotions.Add(p);
            }
        }

        // =========================
        // SEED COMPLAINTS (BẢO HIỂM 3T CARE TRONG CSDL)
        // =========================
        if (!await context.Complaints.AnyAsync())
        {
            var customer1 = await context.Users.FirstOrDefaultAsync(u => u.Phone == "0912306271");
            var customer2 = await context.Users.FirstOrDefaultAsync(u => u.Phone == "0977889911");
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
                    ShipperName = "Nguyễn Thành Trung (0818605505)",
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
                    ShipperName = "Nguyễn Thành Trung (0818605505)",
                    CreatedAt = DateTime.UtcNow.AddDays(-1)
                }
            );
        }

        // =========================
        // SEED CARE OPTIONS (GÓI CHĂM SÓC NÂNG CAO)
        // =========================
        try
        {
            await context.Database.ExecuteSqlRawAsync(@"
                IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='CareOptions' and xtype='U')
                CREATE TABLE CareOptions (
                    Id INT IDENTITY(1,1) PRIMARY KEY,
                    Name NVARCHAR(255) NOT NULL,
                    Description NVARCHAR(500) NULL,
                    Price DECIMAL(18,2) NOT NULL DEFAULT 0,
                    BadgeText NVARCHAR(50) NULL,
                    IsActive BIT NOT NULL DEFAULT 1,
                    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
                    UpdatedAt DATETIME2 NULL
                );
            ");

            if (!await context.CareOptions.AnyAsync())
            {
                context.CareOptions.AddRange(
                    new CareOption
                    {
                        Name = "Nước xả vải Comfort Tinh Tươm",
                        Description = "Hương hoa dịu nhẹ lưu hương 7 ngày",
                        Price = 10000,
                        BadgeText = "Lưu hương 7 ngày",
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    },
                    new CareOption
                    {
                        Name = "Túi giặt bảo vệ vải sợi cao cấp",
                        Description = "Chống bai dão, sờn vải sợi mỏng và đồ cao cấp",
                        Price = 5000,
                        BadgeText = "Chống dão",
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    },
                    new CareOption
                    {
                        Name = "Khử khuẩn UV & Kháng nấm mốc",
                        Description = "Công nghệ khử trùng tia cực tím diệt 99.9% vi khuẩn",
                        Price = 15000,
                        BadgeText = "Khử khuẩn 99.9%",
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    },
                    new CareOption
                    {
                        Name = "Ủi hơi nước chống nhăn form",
                        Description = "Ủi đứng áp suất nhiệt, giữ phom áo sơ mi & quần âu",
                        Price = 20000,
                        BadgeText = "Phẳng phiu",
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    },
                    new CareOption
                    {
                        Name = "Hương Hoa Ban Mai 3T",
                        Description = "Chiết xuất tinh dầu thảo mộc dịu nhẹ, an toàn da nhạy cảm",
                        Price = 0,
                        BadgeText = "72 Giờ",
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    },
                    new CareOption
                    {
                        Name = "Túi vải niêm phong chống nước 3T",
                        Description = "Khóa seal an toàn chống ẩm bụi, mở seal tại nhà khách",
                        Price = 0,
                        BadgeText = "#SEAL-3T",
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    }
                );
                await context.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[DbSeeder] CareOptions seed warning: {ex.Message}");
        }

        await context.SaveChangesAsync();
    }
}
