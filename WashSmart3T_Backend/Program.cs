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

        // Cho phép SignalR đọc JWT token từ query string `access_token`
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

// Add services to the container.
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(new UtcDateTimeJsonConverter());
        options.JsonSerializerOptions.Converters.Add(new NullableUtcDateTimeJsonConverter());
    });
builder.Services.AddSignalR();
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

// 🚀 BẬT CORS TRƯỚC STATIC FILES ĐỂ TRÌNH DUYỆT / FLUTTER WEB LOAD ĐƯỢC ẢNH MINH CHỨNG
app.UseCors("FlutterPolicy");

app.UseStaticFiles(new StaticFileOptions
{
    OnPrepareResponse = ctx =>
    {
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Origin", "*");
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Headers", "*");
        ctx.Context.Response.Headers.Append("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS");
    }
});

app.UseAuthentication();
app.UseAuthorization();

// Middleware kiểm tra trạng thái IsActive của người dùng tại thời gian thực
// Ngay khi tài khoản bị khóa trong DB, mọi token hiện hữu lập tức bị từ chối
app.UseMiddleware<SecurityValidationMiddleware>();

app.MapControllers();
app.MapHub<WashSmart.API.Hubs.OrderNotificationHub>("/hubs/orders");

// Endpoint trang chủ: Chuyển hướng thân thiện sang Web Portal 5500 để tránh lỗi HTTP 404
app.MapGet("/", () => Results.Content(
    @"<!DOCTYPE html>
<html lang=""vi"">
<head>
    <meta charset=""utf-8"">
    <title>WashSmart 3T - Máy Chủ API</title>
    <meta http-equiv=""refresh"" content=""1;url=http://localhost:5500/"">
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #fafafa; color: #333; }
        .card { background: white; padding: 40px; border-radius: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.08); text-align: center; max-width: 520px; }
        h1 { color: #881337; margin-top: 0; font-size: 24px; }
        p { color: #555; font-size: 15px; line-height: 1.6; }
        .btn { display: inline-block; margin-top: 15px; padding: 12px 24px; background: #881337; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; transition: background 0.2s; }
        .btn:hover { background: #9f1239; }
        .badge { display: inline-block; background: #dcfce7; color: #166534; padding: 4px 14px; border-radius: 999px; font-size: 13px; font-weight: 600; margin-bottom: 12px; }
    </style>
</head>
<body>
    <div class=""card"">
        <span class=""badge"">● Backend API Đang Hoạt Động (Port 5085)</span>
        <h1>WashSmart 3T - Máy Chủ Dịch Vụ API</h1>
        <p>Cổng 5085 là máy chủ API (.NET Core Backend). Đang tự động chuyển hướng bạn đến <strong>Cổng Quản Lý Web Portal (Port 5500)</strong> trong giây lát...</p>
        <a class=""btn"" href=""http://localhost:5500/"">Mở Web Quản Lý (Port 5500)</a>
        <br><br>
        <small style=""color: #888;"">Tài liệu API Swagger: <a href=""/swagger"" style=""color: #881337; font-weight: 600;"">/swagger</a></small>
    </div>
</body>
</html>",
    "text/html"
));

app.Run();

public class UtcDateTimeJsonConverter : System.Text.Json.Serialization.JsonConverter<DateTime>
{
    public override DateTime Read(ref System.Text.Json.Utf8JsonReader reader, Type typeToConvert, System.Text.Json.JsonSerializerOptions options)
    {
        var dt = reader.GetDateTime();
        return dt.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(dt, DateTimeKind.Utc) : dt.ToUniversalTime();
    }

    public override void Write(System.Text.Json.Utf8JsonWriter writer, DateTime value, System.Text.Json.JsonSerializerOptions options)
    {
        var utc = value.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(value, DateTimeKind.Utc)
            : value.ToUniversalTime();
        writer.WriteStringValue(utc.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"));
    }
}

public class NullableUtcDateTimeJsonConverter : System.Text.Json.Serialization.JsonConverter<DateTime?>
{
    public override DateTime? Read(ref System.Text.Json.Utf8JsonReader reader, Type typeToConvert, System.Text.Json.JsonSerializerOptions options)
    {
        if (reader.TokenType == System.Text.Json.JsonTokenType.Null) return null;
        var dt = reader.GetDateTime();
        return dt.Kind == DateTimeKind.Unspecified ? DateTime.SpecifyKind(dt, DateTimeKind.Utc) : dt.ToUniversalTime();
    }

    public override void Write(System.Text.Json.Utf8JsonWriter writer, DateTime? value, System.Text.Json.JsonSerializerOptions options)
    {
        if (!value.HasValue)
        {
            writer.WriteNullValue();
            return;
        }

        var utc = value.Value.Kind == DateTimeKind.Unspecified
            ? DateTime.SpecifyKind(value.Value, DateTimeKind.Utc)
            : value.Value.ToUniversalTime();
        writer.WriteStringValue(utc.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"));
    }
}
