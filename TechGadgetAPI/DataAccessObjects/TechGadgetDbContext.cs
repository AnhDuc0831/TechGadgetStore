using BusinessObjects.Enums;
using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class TechGadgetDbContext : DbContext
{
    public TechGadgetDbContext(DbContextOptions<TechGadgetDbContext> options) : base(options)
    {
    }

    public virtual DbSet<Profile> Profiles => Set<Profile>();
    public virtual DbSet<Category> Categories => Set<Category>();
    public virtual DbSet<Brand> Brands => Set<Brand>();
    public virtual DbSet<Product> Products => Set<Product>();
    public virtual DbSet<ProductVariant> ProductVariants => Set<ProductVariant>();
    public virtual DbSet<ShoppingCart> ShoppingCarts => Set<ShoppingCart>();
    public virtual DbSet<CartItem> CartItems => Set<CartItem>();
    public virtual DbSet<Order> Orders => Set<Order>();
    public virtual DbSet<OrderItem> OrderItems => Set<OrderItem>();
    public virtual DbSet<Review> Reviews => Set<Review>();
    public virtual DbSet<Favorite> Favorites => Set<Favorite>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // 1. PostgreSQL Enum Types Mapping
        modelBuilder.HasPostgresEnum<UserRole>("public", "user_role");
        modelBuilder.HasPostgresEnum<OrderStatus>("public", "order_status");
        modelBuilder.HasPostgresEnum<PaymentStatus>("public", "payment_status");
        modelBuilder.HasPostgresEnum<PaymentMethod>("public", "payment_method");

        // 2. Unique Constraints & Indexes
        modelBuilder.Entity<Category>(entity =>
        {
            entity.HasIndex(e => e.Slug).IsUnique();
        });

        modelBuilder.Entity<Brand>(entity =>
        {
            entity.HasIndex(e => e.Name).IsUnique();
        });

        modelBuilder.Entity<Product>(entity =>
        {
            entity.HasIndex(e => e.Slug).IsUnique();
            entity.HasIndex(e => e.CategoryId);
            entity.HasIndex(e => e.BrandId);
            entity.HasIndex(e => e.IsActive);
        });

        modelBuilder.Entity<ProductVariant>(entity =>
        {
            entity.HasIndex(e => e.Sku).IsUnique();
            entity.HasIndex(e => e.ProductId);
        });

        modelBuilder.Entity<CartItem>(entity =>
        {
            entity.HasIndex(e => new { e.CartId, e.ProductVariantId }).IsUnique();
        });

        modelBuilder.Entity<Review>(entity =>
        {
            entity.HasIndex(e => new { e.ProductId, e.UserId }).IsUnique();
        });

        modelBuilder.Entity<Favorite>(entity =>
        {
            entity.HasIndex(e => new { e.UserId, e.ProductId }).IsUnique();
        });

        modelBuilder.Entity<Order>(entity =>
        {
            entity.HasIndex(e => e.UserId);
            entity.HasIndex(e => e.Status);
        });

        modelBuilder.Entity<OrderItem>(entity =>
        {
            entity.HasIndex(e => e.OrderId);
        });
    }
}
