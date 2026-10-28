using BusinessObjects.DTOs;
using DataAccessObjects;
using Repositories.Interfaces;

namespace Repositories.Implementations;

public class DashboardRepository : IDashboardRepository
{
    private readonly DashboardDAO _dashboardDAO;

    public DashboardRepository(DashboardDAO dashboardDAO)
    {
        _dashboardDAO = dashboardDAO;
    }

    public async Task<DashboardOverviewDto> GetOverviewAsync(DashboardQueryParams query)
    {
        return await _dashboardDAO.GetOverviewAsync(query);
    }
}

