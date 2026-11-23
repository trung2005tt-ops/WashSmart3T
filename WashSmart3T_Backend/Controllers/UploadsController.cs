using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace WashSmart.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[AllowAnonymous] // Cho phép upload ảnh minh chứng không bị chặn 401 khi token hết hạn
public class UploadsController : ControllerBase
{
    private readonly IWebHostEnvironment _env;

    public UploadsController(IWebHostEnvironment env)
    {
        _env = env;
    }

    // ============================================================
    // POST: api/Uploads
    // Tải ảnh minh chứng giao hàng, ảnh sự cố khiếu nại (10MB tối đa)
    // ============================================================
    [HttpPost]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> UploadImage(IFormFile? file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "Vui lòng chọn file hình ảnh hợp lệ." });
        }

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (string.IsNullOrEmpty(ext) || ext == ".blob")
        {
            if (file.ContentType == "image/png") ext = ".png";
            else if (file.ContentType == "image/webp") ext = ".webp";
            else ext = ".jpg";
        }

        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp" };
        if (!allowedExtensions.Contains(ext))
        {
            ext = ".jpg";
        }

        var rootPath = _env.WebRootPath ?? Path.Combine(_env.ContentRootPath, "wwwroot");
        var uploadsFolder = Path.Combine(rootPath, "uploads");
        if (!Directory.Exists(uploadsFolder))
        {
            Directory.CreateDirectory(uploadsFolder);
        }

        var fileName = $"{Guid.NewGuid():N}{ext}";
        var filePath = Path.Combine(uploadsFolder, fileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream);
        }

        var photoUrl = $"/uploads/{fileName}";
        return Ok(new
        {
            message = "Tải ảnh lên máy chủ thành công.",
            url = photoUrl,
            fileName = fileName,
            size = file.Length
        });
    }
}
