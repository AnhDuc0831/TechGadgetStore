using BusinessObjects.DTOs;
using Repositories.Interfaces;
using Services.Interfaces;

namespace Services.Implementations;

public class DashboardService : IDashboardService
{
    private readonly IDashboardRepository _dashboardRepository;

    public DashboardService(IDashboardRepository dashboardRepository)
    {
        _dashboardRepository = dashboardRepository;
    }

    public async Task<DashboardOverviewDto> GetOverviewAsync(DashboardQueryParams query)
    {
        return await _dashboardRepository.GetOverviewAsync(query);
    }
}

