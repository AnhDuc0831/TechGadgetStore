using DataAccessObjects;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Repositories.Implementations;
using Repositories.Interfaces;
using Services;
using Services.Implementations;
using Services.Interfaces;
using System.Security.Claims;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// 1. Controllers & API Documentation
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// Configure CORS for Flutter Web / Desktop / Mobile
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// 2. Swagger with JWT Bearer support
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "TechGadgetStore API",
        Version = "v1",
        Description = "Tech Gadget Store Backend API (.NET 8 - 5 Layer Architecture)"
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Nhập JWT Token của Supabase theo định dạng: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// 3. Configure 5-layer dependency injection & PostgreSQL Database
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found in configuration.");

builder.Services.AddBusinessServicesLayer(connectionString);

// 4. Configure Supabase JWT Authentication Middleware
var jwtSecret = builder.Configuration["Jwt:Secret"];
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "authenticated";
var jwtIssuer = builder.Configuration["Jwt:Issuer"];
var jwtAuthority = builder.Configuration["Jwt:Authority"] ?? jwtIssuer;

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;

    // Supabase Cloud OIDC / JWKS (hỗ trợ thuật toán ES256 / RS256)
    if (!string.IsNullOrEmpty(jwtAuthority) && jwtAuthority.StartsWith("http", StringComparison.OrdinalIgnoreCase))
    {
        options.Authority = jwtAuthority;
        options.MetadataAddress = $"{jwtAuthority.TrimEnd('/')}/.well-known/openid-configuration";
    }

    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        ValidateIssuer = !string.IsNullOrEmpty(jwtIssuer),
        ValidIssuer = jwtIssuer,
        ValidateAudience = !string.IsNullOrEmpty(jwtAudience),
        ValidAudience = jwtAudience,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero,
        NameClaimType = ClaimTypes.NameIdentifier,
        RoleClaimType = ClaimTypes.Role
    };

    // Fallback cho môi trường local mock db dùng HS256 với secret đối xứng
    if (!string.IsNullOrEmpty(jwtSecret) && (string.IsNullOrEmpty(jwtAuthority) || !jwtAuthority.StartsWith("http", StringComparison.OrdinalIgnoreCase)))
    {
        options.TokenValidationParameters.IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret));
    }
});

builder.Services.AddAuthorization();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "TechGadgetStore API v1");
    });
}

//app.UseHttpsRedirection();

app.UseCors("AllowAll");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Health Check Endpoint
app.MapGet("/api/health/db", async (ICategoryService categoryService) =>
{
    try
    {
        var categories = await categoryService.GetAllCategoriesAsync();
        return Results.Ok(new
        {
            Status = "Healthy",
            Message = "Successfully traversed all 5 layers: API -> Services -> Repositories -> DataAccessObjects -> DB",
            CategoriesCount = categories.Count
        });
    }
    catch (Exception ex)
    {
        return Results.Problem(
            title: "Database Health Check Failed",
            detail: ex.InnerException?.Message ?? ex.Message,
            statusCode: StatusCodes.Status500InternalServerError
        );
    }
})
.WithName("DatabaseHealthCheck")
.WithOpenApi();

app.Run();
