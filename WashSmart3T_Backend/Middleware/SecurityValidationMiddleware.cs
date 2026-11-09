using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using WashSmart.API.Data;

namespace WashSmart.API.Middleware;

public class SecurityValidationMiddleware
{
    private readonly RequestDelegate _next;

    public SecurityValidationMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, ApplicationDbContext dbContext)
    {
        if (context.User.Identity?.IsAuthenticated == true)
        {
            var userIdStr = context.User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (int.TryParse(userIdStr, out var userId))
            {
                var userRecord = await dbContext.Users
                    .AsNoTracking()
                    .Where(u => u.Id == userId)
                    .Select(u => new { u.IsActive })
                    .FirstOrDefaultAsync();

                if (userRecord == null || !userRecord.IsActive)
                {
                    context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsync("{\"message\": \"Tài khoản của bạn đã bị khóa hoặc ngừng hoạt động. Phiên làm việc đã bị thu hồi.\"}");
                    return;
                }
            }
        }

        await _next(context);
    }
}
