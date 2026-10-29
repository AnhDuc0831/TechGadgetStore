using BusinessObjects.Models;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class CartRepository : ICartRepository
{
    private readonly CartDAO _dao;
    public CartRepository(CartDAO dao) => _dao = dao;

    public Task<ShoppingCart?> GetCartByUserAsync(Guid userId) => _dao.GetCartByUserAsync(userId);
    public Task<ShoppingCart> GetOrCreateCartAsync(Guid userId) => _dao.GetOrCreateCartAsync(userId);
    public Task<ProductVariant?> GetVariantAsync(Guid variantId) => _dao.GetVariantAsync(variantId);
    public Task<CartItem?> GetItemAsync(Guid cartId, Guid itemId) => _dao.GetItemAsync(cartId, itemId);
    public Task AddItemAsync(CartItem item) => _dao.AddItemAsync(item);
    public Task SaveAsync() => _dao.SaveAsync();
    public Task RemoveItemAsync(CartItem item) => _dao.RemoveItemAsync(item);
    public Task ClearAsync(Guid cartId) => _dao.ClearAsync(cartId);
}