using Services;
using Services.Interfaces;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure 5-layer dependency injection & PostgreSQL Database
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found in configuration.");

builder.Services.AddBusinessServicesLayer(connectionString);

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// DB Health Check & 5-Layer Integration Test Endpoint
app.MapGet("/api/test-db", async (ICategoryService categoryService) =>
{
    try
    {
        var categories = await categoryService.GetAllCategoriesAsync();
        return Results.Ok(new
        {
            Status = "Database connection successful!",
            Message = "Successfully connected to PostgreSQL and traversed all 5 layers (API -> Services -> Repositories -> DataAccessObjects -> DB)",
            Count = categories.Count,
            Categories = categories
        });
    }
    catch (Exception ex)
    {
        return Results.Problem(
            title: "Database Connection Failed",
            detail: ex.InnerException?.Message ?? ex.Message,
            statusCode: StatusCodes.Status500InternalServerError
        );
    }
})
.WithName("TestDatabaseConnection")
.WithOpenApi();

app.Run();
