using BusinessObjects.DTOs;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PayOS;
using PayOS.Models.V2.PaymentRequests;
using PayOS.Models.Webhooks;
using Services.Interfaces;

namespace Services.Implementations;

public class PayOSService : IPayOSService
{
    private readonly BusinessObjects.DTOs.PayOSOptions _options;
    private readonly PayOSClient _client;
    private readonly ILogger<PayOSService> _logger;

    public PayOSService(IOptions<BusinessObjects.DTOs.PayOSOptions> options, ILogger<PayOSService> logger)
    {
        _options = options.Value;
        _logger = logger;

        var clientOptions = new PayOS.PayOSOptions
        {
            ClientId = _options.ClientId,
            ApiKey = _options.ApiKey,
            ChecksumKey = _options.ChecksumKey
        };

        _client = new PayOSClient(clientOptions);
    }

    public async Task<CreatePaymentLinkResponse> CreatePaymentLinkAsync(
        long orderCode,
        int amount,
        string description,
        List<PaymentLinkItem> items,
        string? buyerName = null,
        string? buyerPhone = null,
        string? buyerAddress = null)
    {
        // payOS description has character limits (max 25 characters usually)
        if (description.Length > 25)
        {
            description = description.Substring(0, 25);
        }

        var request = new CreatePaymentLinkRequest
        {
            OrderCode = orderCode,
            Amount = amount,
            Description = description,
            Items = items,
            ReturnUrl = _options.ReturnUrl,
            CancelUrl = _options.CancelUrl,
            BuyerName = buyerName,
            BuyerPhone = buyerPhone,
            BuyerAddress = buyerAddress,
            ExpiredAt = (int)DateTimeOffset.UtcNow.AddMinutes(15).ToUnixTimeSeconds()
        };

        return await _client.PaymentRequests.CreateAsync(request);
    }

    public async Task<PaymentLink?> GetPaymentLinkAsync(long orderCode)
    {
        try
        {
            return await _client.PaymentRequests.GetAsync(orderCode);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to retrieve PayOS payment link for orderCode: {OrderCode}", orderCode);
            return null;
        }
    }

    public async Task<PaymentLink?> CancelPaymentLinkAsync(long orderCode, string? reason = null)
    {
        try
        {
            return await _client.PaymentRequests.CancelAsync(orderCode, reason ?? "User requested cancellation");
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to cancel PayOS payment link for orderCode: {OrderCode}", orderCode);
            return null;
        }
    }

    public async Task<WebhookData> VerifyWebhookDataAsync(Webhook webhook)
    {
        return await _client.Webhooks.VerifyAsync(webhook);
    }

    public async Task<ConfirmWebhookResponse> ConfirmWebhookAsync(string webhookUrl)
    {
        return await _client.Webhooks.ConfirmAsync(webhookUrl);
    }
}
