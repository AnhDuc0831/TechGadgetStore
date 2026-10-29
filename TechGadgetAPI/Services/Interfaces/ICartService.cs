using BusinessObjects.DTOs.Cart;

namespace Services.Interfaces;

public interface ICartService
{
    Task<CartDto> GetCartAsync(Guid userId);
    Task<CartDto> AddItemAsync(Guid userId, AddCartItemRequest req);
    Task<CartDto> UpdateItemAsync(Guid userId, Guid itemId, int quantity);
    Task<CartDto> RemoveItemAsync(Guid userId, Guid itemId);
    Task<CartDto> ClearAsync(Guid userId);
}