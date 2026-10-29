namespace BusinessObjects.DTOs.Cart;

public class CartDto
{
    public Guid? Id { get; set; }
    public List<CartItemDto> Items { get; set; } = new();
    public int TotalQuantity => Items.Sum(i => i.Quantity);
    public decimal TotalAmount => Items.Where(i => i.IsAvailable).Sum(i => i.LineTotal);
}