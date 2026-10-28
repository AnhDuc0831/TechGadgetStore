using BusinessObjects.DTOs;

namespace Services.Interfaces;

public interface IDashboardService
{
    Task<DashboardOverviewDto> GetOverviewAsync(DashboardQueryParams query);
}

