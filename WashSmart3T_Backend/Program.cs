using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using WashSmart.API.Data;
using WashSmart.API.Middleware;

var builder = WebApplication.CreateBuilder(args);

// ============================================================
// BẢO MẬT CORS: Không dùng AllowAnyOrigin() vô hạn định.
// Cho phép các máy trạm Web Admin, Flutter Web trên localhost/127.0.0.1
// ============================================================
builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterPolicy", policy =>
    {
        policy
            .SetIsOriginAllowed(origin =>
            {
                if (string.IsNullOrWhiteSpace(origin)) return false;
                if (Uri.TryCreate(origin, UriKind.Absolute, out var uri))
                {
                    return uri.Host.Equals("localhost", StringComparison.OrdinalIgnoreCase) ||
                           uri.Host.Equals("127.0.0.1", StringComparison.OrdinalIgnoreCase);
                }
                return false;
            })
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(
        Environment.GetEnvironmentVariable("DB_CONNECTION_STRING") ??
        builder.Configuration.GetConnectionString("DefaultConnection")
    ));

// ============================================================
// BẢO MẬT JWT AUTHENTICATION
// Hỗ trợ lấy khóa bí mật từ biến môi trường JWT_SECRET_KEY
// ============================================================
var jwtSecret = Environment.GetEnvironmentVariable("JWT_SECRET_KEY") ??
                builder.Configuration["Jwt:Key"] ??
                "WashSmart3T_SuperSecretKey_2026_VeryLongKey_DefaultFallbackForSecurityCheck";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.RequireHttpsMetadata = false;
        options.SaveToken = true;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ClockSkew = TimeSpan.FromMinutes(1), // Giới hạn độ lệch thời gian chặt chẽ

            ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "WashSmart.API",
            ValidAudience = builder.Configuration["Jwt:Audience"] ?? "WashSmart.Client",

            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtSecret)
            )
        };
    });

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.Models.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.Models.SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.Models.ParameterLocation.Header,
        Description = "Nhập JWT token theo định dạng: Bearer {token}"
    });

    options.AddSecurityRequirement(new Microsoft.OpenApi.Models.OpenApiSecurityRequirement
    {
        {
            new Microsoft.OpenApi.Models.OpenApiSecurityScheme
            {
                Reference = new Microsoft.OpenApi.Models.OpenApiReference
                {
                    Type = Microsoft.OpenApi.Models.ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider
        .GetRequiredService<ApplicationDbContext>();

    await DbSeeder.SeedAsync(context);
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseCors("FlutterPolicy");

app.UseAuthentication();
app.UseAuthorization();

// Middleware kiểm tra trạng thái IsActive của người dùng tại thời gian thực
// Ngay khi tài khoản bị khóa trong DB, mọi token hiện hữu lập tức bị từ chối
app.UseMiddleware<SecurityValidationMiddleware>();

app.MapControllers();

app.Run();
