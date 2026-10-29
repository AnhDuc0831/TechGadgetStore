using System.ComponentModel.DataAnnotations;

namespace BusinessObjects.DTOs.Cart;

public class UpdateCartItemRequest
{
    [Range(1, 999)] public int Quantity { get; set; }
}