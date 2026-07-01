using System.Reflection;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Load configuration files in the correct order
builder.Configuration.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                     .AddJsonFile("appsettings.Production.json", optional: true, reloadOnChange: true);

// Add services to the container
builder.Services.AddControllers();

// Add static files
builder.Services.AddDirectoryBrowser();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "CS Ranking API",
        Version = "v1",
        Description = "API para ranking CS 1.6 - UltimateStats"
    });

    // Include XML comments if file exists
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath))
        c.IncludeXmlComments(xmlPath);
});

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// Add HttpClient for external calls
builder.Services.AddHttpClient();

// Configure database connection (MySQL)
// In production, use environment variables or secure config
builder.Services.Configure<DatabaseConfig>(builder.Configuration.GetSection("Database"));

// Add health checks
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "CS Ranking API v1");
        c.RoutePrefix = string.Empty; // Swagger UI at root
    });
}

app.UseCors("AllowAll");

app.UseAuthorization();

// Serve static files FIRST (index.html)
app.UseFileServer(new FileServerOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(
        Path.Combine(Directory.GetCurrentDirectory(), "wwwroot")),
    RequestPath = "",
    EnableDirectoryBrowsing = false,
    EnableDefaultFiles = true
});

app.UseStaticFiles();

app.MapControllers();

// Health check endpoint
app.MapHealthChecks("/health");

// Root endpoint
app.MapGet("/", () => Results.Ok(new
{
    service = "CS Ranking API",
    version = "1.0.0",
    status = "running",
    endpoints = new[]
    {
        "/api/players - Get ranking",
        "/api/players/{id} - Get player details",
        "/api/players/search?q= - Search players",
        "/api/players/top/{limit} - Get top players",
        "/swagger - API documentation",
        "/health - Health check"
    }
}));

app.Run();

// Database configuration class
public class DatabaseConfig
{
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 3306;
    public string Database { get; set; } = "ultimate_stats";
    public string Username { get; set; } = "ultimate_stats";
    public string Password { get; set; } = string.Empty;
}