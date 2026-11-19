using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.Models;

namespace WashSmart.API.Controllers;

public class CreatePromotionRequest
{
    public string Code { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string DiscountType { get; set; } = "Percentage"; // "Percentage" or "FixedAmount"
    public decimal DiscountValue { get; set; }
    public decimal MinOrderAmount { get; set; } = 0;
    public decimal? MaxDiscountAmount { get; set; }
    public DateTime? StartDate { get; set; }
    public DateTime? EndDate { get; set; }
    public int UsageLimit { get; set; } = 1000;
}

public class VerifyPromotionRequest
{
    public string Code { get; set; } = string.Empty;
    public decimal OrderAmount { get; set; } = 0;
}

[ApiController]
[Route("api/[controller]")]
public class PromotionsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public PromotionsController(ApplicationDbContext context)
    {
        _context = context;
    }

    // ============================================================
    // GET: api/Promotions/my-vouchers
    // Danh sách các ưu đãi & voucher theo cấp bậc thành viên thực tế
    // ============================================================
    [HttpGet("my-vouchers")]
    [AllowAnonymous]
    public async Task<IActionResult> GetMyVouchers()
    {
        var idStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        int? userId = int.TryParse(idStr, out var id) ? id : null;

        string tier = "Gold"; // Mặc định Gold nếu demo chưa đăng nhập
        int points = 1450;
        string customerName = "Chị Kiều Như";

        if (userId.HasValue)
        {
            var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId.Value);
            if (user != null)
            {
                tier = string.IsNullOrWhiteSpace(user.MembershipTier) ? "Bronze" : user.MembershipTier;
                points = user.LoyaltyPoints;
                customerName = user.FullName;
            }
        }

