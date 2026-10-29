using BusinessObjects.DTOs.Cart;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Cors.Infrastructure;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Security.Claims;

namespace API.Controllers;

[ApiController]
[Authorize]
[Route("api/cart")]
public class CartController : ControllerBase
{
    private readonly ICartService _service;
    public CartController(ICartService service) => _service = service;

    private Guid UserId
    {
        get
        {
            var sub = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return Guid.TryParse(sub, out var id) ? id : throw new UnauthorizedAccessException();
        }
    }

    [HttpGet]
    public Task<IActionResult> Get() => Run(() => _service.GetCartAsync(UserId));

    [HttpPost("items")]
    public Task<IActionResult> Add(AddCartItemRequest req) => Run(() => _service.AddItemAsync(UserId, req));

    [HttpPut("items/{itemId:guid}")]
    public Task<IActionResult> Update(Guid itemId, UpdateCartItemRequest req) =>
        Run(() => _service.UpdateItemAsync(UserId, itemId, req.Quantity));

    [HttpDelete("items/{itemId:guid}")]
    public Task<IActionResult> Remove(Guid itemId) => Run(() => _service.RemoveItemAsync(UserId, itemId));

    [HttpDelete]
    public Task<IActionResult> Clear() => Run(() => _service.ClearAsync(UserId));

    private async Task<IActionResult> Run(Func<Task<CartDto>> action)
    {
        try { return Ok(await action()); }
        catch (KeyNotFoundException ex) { return NotFound(new { message = ex.Message }); }
        catch (InvalidOperationException ex) { return BadRequest(new { message = ex.Message }); }
        catch (UnauthorizedAccessException) { return Unauthorized(); }
    }
}