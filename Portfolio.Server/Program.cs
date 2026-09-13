var builder = WebApplication.CreateBuilder(args);
builder.Services.AddCors();
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new Microsoft.OpenApi.OpenApiInfo
    {
        Title = "Portfolio API",
        Version = "v1"
    });
});
builder.Logging.AddFile(builder.Configuration.GetSection("Logging"));

var app = builder.Build();
app.UseDefaultFiles();
app.MapStaticAssets();
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.DocumentTitle = "Swagger UI - Portfolio";
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Portfolio API V1");
    });
}
app.UseHttpsRedirection();
app.UseCors(b => b.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod());
app.MapControllers();
app.MapFallbackToFile("/index.html");
app.Run();
