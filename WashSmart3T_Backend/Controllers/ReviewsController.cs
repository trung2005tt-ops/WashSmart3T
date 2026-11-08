using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;
using WashSmart.API.DTOs;
using WashSmart.API.Models;

namespace WashSmart.API.Controllers;

// ============================================================
// ĐÁNH GIÁ / PHẢN HỒI ĐƠN HÀNG
// ============================================================

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ReviewsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public ReviewsController(ApplicationDbContext context)
    {
        _context = context;
    }

    private int? GetCurrentUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier);

        return claim != null &&
            int.TryParse(claim.Value, out var userId)
            ? userId
            : null;
    }

    // ============================================================
    // POST: api/Reviews/order/{orderId}
    // Khách tạo đánh giá cho đơn hàng đã hoàn tất
    // ============================================================

    [HttpPost("order/{orderId}")]
    public async Task<IActionResult> CreateReview(
        int orderId,
        CreateReviewRequest request)
    {
        var userId = GetCurrentUserId();

        if (userId == null)
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var order = await _context.Orders
            .FirstOrDefaultAsync(x =>
                x.Id == orderId &&
                x.CustomerId == userId);

        if (order == null)
        {
            return NotFound(new
            {
                message = "Không tìm thấy đơn hàng."
            });
        }

        // Chỉ đánh giá được đơn đã hoàn tất
        if (order.Status != OrderStatus.Completed)
        {
            return BadRequest(new
            {
                message =
                    "Chỉ có thể đánh giá đơn hàng đã hoàn tất (Completed)."
            });
        }

        // Mỗi đơn chỉ một đánh giá
        var existing = await _context.Reviews
            .AnyAsync(x => x.OrderId == orderId);

        if (existing)
        {
            return BadRequest(new
            {
                message = "Đơn hàng này đã được đánh giá."
            });
        }

        var review = new Review
        {
            OrderId = orderId,
            CustomerId = userId.Value,
            Rating = request.Rating,
            Comment = request.Comment ?? string.Empty,
            CreatedAt = DateTime.UtcNow
        };

        _context.Reviews.Add(review);

        await _context.SaveChangesAsync();

        return Ok(new
        {
            message = "Tạo đánh giá thành công.",
            reviewId = review.Id,
            orderId = review.OrderId,
            rating = review.Rating,
            comment = review.Comment
        });
    }

    // ============================================================
    // GET: api/Reviews/order/{orderId}
    // Xem đánh giá của đơn hàng
    // ============================================================

    [HttpGet("order/{orderId}")]
    public async Task<IActionResult> GetReviewByOrder(int orderId)
    {
        var review = await _context.Reviews
            .FirstOrDefaultAsync(x => x.OrderId == orderId);

        if (review == null)
        {
            return NotFound(new
            {
                message = "Đơn hàng chưa có đánh giá."
            });
        }

        return Ok(new
        {
            review.Id,
            review.OrderId,
            review.CustomerId,
            review.Rating,
            review.Comment,
            review.CreatedAt
        });
    }

    // ============================================================
    // GET: api/Reviews/my-reviews
    // Khách xem các đánh giá của mình
    // ============================================================

    [HttpGet("my-reviews")]
    public async Task<IActionResult> GetMyReviews()
    {
        var userId = GetCurrentUserId();

        if (userId == null)
        {
            return Unauthorized(new
            {
                message = "Không xác định được người dùng."
            });
        }

        var reviews = await _context.Reviews
            .Where(x => x.CustomerId == userId)
            .OrderByDescending(x => x.CreatedAt)
            .Select(x => new
            {
                x.Id,
                x.OrderId,
                x.Rating,
                x.Comment,
                x.CreatedAt
            })
            .ToListAsync();

        return Ok(reviews);
    }

    // ============================================================
    // GET: api/Reviews/stats
    // Admin/staff xem thống kê đánh giá tổng quan
    // ============================================================

    [HttpGet("stats")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> GetReviewStats()
    {
        var stats = await _context.Reviews
            .GroupBy(x => 1)
            .Select(g => new
            {
                totalReviews = g.Count(),
                averageRating = g.Average(x => x.Rating),
                rating1 = g.Count(x => x.Rating == 1),
                rating2 = g.Count(x => x.Rating == 2),
                rating3 = g.Count(x => x.Rating == 3),
                rating4 = g.Count(x => x.Rating == 4),
                rating5 = g.Count(x => x.Rating == 5)
            })
            .FirstOrDefaultAsync();

        if (stats == null)
        {
            return Ok(new
            {
                totalReviews = 0,
                averageRating = 0.0,
                rating1 = 0,
                rating2 = 0,
                rating3 = 0,
                rating4 = 0,
                rating5 = 0
            });
        }

        return Ok(stats);
    }

    // ============================================================
    // GET: api/Reviews/all
    // Admin/staff xem tất cả đánh giá
    // ============================================================

    [HttpGet("all")]
    [Authorize(Roles = "Admin,Staff")]
    public async Task<IActionResult> GetAllReviews()
    {
        var reviews = await _context.Reviews
            .Include(x => x.Customer)
            .Include(x => x.Order)
            .OrderByDescending(x => x.CreatedAt)
            .Select(x => new
            {
                x.Id,
                x.OrderId,
                customerName = x.Customer!.FullName,
                customerPhone = x.Customer!.Phone,
                orderStatus = x.Order!.Status.ToString(),
                x.Rating,
                x.Comment,
                x.CreatedAt
            })
            .ToListAsync();

        return Ok(reviews);
    }
}
