using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Services.Interfaces;

namespace Services.Implementations;

public class PayOSOrderCleanupHostedService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<PayOSOrderCleanupHostedService> _logger;
    private readonly TimeSpan _checkInterval = TimeSpan.FromMinutes(1);

    public PayOSOrderCleanupHostedService(
        IServiceScopeFactory scopeFactory,
        ILogger<PayOSOrderCleanupHostedService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("PayOSOrderCleanupHostedService background service started.");

        using var timer = new PeriodicTimer(_checkInterval);

        while (!stoppingToken.IsCancellationRequested && await timer.WaitForNextTickAsync(stoppingToken))
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var orderService = scope.ServiceProvider.GetRequiredService<IOrderService>();
                var cancelledCount = await orderService.CancelExpiredPayOSOrdersAsync(olderThanMinutes: 15);
                if (cancelledCount > 0)
                {
                    _logger.LogInformation("PayOSOrderCleanupHostedService: Đã tự động hủy {Count} đơn hàng PayOS quá 15 phút chưa thanh toán và hoàn trả tồn kho.", cancelledCount);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Lỗi khi chạy tiến trình nền quét và hủy đơn hàng PayOS hết hạn.");
            }
        }

        _logger.LogInformation("PayOSOrderCleanupHostedService background service stopping.");
    }
}
