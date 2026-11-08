using System.ComponentModel.DataAnnotations;

namespace WashSmart.API.DTOs;

// ============================================================
// REQUEST TẠO ĐÁNH GIÁ CHO ĐƠN HÀNG
// ============================================================

public class CreateReviewRequest
{
    // Điểm từ 1 đến 5
    [Required]
    [Range(1, 5)]
    public int Rating { get; set; }

    [MaxLength(1000)]
    public string? Comment { get; set; }
}
