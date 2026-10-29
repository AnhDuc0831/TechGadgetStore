using BusinessObjects.Models;

namespace Repositories.Interfaces;

public interface ICartRepository
{
    Task<ShoppingCart?> GetCartByUserAsync(Guid userId);
    Task<ShoppingCart> GetOrCreateCartAsync(Guid userId);
    Task<ProductVariant?> GetVariantAsync(Guid variantId);
    Task<CartItem?> GetItemAsync(Guid cartId, Guid itemId);
    Task AddItemAsync(CartItem item);
    Task SaveAsync();
    Task RemoveItemAsync(CartItem item);
    Task ClearAsync(Guid cartId);
}