namespace BusinessObjects.DTOs;

public class ShippingOptions
{
    public const string SectionName = "Shipping";
    public decimal FlatFee { get; set; } = 30000;
    public decimal FreeShippingThreshold { get; set; } = 500000;
}
