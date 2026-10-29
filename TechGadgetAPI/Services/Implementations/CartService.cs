using System.Text.Json;
using BusinessObjects.DTOs.Cart;
using BusinessObjects.Enums;
using BusinessObjects.Models;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class CartService : ICartService
{
    private readonly ICartRepository _repo;
    public CartService(ICartRepository repo) => _repo = repo;

    public async Task<CartDto> GetCartAsync(Guid userId)
    {
        var cart = await _repo.GetCartByUserAsync(userId);
        return cart == null ? new CartDto() : ToDto(cart);
    }

    public async Task<CartDto> AddItemAsync(Guid userId, AddCartItemRequest req)
    {
        var variant = await _repo.GetVariantAsync(req.ProductVariantId)
            ?? throw new KeyNotFoundException("Không tìm thấy phiên bản sản phẩm.");

        if (!variant.IsActive || !variant.Product.IsActive)
            throw new InvalidOperationException("Sản phẩm hiện không còn bán.");

        var cart = await _repo.GetOrCreateCartAsync(userId);
        var existing = cart.CartItems.FirstOrDefault(i => i.ProductVariantId == req.ProductVariantId);
        var newQty = (existing?.Quantity ?? 0) + req.Quantity;

        if (newQty > variant.StockQuantity)
            throw new InvalidOperationException($"Chỉ còn {variant.StockQuantity} sản phẩm trong kho.");

        if (existing != null)
        {
            existing.Quantity = newQty;
            existing.UpdatedAt = DateTimeOffset.UtcNow;
            await _repo.SaveAsync();
        }
        else
        {
            await _repo.AddItemAsync(new CartItem
            {
                Id = Guid.NewGuid(),
                CartId = cart.Id,
                ProductVariantId = variant.Id,
                Quantity = req.Quantity,
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow
            });
        }
        return await GetCartAsync(userId);
    }

    public async Task<CartDto> UpdateItemAsync(Guid userId, Guid itemId, int quantity)
    {
        var cart = await _repo.GetCartByUserAsync(userId)
            ?? throw new KeyNotFoundException("Giỏ hàng trống.");
        var item = await _repo.GetItemAsync(cart.Id, itemId)
            ?? throw new KeyNotFoundException("Không tìm thấy sản phẩm trong giỏ.");

        if (quantity > item.ProductVariant.StockQuantity)
            throw new InvalidOperationException($"Chỉ còn {item.ProductVariant.StockQuantity} sản phẩm trong kho.");

        item.Quantity = quantity;
        item.UpdatedAt = DateTimeOffset.UtcNow;
        await _repo.SaveAsync();
        return await GetCartAsync(userId);
    }

    public async Task<CartDto> RemoveItemAsync(Guid userId, Guid itemId)
    {
        var cart = await _repo.GetCartByUserAsync(userId)
            ?? throw new KeyNotFoundException("Giỏ hàng trống.");
        var item = await _repo.GetItemAsync(cart.Id, itemId)
            ?? throw new KeyNotFoundException("Không tìm thấy sản phẩm trong giỏ.");
        await _repo.RemoveItemAsync(item);
        return await GetCartAsync(userId);
    }

    public async Task<CartDto> ClearAsync(Guid userId)
    {
        var cart = await _repo.GetCartByUserAsync(userId);
        if (cart != null) await _repo.ClearAsync(cart.Id);
        return new CartDto { Id = cart?.Id };
    }

    private static CartDto ToDto(ShoppingCart cart) => new()
    {
        Id = cart.Id,
        Items = cart.CartItems.OrderBy(i => i.CreatedAt).Select(i =>
        {
            var v = i.ProductVariant;
            var p = v.Product;
            return new CartItemDto
            {
                Id = i.Id,
                ProductId = p.Id,
                ProductVariantId = v.Id,
                ProductName = p.Name,
                ThumbnailUrl = p.ThumbnailUrl,
                Sku = v.Sku,
                Attributes = SerializeAttributes(v.Attributes),
                UnitPrice = p.BasePrice + v.PriceAdjustment,
                Quantity = i.Quantity,
                StockQuantity = v.StockQuantity,
                Status = GetStatus(i)
            };
        }).ToList()
    };

    private static CartItemStatus GetStatus(CartItem i)
    {
        var v = i.ProductVariant;
        if (!v.IsActive || !v.Product.IsActive) return CartItemStatus.Unavailable;
        if (v.StockQuantity <= 0) return CartItemStatus.OutOfStock;
        if (v.StockQuantity < i.Quantity) return CartItemStatus.InsufficientStock;
        return CartItemStatus.Available;
    }

    // product_variants.attributes là jsonb -> tùy cách scaffold có thể là string, JsonDocument hoặc Dictionary
    private static string? SerializeAttributes(object? attrs) => attrs switch
    {
        null => null,
        string str => str,
        JsonDocument doc => doc.RootElement.GetRawText(),
        JsonElement el => el.GetRawText(),
        _ => JsonSerializer.Serialize(attrs)
    };
}