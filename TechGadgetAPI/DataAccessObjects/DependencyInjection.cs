using BusinessObjects.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;

namespace DataAccessObjects;

public static class DependencyInjection
{
    public static IServiceCollection AddDataAccessLayer(this IServiceCollection services, string connectionString)
    {
        var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);
        dataSourceBuilder.MapEnum<UserRole>("user_role");
        dataSourceBuilder.MapEnum<OrderStatus>("order_status");
        dataSourceBuilder.MapEnum<PaymentStatus>("payment_status");
        dataSourceBuilder.MapEnum<PaymentMethod>("payment_method");
        var dataSource = dataSourceBuilder.Build();

        services.AddDbContext<TechGadgetDbContext>(options =>
            options.UseNpgsql(dataSource));

        return services;
    }
}
