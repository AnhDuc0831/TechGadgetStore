using Microsoft.Extensions.DependencyInjection;
using Repositories;
using Services.Implementations;
using Services.Interfaces;

namespace Services;

public static class DependencyInjection
{
    public static IServiceCollection AddBusinessServicesLayer(this IServiceCollection services, string connectionString)
    {
        services.AddRepositoriesLayer(connectionString);

        // Services Registration
        services.AddScoped<ICategoryService, CategoryService>();
        services.AddScoped<IProfileService, ProfileService>();

        return services;
    }
}
