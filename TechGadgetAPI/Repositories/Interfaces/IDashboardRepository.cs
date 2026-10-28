using BusinessObjects.DTOs;

namespace Repositories.Interfaces;

public interface IDashboardRepository
{
    Task<DashboardOverviewDto> GetOverviewAsync(DashboardQueryParams query);
}