        var allVouchers = new List<object>
        {
            new {
                code = "3TTINHTUOM",
                title = "Giặt Sấy Tinh Tươm Lấy Ngay",
                description = "Giảm ngay 20.000đ cho đơn dịch vụ Giặt sấy gấp thơm tho chỉ từ 120.000đ.",
                discountTag = "GIẢM",
                discountValue = "20k",
                discountAmount = 20000,
                minOrderAmount = 120000,
                requiredTier = "Gold",
                tierLabel = "Hạng Vàng",
                badgeText = "3T CARE",
                category = "Giặt Sấy & Ủi",
                expiry = "30/10/2026",
                isAvailable = tier == "Gold" || tier == "Diamond"
            },
            new {
                code = "FREESHIP3T",
                title = "Freeship Gom & Giao 2 Chiều",
                description = "Miễn phí giao nhận tận sảnh chung cư hoặc nhà riêng (tối đa 30.000đ).",
                discountTag = "SHIP",
                discountValue = "0 Đ",
                discountAmount = 30000,
                minOrderAmount = 0,
                requiredTier = "Gold",
                tierLabel = "VIP Vàng",
                badgeText = "VIP VÀNG",
                category = "Freeship Gom & Giao",
                expiry = "05/11/2026",
                isAvailable = tier == "Gold" || tier == "Diamond"
            },
            new {
                code = "SNEAKERNEW",
                title = "Vệ Sinh Sneaker & Khử Trùng UV",
                description = "Giặt hấp giày thể thao, phủ nano chống bám bẩn kèm khử khuẩn sâu. Đơn từ 150k.",
                discountTag = "GIẢM",
                discountValue = "30k",
                discountAmount = 30000,
                minOrderAmount = 150000,
                requiredTier = "Gold",
                tierLabel = "Hạng Vàng",
                badgeText = "UV CARE",
                category = "Giày & Đồ hiệu",
                expiry = "15/11/2026",
                isAvailable = tier == "Gold" || tier == "Diamond"
            },
            new {
                code = "GIATKHOVIP",
                title = "Giặt Khô Hấp Vest & Đầm Lụa",
                description = "Công nghệ giặt hydrocacbon dịu nhẹ giữ form áo vest, suit và lụa tơ tằm.",
                discountTag = "GIẢM",
                discountValue = "15%",
                discountAmount = 50000,
                minOrderAmount = 150000,
                requiredTier = "Gold",
                tierLabel = "Hạng Vàng",
                badgeText = "PREMIUM",
                category = "Giày & Đồ hiệu",
                expiry = "20/11/2026",
                isAvailable = tier == "Gold" || tier == "Diamond"
            },
            new {
                code = "DIAMOND-VIP",
                title = "Đặc Quyền Thượng Hạng Diamond",
                description = "Giảm trực tiếp 50.000đ trên tổng hóa đơn và ưu tiên xử lý trong lồng giặt VIP.",
                discountTag = "GIẢM",
                discountValue = "50k",
                discountAmount = 50000,
                minOrderAmount = 200000,
                requiredTier = "Diamond",
                tierLabel = "Kim Cương",
                badgeText = "DIAMOND",
                category = "Đặc quyền Đổi Xu",
                expiry = "31/12/2026",
                isAvailable = tier == "Diamond"
            },
            new {
                code = "FREESHIPVIP",
                title = "Freeship Không Giới Hạn Kim Cương",
                description = "Miễn phí gom và giao tận cửa cho tất cả đơn hàng, không phụ thuộc khoảng cách.",
                discountTag = "SHIP",
                discountValue = "0 Đ",
                discountAmount = 50000,
                minOrderAmount = 0,
                requiredTier = "Diamond",
                tierLabel = "Kim Cương",
                badgeText = "DIAMOND",
                category = "Freeship Gom & Giao",
                expiry = "31/12/2026",
                isAvailable = tier == "Diamond"
            },
            new {
                code = "3TBAC",
                title = "Ưu Đãi Thành Viên Hạng Bạc",
                description = "Giảm ngay 15.000đ cho đơn giặt sấy từ 100.000đ.",
                discountTag = "GIẢM",
                discountValue = "15k",
                discountAmount = 15000,
                minOrderAmount = 100000,
                requiredTier = "Silver",
                tierLabel = "Hạng Bạc",
                badgeText = "SILVER",
                category = "Giặt Sấy & Ủi",
                expiry = "30/11/2026",
                isAvailable = tier == "Silver" || tier == "Gold" || tier == "Diamond"
            },
            new {
                code = "CHAOBANMOI",
                title = "Chào Bạn Mới 3T",
                description = "Giảm 20% (tối đa 50.000đ) cho khách hàng mới trải nghiệm dịch vụ.",
                discountTag = "GIẢM",
                discountValue = "20%",
                discountAmount = 50000,
                minOrderAmount = 50000,
                requiredTier = "Bronze",
                tierLabel = "Thành viên",
                badgeText = "WELCOME",
                category = "Giặt Sấy & Ủi",
                expiry = "31/12/2026",
                isAvailable = true
            }
        };

