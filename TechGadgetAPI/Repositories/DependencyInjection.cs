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
        services.AddScoped<ICategoryRepository, CategoryRepository>();
        return services;
    }
}
