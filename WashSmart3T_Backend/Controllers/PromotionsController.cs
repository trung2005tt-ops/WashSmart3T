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
    public async Task<IActionResult> GetMyVouchers([FromQuery] string? phone = null)
    {
        var idStr = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        int? userId = int.TryParse(idStr, out var id) ? id : null;

        string tier = "Bronze";
        int points = 0;
        string customerName = "Khách hàng mới";
        string? resolvedPhone = null;

        if (!string.IsNullOrWhiteSpace(phone))
        {
            var (_, _, cleanPhone) = WashSmart.API.Services.SmsService.NormalizePhone(phone);
            var targetPhone = !string.IsNullOrWhiteSpace(cleanPhone) ? cleanPhone : phone.Trim();
            var targetUser = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Phone == targetPhone || u.Phone == phone.Trim());

            resolvedPhone = targetPhone;
            if (targetUser != null)
            {
                tier = string.IsNullOrWhiteSpace(targetUser.MembershipTier) ? "Bronze" : targetUser.MembershipTier;
                points = targetUser.LoyaltyPoints;
                customerName = targetUser.FullName;
                resolvedPhone = targetUser.Phone;
            }
        }
        else if (userId.HasValue)
        {
            var user = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId.Value);
            if (user != null)
            {
                tier = string.IsNullOrWhiteSpace(user.MembershipTier) ? "Bronze" : user.MembershipTier;
                points = user.LoyaltyPoints;
                customerName = user.FullName;
                resolvedPhone = user.Phone;
            }
        }

        // Nạp danh sách các voucher THẬT đang phát hành & còn hiệu lực trong CSDL
        var now = DateTime.UtcNow;
        var dbPromos = await _context.Promotions
            .AsNoTracking()
            .Where(p => p.IsActive && p.StartDate <= now && p.EndDate >= now && p.UsedCount < p.UsageLimit)
            .OrderByDescending(p => p.CreatedAt)
            .ToListAsync();

        var eligibleList = new List<object>();
        var ineligibleList = new List<object>();

        foreach (var p in dbPromos)
        {
            var codeUpper = (p.Code ?? string.Empty).ToUpperInvariant();
            var titleLower = (p.Title ?? string.Empty).ToLowerInvariant();
            var descLower = (p.Description ?? string.Empty).ToLowerInvariant();

            bool isCompensation = descLower.Contains("đền bù") || titleLower.Contains("đền bù");
            bool isPersonal = !string.IsNullOrEmpty(resolvedPhone) && (p.Description.Contains(resolvedPhone) || (!string.IsNullOrEmpty(customerName) && p.Title.Contains(customerName)));

            // Nếu là voucher đền bù cá nhân của khách khác thì không hiển thị
            if (isCompensation && !isPersonal)
            {
                continue;
            }

            // Xác định điều kiện hạng thành viên thực tế
            string requiredTier = "Bronze";
            string tierLabel = isPersonal ? "Tặng Riêng Bạn" : "Mọi hạng thành viên";
            bool isAvailable = true;

            if (codeUpper.Contains("DIAMOND") || titleLower.Contains("kim cương") || titleLower.Contains("diamond") || descLower.Contains("kim cương"))
            {
                requiredTier = "Diamond";
                tierLabel = "Hạng Kim Cương";
                isAvailable = string.Equals(tier, "Diamond", StringComparison.OrdinalIgnoreCase);
            }
            else if (codeUpper == "3TTINHTUOM" || codeUpper == "FREESHIP3T" || codeUpper == "SNEAKERNEW" || codeUpper == "GIATKHOVIP" ||
                     titleLower.Contains("hạng vàng") || titleLower.Contains("vip vàng") || descLower.Contains("hạng vàng"))
            {
                requiredTier = "Gold";
                tierLabel = "Hạng Vàng";
                isAvailable = string.Equals(tier, "Gold", StringComparison.OrdinalIgnoreCase) ||
                              string.Equals(tier, "Diamond", StringComparison.OrdinalIgnoreCase);
            }
            else if (codeUpper == "3TBAC" || titleLower.Contains("hạng bạc") || descLower.Contains("hạng bạc"))
            {
                requiredTier = "Silver";
                tierLabel = "Hạng Bạc";
                isAvailable = string.Equals(tier, "Silver", StringComparison.OrdinalIgnoreCase) ||
                              string.Equals(tier, "Gold", StringComparison.OrdinalIgnoreCase) ||
                              string.Equals(tier, "Diamond", StringComparison.OrdinalIgnoreCase);
            }

            string ineligibleReason = isAvailable
                ? string.Empty
                : $"Yêu cầu {tierLabel} trở lên (Hạng hiện tại: {tier})";

            var item = new
            {
                code = p.Code,
                title = p.Title,
                description = p.Description,
                discountTag = p.DiscountType == "Percentage" ? "GIẢM" : "VOUCHER",
                discountType = p.DiscountType,
                discountValue = p.DiscountType == "Percentage" ? $"{(int)p.DiscountValue}%" : $"{p.DiscountValue / 1000:N0}k",
                discountAmount = p.DiscountValue,
                minOrderAmount = p.MinOrderAmount,
                maxDiscountAmount = p.MaxDiscountAmount,
                requiredTier,
                tierLabel,
                badgeText = isPersonal ? "3T CARE ĐỀN BÙ" : (requiredTier == "Bronze" ? "TOÀN HỆ THỐNG" : tierLabel.ToUpperInvariant()),
                category = "Toàn hệ thống",
                expiry = p.EndDate.ToString("dd/MM/yyyy"),
                isAvailable,
                ineligibleReason
            };

            if (isAvailable)
                eligibleList.Add(item);
            else
                ineligibleList.Add(item);
        }

        var allVouchers = eligibleList.Concat(ineligibleList).ToList();

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
