using BusinessObjects.Enums;
using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace DataAccessObjects;

public class ReviewDAO
{

    private readonly TechGadgetDbContext _context;

    public ReviewDAO(TechGadgetDbContext context)
    {
        _context = context;
    }

    // =====================================================================
    // PUBLIC
    // =====================================================================

    public async Task<(List<Review> Items, int TotalCount)> GetProductReviewsAsync(
        Guid productId, int page, int pageSize, int? rating, bool hasImages)
    {
        var query = _context.Reviews.AsNoTracking().Where(r => r.ProductId == productId);

        if (rating is >= 1 and <= 5)
        {
            query = query.Where(r => r.Rating == rating.Value);
        }
        if (hasImages)
        {
            // Ảnh của đánh giá đã bị ẩn nội dung không được hiển thị → không tính là "có ảnh"
            query = query.Where(r => r.Images.Count > 0 && !r.ContentHidden);
        }

        var total = await query.CountAsync();
        var items = await query
            .Include(r => r.User)
            .OrderByDescending(r => r.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return (items, total);
    }

    /// <summary>Thống kê đánh giá của sản phẩm: (số lượng theo sao, số đánh giá có ảnh).</summary>
    public async Task<(Dictionary<int, int> RatingCounts, int WithImages)> GetSummaryAsync(Guid productId)
    {
        var counts = await _context.Reviews
            .AsNoTracking()
            .Where(r => r.ProductId == productId)
            .GroupBy(r => r.Rating)
            .Select(g => new { Rating = (int)g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Rating, x => x.Count);

        var withImages = await _context.Reviews
            .AsNoTracking()
            .CountAsync(r => r.ProductId == productId && r.Images.Count > 0 && !r.ContentHidden);

        return (counts, withImages);
    }

    public Task<bool> ProductExistsAsync(Guid productId) =>
        _context.Products.AnyAsync(p => p.Id == productId);

    // =====================================================================
    // CUSTOMER
    // =====================================================================

    public Task<Review?> GetUserReviewAsync(Guid productId, Guid userId) =>
        _context.Reviews
            .Include(r => r.User)
            .FirstOrDefaultAsync(r => r.ProductId == productId && r.UserId == userId);

    /// <summary>
    /// Đơn hàng ĐÃ HOÀN THÀNH gần nhất của khách có chứa sản phẩm này (bằng chứng đã mua).
    /// Trả về (OrderId, Sku) hoặc null nếu khách chưa mua / đơn chưa hoàn thành.
    /// </summary>
    public async Task<(Guid OrderId, string Sku)?> GetCompletedPurchaseAsync(Guid productId, Guid userId)
    {
        var purchase = await _context.OrderItems
            .AsNoTracking()
            .Where(oi => oi.ProductVariant.ProductId == productId
                         && oi.Order.UserId == userId
                         // Enum order_status trong DB không có 'completed': đơn hoàn thành được lưu là 'delivered'
                         // (xem OrderStatusMapper.ToDbStatus). Đưa Completed vào câu SQL sẽ gây lỗi 22P02.
                         && oi.Order.Status == OrderStatus.Delivered)
            .OrderByDescending(oi => oi.Order.UpdatedAt)
            .Select(oi => new { oi.OrderId, oi.Sku })
            .FirstOrDefaultAsync();

        return purchase == null ? null : (purchase.OrderId, purchase.Sku);
    }

    /// <summary>Khách có đơn chứa sản phẩm này nhưng chưa hoàn thành (đang xử lý / đang giao)?</summary>
    public Task<bool> HasInProgressPurchaseAsync(Guid productId, Guid userId) =>
        _context.OrderItems.AnyAsync(oi => oi.ProductVariant.ProductId == productId
                                           && oi.Order.UserId == userId
                                           && oi.Order.Status != OrderStatus.Cancelled
                                           && oi.Order.Status != OrderStatus.Delivered);

    /// <summary>Số lần khách gửi / sửa đánh giá kể từ thời điểm <paramref name="since"/> (chống spam).</summary>
    public Task<int> CountRecentSubmissionsAsync(Guid userId, DateTimeOffset since) =>
        _context.Reviews.CountAsync(r => r.UserId == userId
                                         && (r.CreatedAt >= since || (r.EditedAt != null && r.EditedAt >= since)));

    /// <summary>Sản phẩm đã mua (đơn hoàn thành) nhưng chưa đánh giá.</summary>
    public async Task<List<(Guid ProductId, string ProductName, string? Thumbnail, string Sku, Guid OrderId, DateTimeOffset PurchasedAt)>>
        GetPendingReviewsAsync(Guid userId)
    {
        var rows = await _context.OrderItems
            .AsNoTracking()
            .Where(oi => oi.Order.UserId == userId
                         && oi.Order.Status == OrderStatus.Delivered
                         && !_context.Reviews.Any(r => r.UserId == userId && r.ProductId == oi.ProductVariant.ProductId))
            .Select(oi => new
            {
                oi.ProductVariant.ProductId,
                ProductName = oi.ProductVariant.Product.Name,
                oi.ProductVariant.Product.ThumbnailUrl,
                oi.Sku,
                oi.OrderId,
                PurchasedAt = oi.Order.UpdatedAt
            })
            .ToListAsync();

        // Mỗi sản phẩm chỉ hiện 1 lần (lấy lần mua gần nhất)
        return rows
            .GroupBy(r => r.ProductId)
            .Select(g => g.OrderByDescending(x => x.PurchasedAt).First())
            .OrderByDescending(x => x.PurchasedAt)
            .Select(x => (x.ProductId, x.ProductName, x.ThumbnailUrl, x.Sku, x.OrderId, x.PurchasedAt))
            .ToList();
    }

    /// <summary>Thêm đánh giá mới. Ném InvalidOperationException nếu khách đã đánh giá (race 2 request cùng lúc).</summary>
    public async Task<Review> AddAsync(Review review)
    {
        _context.Reviews.Add(review);
        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (ex.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            throw new InvalidOperationException("Bạn đã đánh giá sản phẩm này rồi. Vui lòng tải lại để chỉnh sửa đánh giá.");
        }
        return review;
    }

    public async Task UpdateAsync(Review review)
    {
        review.UpdatedAt = DateTimeOffset.UtcNow;
        await _context.SaveChangesAsync();
    }

    // =====================================================================
    // ADMIN
    // =====================================================================

    public async Task<(List<Review> Items, int TotalCount)> GetAdminReviewsAsync(
        int page, int pageSize, int? rating, bool? hasReply, string? search)
    {
        var query = _context.Reviews.AsNoTracking().AsQueryable();

        if (rating is >= 1 and <= 5)
        {
            query = query.Where(r => r.Rating == rating.Value);
        }
        if (hasReply.HasValue)
        {
            query = hasReply.Value
                ? query.Where(r => r.AdminReply != null)
                : query.Where(r => r.AdminReply == null);
        }
        if (!string.IsNullOrWhiteSpace(search))
        {
            var keyword = $"%{search.Trim()}%";
            query = query.Where(r => EF.Functions.ILike(r.Product.Name, keyword)
                                     || (r.Comment != null && EF.Functions.ILike(r.Comment, keyword)));
        }

        var total = await query.CountAsync();
        var items = await query
            .Include(r => r.User)
            .Include(r => r.Product)
            // Ưu tiên đánh giá chưa được phản hồi, rồi đến đánh giá thấp sao, rồi mới nhất
            .OrderBy(r => r.AdminReply != null)
            .ThenBy(r => r.Rating)
            .ThenByDescending(r => r.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return (items, total);
    }

    public Task<Review?> GetByIdAsync(Guid id) =>
        _context.Reviews
            .Include(r => r.User)
            .Include(r => r.Product)
            .FirstOrDefaultAsync(r => r.Id == id);
}
