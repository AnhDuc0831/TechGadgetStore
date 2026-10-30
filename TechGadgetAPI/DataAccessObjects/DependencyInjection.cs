using BusinessObjects.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Npgsql.NameTranslation;

namespace DataAccessObjects;

public static class DependencyInjection
{
    public static IServiceCollection AddDataAccessLayer(this IServiceCollection services, string connectionString)
    {
        var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
        dataSourceBuilder.MapEnum<UserRole>("user_role");
        dataSourceBuilder.MapEnum<OrderStatus>("order_status");
        dataSourceBuilder.MapEnum<PaymentStatus>("payment_status");
        dataSourceBuilder.MapEnum<PaymentMethod>("payment_method", new PaymentMethodNameTranslator());
        var dataSource = dataSourceBuilder.Build();

        services.AddDbContext<TechGadgetDbContext>(options =>
            options.UseNpgsql(dataSource));

        // DAOs Registration
        services.AddScoped<ProfileDAO>();
        services.AddScoped<ProductDAO>();
        services.AddScoped<BrandDAO>();
        services.AddScoped<DashboardDAO>();
        services.AddScoped<CartDAO>();
        services.AddScoped<OrderDAO>();

        return services;
    }
}

public class PaymentMethodNameTranslator : INpgsqlNameTranslator
{
    private readonly INpgsqlNameTranslator _snake = new NpgsqlSnakeCaseNameTranslator();

    public string TranslateTypeName(string clrName) => _snake.TranslateTypeName(clrName);

    public string TranslateMemberName(string clrName) =>
        clrName.Equals(nameof(PaymentMethod.PayOS), StringComparison.OrdinalIgnoreCase)
            ? "payos"
            : _snake.TranslateMemberName(clrName);
}
