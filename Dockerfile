# Multi-stage build for .NET 8 Web API on Render
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files for caching dotnet restore
COPY ["TechGadgetAPI/TechGadgetAPI.sln", "TechGadgetAPI/"]
COPY ["TechGadgetAPI/API/API.csproj", "TechGadgetAPI/API/"]
COPY ["TechGadgetAPI/BusinessObjects/BusinessObjects.csproj", "TechGadgetAPI/BusinessObjects/"]
COPY ["TechGadgetAPI/DataAccessObjects/DataAccessObjects.csproj", "TechGadgetAPI/DataAccessObjects/"]
COPY ["TechGadgetAPI/Repositories/Repositories.csproj", "TechGadgetAPI/Repositories/"]
COPY ["TechGadgetAPI/Services/Services.csproj", "TechGadgetAPI/Services/"]
COPY ["TechGadgetAPI/Services.Tests/Services.Tests.csproj", "TechGadgetAPI/Services.Tests/"]

RUN dotnet restore "TechGadgetAPI/TechGadgetAPI.sln"

# Copy all source files and publish
COPY TechGadgetAPI/ TechGadgetAPI/
WORKDIR /src/TechGadgetAPI/API
RUN dotnet publish "API.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime image (.NET 8 ASP.NET)
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# Render tự động cấu hình PORT
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "API.dll"]
