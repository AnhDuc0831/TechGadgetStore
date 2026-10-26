using DataAccessObjects;
using Microsoft.Extensions.DependencyInjection;
using Repositories.Implementations;
using Repositories.Interfaces;

namespace Repositories;

public static class DependencyInjection
{
    public static IServiceCollection AddRepositoriesLayer(this IServiceCollection services, string connectionString)
    {
        services.AddDataAccessLayer(connectionString);

        // Repositories Registration
        services.AddScoped<ICategoryRepository, CategoryRepository>();
        services.AddScoped<IProfileRepository, ProfileRepository>();
        services.AddScoped<IProductRepository, ProductRepository>();
        services.AddScoped<IBrandRepository, BrandRepository>();

        return services;
    }
}
