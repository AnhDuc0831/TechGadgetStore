using API.Controllers;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Moq;
using PayOS.Models.Webhooks;
using Services.Interfaces;
using System.Text.Json;
using Xunit;

namespace Services.Tests;

public class PayOSWebhookControllerTests
{
    private readonly Mock<IOrderService> _orderServiceMock;
    private readonly Mock<IPayOSService> _payOSServiceMock;
    private readonly Mock<IProfileService> _profileServiceMock;
    private readonly Mock<ILogger<PayOSWebhookController>> _loggerMock;
    private readonly PayOSWebhookController _controller;

    public PayOSWebhookControllerTests()
    {
        _orderServiceMock = new Mock<IOrderService>();
        _payOSServiceMock = new Mock<IPayOSService>();
        _profileServiceMock = new Mock<IProfileService>();
        _loggerMock = new Mock<ILogger<PayOSWebhookController>>();

        _controller = new PayOSWebhookController(
            _orderServiceMock.Object,
            _payOSServiceMock.Object,
            _profileServiceMock.Object,
            _loggerMock.Object);
    }

    [Fact]
    public async Task HandleWebhook_EmptyBody_Returns200WithSuccessTrue()
    {
        // Arrange
        _orderServiceMock
            .Setup(s => s.ProcessPayOSWebhookAsync(null))
            .ReturnsAsync(true);

        // Act
        var result = await _controller.HandleWebhook(null);

        // Assert: HTTP 200 with { success: true }
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(StatusCodes.Status200OK, okResult.StatusCode);

        var json = JsonSerializer.Serialize(okResult.Value);
        Assert.Contains("\"success\":true", json);
    }

    [Fact]
    public async Task HandleWebhook_InvalidSignature_Returns200WithSuccessTrue()
    {
        // Arrange
        var webhook = new Webhook();
        _orderServiceMock
            .Setup(s => s.ProcessPayOSWebhookAsync(webhook))
            .ReturnsAsync(true);

        // Act
        var result = await _controller.HandleWebhook(webhook);

        // Assert: HTTP 200 with { success: true }
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(StatusCodes.Status200OK, okResult.StatusCode);

        var json = JsonSerializer.Serialize(okResult.Value);
        Assert.Contains("\"success\":true", json);
    }

    [Fact]
    public async Task HandleWebhook_UnknownOrderCode_Returns200WithSuccessTrue()
    {
        // Arrange
        var webhook = new Webhook();
        _orderServiceMock
            .Setup(s => s.ProcessPayOSWebhookAsync(webhook))
            .ReturnsAsync(true);

        // Act
        var result = await _controller.HandleWebhook(webhook);

        // Assert: HTTP 200 with { success: true } (never 404!)
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(StatusCodes.Status200OK, okResult.StatusCode);

        var json = JsonSerializer.Serialize(okResult.Value);
        Assert.Contains("\"success\":true", json);
    }

    [Fact]
    public async Task HandleWebhook_ValidPayload_ExistingOrder_Returns200WithSuccessTrue()
    {
        // Arrange
        var webhook = new Webhook();
        _orderServiceMock
            .Setup(s => s.ProcessPayOSWebhookAsync(webhook))
            .ReturnsAsync(true);

        // Act
        var result = await _controller.HandleWebhook(webhook);

        // Assert: HTTP 200 with { success: true }
        var okResult = Assert.IsType<OkObjectResult>(result);
        Assert.Equal(StatusCodes.Status200OK, okResult.StatusCode);

        var json = JsonSerializer.Serialize(okResult.Value);
        Assert.Contains("\"success\":true", json);
    }

    [Fact]
    public async Task HandleWebhook_GenuineProcessingErrorOnMatchedOrder_Returns500InternalServerError()
    {
        // Arrange: database exception during processing
        var webhook = new Webhook();
        _orderServiceMock
            .Setup(s => s.ProcessPayOSWebhookAsync(webhook))
            .ThrowsAsync(new InvalidOperationException("Database connection failed"));

        // Act
        var result = await _controller.HandleWebhook(webhook);

        // Assert: HTTP 500 so payOS retries
        var objectResult = Assert.IsType<ObjectResult>(result);
        Assert.Equal(StatusCodes.Status500InternalServerError, objectResult.StatusCode);

        var json = JsonSerializer.Serialize(objectResult.Value);
        Assert.Contains("\"success\":false", json);
    }
}

