namespace WashSmart.API.Models;

public class User
{
    public int Id { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Phone { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string PasswordHash { get; set; } = string.Empty;

    public int RoleId { get; set; }

    public Role? Role { get; set; }

    public bool IsActive { get; set; } = true;

    // ============================
    // CUSTOMER LOYALTY & TIERS
    // ============================
    public int LoyaltyPoints { get; set; } = 0;

    public string MembershipTier { get; set; } = "Bronze"; // Bronze, Silver, Gold, Diamond

    public decimal TotalSpent { get; set; } = 0;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}