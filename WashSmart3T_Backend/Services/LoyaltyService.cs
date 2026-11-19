using WashSmart.API.Models;

namespace WashSmart.API.Services;

public static class LoyaltyService
{
    /// <summary>
    /// Tính toán cấp bậc thành viên dựa trên tổng chi tiêu và điểm tích lũy 3T Xu
    /// - Kim Cương (Diamond): Tổng chi tiêu >= 2.000.000đ hoặc Xu >= 2.000
    /// - Vàng (Gold): Tổng chi tiêu >= 1.000.000đ hoặc Xu >= 1.000
    /// - Bạc (Silver): Tổng chi tiêu >= 500.000đ hoặc Xu >= 500
    /// - Đồng (Bronze): Dưới 500.000đ
    /// </summary>
    public static string CalculateTier(decimal totalSpent, int loyaltyPoints)
    {
        if (totalSpent >= 2000000m || loyaltyPoints >= 2000)
        {
            return "Diamond";
        }
        if (totalSpent >= 1000000m || loyaltyPoints >= 1000)
        {
            return "Gold";
        }
        if (totalSpent >= 500000m || loyaltyPoints >= 500)
        {
            return "Silver";
        }
        return "Bronze";
    }

    /// <summary>
    /// Tích điểm thưởng 3T Xu và nâng hạng thành viên khi thanh toán đơn hàng thành công.
    /// Tỷ lệ quy chuẩn: Mỗi 1.000 VNĐ thanh toán thực tế = 1 điểm 3T Xu.
    /// </summary>
    public static int AwardLoyalty(User customer, decimal paidAmount)
    {
        if (customer == null || paidAmount <= 0) return 0;

        int pointsEarned = (int)(paidAmount / 1000m);
        customer.LoyaltyPoints += pointsEarned;
        customer.TotalSpent += paidAmount;
        customer.MembershipTier = CalculateTier(customer.TotalSpent, customer.LoyaltyPoints);

        return pointsEarned;
    }

    /// <summary>
    /// Cộng điểm thưởng bồi hoàn khi khiếu nại được giải quyết qua phương án Tích Điểm / Xu.
    /// </summary>
    public static void CompensatePoints(User customer, int points)
    {
        if (customer == null || points <= 0) return;
        customer.LoyaltyPoints += points;
        customer.MembershipTier = CalculateTier(customer.TotalSpent, customer.LoyaltyPoints);
    }
}
