using BusinessObjects.Models;
using Microsoft.EntityFrameworkCore;

namespace DataAccessObjects;

public class CartDAO
{
    private readonly TechGadgetDbContext _context;

    public CartDAO(TechGadgetDbContext context) => _context = context;

    private IQueryable<ShoppingCart> CartWithItems() =>
        _context.Set<ShoppingCart>()
           .Include(c => c.CartItems).ThenInclude(i => i.ProductVariant).ThenInclude(v => v.Product);

    public Task<ShoppingCart?> GetCartByUserAsync(Guid userId) =>
        CartWithItems().FirstOrDefaultAsync(c => c.UserId == userId);

    public async Task<ShoppingCart> GetOrCreateCartAsync(Guid userId)
    {
        var cart = await GetCartByUserAsync(userId);
        if (cart != null) return cart;

        cart = new ShoppingCart 
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CreatedAt = DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow
        };
        _context.Add(cart);
        await _context.SaveChangesAsync();
        return cart;
    }

    public Task<ProductVariant?> GetVariantAsync(Guid variantId) =>
        _context.Set<ProductVariant>().Include(v => v.Product).FirstOrDefaultAsync(v => v.Id == variantId);

    public Task<CartItem?> GetItemAsync(Guid cartId, Guid itemId) =>
        _context.Set<CartItem>().Include(i => i.ProductVariant)
           .FirstOrDefaultAsync(i => i.Id == itemId && i.CartId == cartId);

    public async Task AddItemAsync(CartItem item) { _context.Add(item); await _context.SaveChangesAsync(); }

    public async Task SaveAsync() => await _context.SaveChangesAsync();

    public async Task RemoveItemAsync(CartItem item) { _context.Remove(item); await _context.SaveChangesAsync(); }

    public async Task ClearAsync(Guid cartId) =>
        await _context.Set<CartItem>().Where(i => i.CartId == cartId).ExecuteDeleteAsync();
}