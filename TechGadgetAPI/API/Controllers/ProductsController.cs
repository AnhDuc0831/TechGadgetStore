using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly IProductService _productService;

    public ProductsController(IProductService productService)
    {
        _productService = productService;
    }

    /// <summary>
    /// Lấy danh sách sản phẩm có phân trang, lọc theo danh mục/thương hiệu, tìm kiếm theo tên và sắp xếp.
    /// </summary>
    /// <remarks>
    /// Ví dụ: GET /api/products?page=1&amp;pageSize=20&amp;categoryIds={id}&amp;brandIds={id}&amp;search=iphone&amp;sortBy=price_asc
    ///
    /// sortBy: newest (mặc định), price_asc, price_desc, name
    /// </remarks>
    [HttpGet]
    [ProducesResponseType(typeof(PagedResult<ProductListItemDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetProducts([FromQuery] ProductQueryParams query)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var result = await _productService.GetProductsAsync(query);
        return Ok(result);
    }

    /// <summary>
    /// Lấy chi tiết sản phẩm theo ID, bao gồm tất cả biến thể đang hoạt động.
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(ProductDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetProductById(Guid id)
    {
        var product = await _productService.GetProductByIdAsync(id);
        if (product == null)
        {
            return NotFound(new { message = $"Product with ID {id} was not found." });
        }

        return Ok(product);
    }

    /// <summary>
    /// Lấy chi tiết sản phẩm theo slug (vd: iphone-15-pro-max), bao gồm tất cả biến thể đang hoạt động.
    /// </summary>
    [HttpGet("slug/{slug}")]
    [ProducesResponseType(typeof(ProductDetailDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetProductBySlug(string slug)
    {
        var product = await _productService.GetProductBySlugAsync(slug);
        if (product == null)
        {
            return NotFound(new { message = $"Product with slug '{slug}' was not found." });
        }

        return Ok(product);
    }
}
