using System.ComponentModel.DataAnnotations;

namespace BusinessObjects.DTOs.Cart;

public class AddCartItemRequest
{
    [Required] public Guid ProductVariantId { get; set; }
    [Range(1, 999)] public int Quantity { get; set; } = 1;
}