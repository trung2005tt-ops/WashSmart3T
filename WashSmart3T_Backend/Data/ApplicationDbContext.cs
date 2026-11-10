using Microsoft.EntityFrameworkCore;
using WashSmart.API.Models;

namespace WashSmart.API.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(
        DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // ============================
        // USER
        // ============================
        modelBuilder.Entity<User>()
            .HasIndex(x => x.Phone)
            .IsUnique();

        modelBuilder.Entity<User>()
            .Property(x => x.TotalSpent)
            .HasColumnType("decimal(18,2)");

        // ============================
        // ORDER
        // ============================
        modelBuilder.Entity<Order>()
            .HasOne(x => x.Customer)
            .WithMany()
            .HasForeignKey(x => x.CustomerId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Order>()
            .HasOne(x => x.Shipper)
            .WithMany()
            .HasForeignKey(x => x.ShipperId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Order>()
            .Property(x => x.TotalAmount)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<Order>()
            .Property(x => x.ShippingFee)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<Order>()
            .Property(x => x.AddonFee)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<Order>()
            .Property(x => x.DiscountAmount)
            .HasColumnType("decimal(18,2)");

        // ============================
        // ORDER DETAILS
        // ============================
        modelBuilder.Entity<OrderDetail>()
            .HasOne(x => x.Order)
            .WithMany(x => x.OrderDetails)
            .HasForeignKey(x => x.OrderId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<OrderDetail>()
            .HasOne(x => x.Service)
            .WithMany()
            .HasForeignKey(x => x.ServiceId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<OrderDetail>()
            .Property(x => x.Quantity)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<OrderDetail>()
            .Property(x => x.UnitPrice)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<OrderDetail>()
            .Property(x => x.TotalPrice)
            .HasColumnType("decimal(18,2)");

        // ============================
        // SERVICE PRICE
        // ============================
        modelBuilder.Entity<ServicePrice>()
            .Property(x => x.Price)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<ServicePrice>()
            .Property(x => x.MinimumPrice)
            .HasColumnType("decimal(18,2)");

        // ============================
        // ORDER STATUS HISTORY
        // ============================
        modelBuilder.Entity<OrderStatusHistory>()
            .HasOne(x => x.Order)
            .WithMany()
            .HasForeignKey(x => x.OrderId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<OrderStatusHistory>()
            .HasOne(x => x.ChangedByUser)
            .WithMany()
            .HasForeignKey(x => x.ChangedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        // ============================
        // PAYMENT
        // ============================
        modelBuilder.Entity<Payment>()
            .HasOne(x => x.Order)
            .WithMany()
            .HasForeignKey(x => x.OrderId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Payment>()
            .HasIndex(x => x.OrderId)
            .IsUnique();

        modelBuilder.Entity<Payment>()
            .Property(x => x.Amount)
            .HasColumnType("decimal(18,2)");

        modelBuilder.Entity<Payment>()
            .Property(x => x.RefundedAmount)
            .HasColumnType("decimal(18,2)");

        // ============================
        // REVIEW
        // ============================
        modelBuilder.Entity<Review>()
            .HasOne(x => x.Order)
            .WithMany()
            .HasForeignKey(x => x.OrderId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Review>()
            .HasOne(x => x.Customer)
            .WithMany()
            .HasForeignKey(x => x.CustomerId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Review>()
            .HasIndex(x => x.OrderId)
            .IsUnique();

        modelBuilder.Entity<Review>()
            .HasIndex(x => x.Rating);

        // ============================
        // COMPLAINT (BẢO HIỂM 3T CARE)
        // ============================
        modelBuilder.Entity<Complaint>(entity =>
        {
            entity.HasIndex(x => x.TicketCode).IsUnique();
            entity.HasIndex(x => x.CustomerId);
            entity.HasIndex(x => x.OrderId);
            entity.HasIndex(x => x.Status);

            entity.HasOne(x => x.Customer)
                .WithMany()
                .HasForeignKey(x => x.CustomerId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(x => x.Order)
                .WithMany()
                .HasForeignKey(x => x.OrderId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.Property(x => x.RequestedRefund).HasColumnType("decimal(18,2)");
            entity.Property(x => x.ApprovedAmount).HasColumnType("decimal(18,2)");
        });

        // ============================
        // STORE CONFIG
        // ============================
        modelBuilder.Entity<StoreConfig>(entity =>
        {
            entity.Property(x => x.BaseShippingFee).HasColumnType("decimal(18,2)");
            entity.Property(x => x.Tier2ShippingFee).HasColumnType("decimal(18,2)");
            entity.Property(x => x.Tier3ShippingFee).HasColumnType("decimal(18,2)");
            entity.Property(x => x.ExpressExtraFee).HasColumnType("decimal(18,2)");
            entity.Property(x => x.AddonComfortFee).HasColumnType("decimal(18,2)");
            entity.Property(x => x.AddonBagFee).HasColumnType("decimal(18,2)");
            entity.Property(x => x.FreeShipMinAmount).HasColumnType("decimal(18,2)");
        });

        // ============================
        // PROMOTION (VOUCHERS)
        // ============================
        modelBuilder.Entity<Promotion>(entity =>
        {
            entity.HasIndex(x => x.Code).IsUnique();
            entity.Property(x => x.DiscountValue).HasColumnType("decimal(18,2)");
            entity.Property(x => x.MinOrderAmount).HasColumnType("decimal(18,2)");
            entity.Property(x => x.MaxDiscountAmount).HasColumnType("decimal(18,2)");
        });
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<Service> Services => Set<Service>();
    public DbSet<ServicePrice> ServicePrices => Set<ServicePrice>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<OrderDetail> OrderDetails => Set<OrderDetail>();
    public DbSet<OrderStatusHistory> OrderStatusHistories => Set<OrderStatusHistory>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<Complaint> Complaints => Set<Complaint>();
    public DbSet<StoreConfig> StoreConfigs => Set<StoreConfig>();
    public DbSet<Promotion> Promotions => Set<Promotion>();
}
