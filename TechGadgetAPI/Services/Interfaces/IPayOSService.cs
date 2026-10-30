using PayOS.Models.V2.PaymentRequests;
using PayOS.Models.Webhooks;

namespace Services.Interfaces;

public interface IPayOSService
{
    Task<CreatePaymentLinkResponse> CreatePaymentLinkAsync(
        long orderCode,
        int amount,
        string description,
        List<PaymentLinkItem> items,
        string? buyerName = null,
        string? buyerPhone = null,
        string? buyerAddress = null);

    Task<PaymentLink?> GetPaymentLinkAsync(long orderCode);

    Task<PaymentLink?> CancelPaymentLinkAsync(long orderCode, string? reason = null);

    Task<WebhookData> VerifyWebhookDataAsync(Webhook webhook);

    Task<ConfirmWebhookResponse> ConfirmWebhookAsync(string webhookUrl);
}