        return Ok(new
        {
            customerName,
            membershipTier = tier,
            loyaltyPoints = points,
            vouchers = allVouchers
        });
    }

    // ============================================================
    // GET: api/Promotions
    // Danh sách các chương trình khuyến mãi & Voucher
    // ============================================================
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetAll([FromQuery] string? category)
    {
        var now = DateTime.UtcNow;
        var query = _context.Promotions.AsNoTracking().AsQueryable();

        if (string.Equals(category, "active", StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(p => p.IsActive && p.StartDate <= now && p.EndDate >= now && p.UsedCount < p.UsageLimit);
        }

        var list = await query
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => new
            {
                p.Id,
                p.Code,
                p.Title,
                p.Description,
                p.DiscountType,
                p.DiscountValue,
                p.MinOrderAmount,
                p.MaxDiscountAmount,
                p.StartDate,
                p.EndDate,
                p.UsageLimit,
                p.UsedCount,
                p.IsActive,
                p.CreatedAt
            })
            .ToListAsync();

        return Ok(list);
    }

    // ============================================================
    // GET: api/Promotions/{id}
    // ============================================================
    [HttpGet("{id}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetById(int id)
    {
        var promo = await _context.Promotions.AsNoTracking().FirstOrDefaultAsync(p => p.Id == id);
        if (promo == null) return NotFound(new { message = "Không tìm thấy mã ưu đãi." });
        return Ok(promo);
    }

    // ============================================================
    // POST: api/Promotions/verify
    // Xác thực mã giảm giá & tính toán số tiền được giảm
    // ============================================================
    [HttpPost("verify")]
    [AllowAnonymous]
    public async Task<IActionResult> VerifyPromotion([FromBody] VerifyPromotionRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Code))
        {
            return BadRequest(new { valid = false, message = "Vui lòng nhập mã ưu đãi." });
        }

        var code = request.Code.Trim().ToUpperInvariant();
        var now = DateTime.UtcNow;

        var promo = await _context.Promotions.FirstOrDefaultAsync(p => p.Code == code);
        if (promo == null || !promo.IsActive)
        {
            return BadRequest(new { valid = false, message = "Mã ưu đãi không tồn tại hoặc đã hết hiệu lực." });
        }

        if (promo.StartDate > now)
        {
            return BadRequest(new { valid = false, message = "Chương trình ưu đãi này chưa bắt đầu." });
        }

        if (promo.EndDate < now)
        {
            return BadRequest(new { valid = false, message = "Mã ưu đãi đã hết hạn sử dụng." });
        }

        if (promo.UsedCount >= promo.UsageLimit)
        {
            return BadRequest(new { valid = false, message = "Mã ưu đãi đã hết số lượt sử dụng." });
        }

        if (request.OrderAmount < promo.MinOrderAmount)
        {
            return BadRequest(new
            {
                valid = false,
                message = $"Đơn hàng tối thiểu {promo.MinOrderAmount:N0}đ để áp dụng mã này (Đơn hiện tại: {request.OrderAmount:N0}đ)."
            });
        }

        decimal discount = 0;
        if (promo.DiscountType == "Percentage")
        {
            discount = Math.Round(request.OrderAmount * (promo.DiscountValue / 100m));
            if (promo.MaxDiscountAmount.HasValue && discount > promo.MaxDiscountAmount.Value)
            {
                discount = promo.MaxDiscountAmount.Value;
            }
        }
        else
        {
            discount = promo.DiscountValue;
            if (discount > request.OrderAmount)
            {
                discount = request.OrderAmount;
            }
        }

        return Ok(new
        {
            valid = true,
            code = promo.Code,
            title = promo.Title,
            discountAmount = discount,
            message = $"Áp dụng mã {promo.Code} thành công! Bạn được giảm {discount:N0}đ."
        });
    }

    // ============================================================
    // POST: api/Promotions
    // Admin tạo mới mã Voucher
    // ============================================================
    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create([FromBody] CreatePromotionRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Code) || string.IsNullOrWhiteSpace(request.Title))
        {
            return BadRequest(new { message = "Mã ưu đãi và tiêu đề là bắt buộc." });
        }

        var cleanCode = request.Code.Trim().ToUpperInvariant();
        if (await _context.Promotions.AnyAsync(p => p.Code == cleanCode))
        {
            return BadRequest(new { message = $"Mã ưu đãi '{cleanCode}' đã tồn tại trong hệ thống." });
        }

        var promo = new Promotion
        {
            Code = cleanCode,
            Title = request.Title.Trim(),
            Description = request.Description?.Trim() ?? string.Empty,
            DiscountType = request.DiscountType == "FixedAmount" ? "FixedAmount" : "Percentage",
            DiscountValue = request.DiscountValue > 0 ? request.DiscountValue : 10,
            MinOrderAmount = request.MinOrderAmount >= 0 ? request.MinOrderAmount : 0,
            MaxDiscountAmount = request.MaxDiscountAmount,
            StartDate = request.StartDate ?? DateTime.UtcNow,
            EndDate = request.EndDate ?? DateTime.UtcNow.AddMonths(3),
            UsageLimit = request.UsageLimit > 0 ? request.UsageLimit : 500,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _context.Promotions.Add(promo);
        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = $"Tạo mã khuyến mãi {promo.Code} thành công!",
            promotion = promo
        });
    }

    // ============================================================
    // DELETE: api/Promotions/{id}
    // ============================================================
    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var promo = await _context.Promotions.FirstOrDefaultAsync(p => p.Id == id);
        if (promo == null) return NotFound(new { message = "Không tìm thấy mã ưu đãi." });

        promo.IsActive = false;
        await _context.SaveChangesAsync();

        return Ok(new { message = $"Đã ngưng áp dụng mã {promo.Code}." });
    }
}
