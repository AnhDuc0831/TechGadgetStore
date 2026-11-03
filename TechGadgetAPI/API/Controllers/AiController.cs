using BusinessObjects.DTOs;
using Microsoft.AspNetCore.Mvc;
using Services.Interfaces;
using System.Text;
using System.Text.Json;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AiController : ControllerBase
{
    private readonly ICategoryService _categoryService;
    private readonly IBrandService _brandService;
    private readonly IProductService _productService;
    private readonly IDashboardService _dashboardService;
    private readonly IOrderService _orderService;
    private readonly IConfiguration _config;
    private readonly ILogger<AiController> _logger;
    private static readonly HttpClient _httpClient = new() { Timeout = TimeSpan.FromSeconds(25) };

    private static readonly string[] CandidateModels = ["gemini-flash-lite-latest", "gemini-3.5-flash-lite", "gemini-flash-latest"];

    public AiController(
        ICategoryService categoryService,
        IBrandService brandService,
        IProductService productService,
        IDashboardService dashboardService,
        IOrderService orderService,
        IConfiguration config,
        ILogger<AiController> logger)
    {
        _categoryService = categoryService;
        _brandService = brandService;
        _productService = productService;
        _dashboardService = dashboardService;
        _orderService = orderService;
        _config = config;
        _logger = logger;
    }

    private string GeminiApiKey =>
        _config["Gemini:ApiKey"]
        ?? _config["GEMINI_API_KEY"]
        ?? Environment.GetEnvironmentVariable("GEMINI_API_KEY")
        ?? "";

    private string ConfiguredModel =>
        _config["Gemini:Model"]
        ?? _config["GEMINI_MODEL"]
        ?? "gemini-flash-lite-latest";

    private bool IsConfigured => !string.IsNullOrWhiteSpace(GeminiApiKey) && GeminiApiKey != "API_KEY" && !GeminiApiKey.StartsWith("YOUR_");

    /// <summary>
    /// Kiểm tra trạng thái lõi Google Gemini AI
    /// </summary>
    [HttpGet("status")]
    public IActionResult GetStatus()
    {
        return Ok(new AiStatusResponse(
            Configured: IsConfigured,
            Model: ConfiguredModel,
            Message: IsConfigured
                ? "Trợ lý TechGadget AI đã sẵn sàng hỗ trợ khách hàng và quản trị viên."
                : "Chưa cấu hình API Key. Đang hoạt động ở chế độ trợ lý dự phòng thông minh nội bộ."));
    }

    /// <summary>
    /// Tự động soạn bài đăng sản phẩm cho Admin bằng Gemini AI (hoặc Smart Engine)
    /// </summary>
    [HttpPost("draft-product")]
    public async Task<IActionResult> DraftProduct([FromBody] DraftProductRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request?.Prompt))
        {
            return BadRequest(new { message = "Yêu cầu sản phẩm không được để trống." });
        }

        var categories = await _categoryService.GetAllCategoriesAsync();
        var brands = await _brandService.GetAllBrandsAsync();

        if (IsConfigured)
        {
            try
            {
                var geminiDraft = await GenerateWithGeminiAsync(request.Prompt, categories, brands, ct);
                if (geminiDraft != null)
                {
                    return Ok(geminiDraft);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Gemini call failed. Falling back to local smart engine.");
            }
        }

        var localDraft = GenerateLocalSmartDraft(request.Prompt, categories, brands);
        return Ok(localDraft);
    }

    /// <summary>
    /// Chatbot AI tư vấn thông minh phân tách vai trò:
    /// - Role "customer": Tư vấn bán hàng, gợi ý sản phẩm, so sánh cấu hình, chính sách.
    /// - Role "admin": Đọc trực tiếp Database để báo cáo thống kê doanh thu, đơn hàng, tồn kho, phân tích số liệu kinh doanh hoặc soạn bài đăng.
    /// </summary>
    [HttpPost("chat")]
    public async Task<IActionResult> Chat([FromBody] AiChatRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request?.Message))
        {
            return BadRequest(new { message = "Tin nhắn không được để trống." });
        }

        var role = request.Role?.Trim().ToLowerInvariant() ?? "customer";
        var categories = await _categoryService.GetAllCategoriesAsync();
        var brands = await _brandService.GetAllBrandsAsync();

        // 1. Phân nhánh cho vai trò ADMIN (Đọc Database thống kê, phân tích kinh doanh hoặc tạo bài)
        if (role == "admin")
        {
            return await HandleAdminChat(request, categories, brands, ct);
        }

        // 2. Phân nhánh cho vai trò KHÁCH HÀNG (Tư vấn bán hàng, giới thiệu sản phẩm)
        return await HandleCustomerChat(request, categories, brands, ct);
    }

    private async Task<IActionResult> HandleCustomerChat(
        AiChatRequest request,
        List<CategoryDto> categories,
        List<BrandDto> brands,
        CancellationToken ct)
    {
        List<ProductListItemDto> availableProducts = [];
        try
        {
            var paged = await _productService.GetProductsAsync(new ProductQueryParams { Page = 1, PageSize = 40 });
            availableProducts = paged.Items.Where(p => p.IsActive).ToList();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to load products for AI context.");
        }

        ProductDetailDto? focusedProduct = null;
        if (!string.IsNullOrWhiteSpace(request.ProductId) && Guid.TryParse(request.ProductId, out var pid))
        {
            try
            {
                focusedProduct = await _productService.GetProductByIdAsync(pid);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to load focused product {ProductId}", request.ProductId);
            }
        }

        string? geminiError = null;

        if (IsConfigured)
        {
            try
            {
                var geminiRes = await ConsultCustomerWithGeminiAsync(
                    request.Message,
                    availableProducts,
                    categories,
                    brands,
                    focusedProduct,
                    request.History,
                    ct);

                if (geminiRes != null)
                {
                    return Ok(geminiRes);
                }
            }
            catch (Exception ex)
            {
                geminiError = ex.Message;
                _logger.LogWarning(ex, "Lỗi khi gọi Gemini tư vấn khách hàng: {Message}. Kích hoạt chế độ dự phòng thông minh.", ex.Message);
            }
        }

        var fallbackResponse = GenerateLocalSmartCustomerAdvisory(
            request.Message,
            availableProducts,
            categories,
            brands,
            focusedProduct);

        if (!string.IsNullOrEmpty(geminiError))
        {
            fallbackResponse.ErrorDetail = "Hệ thống AI đang bận. Đã chuyển sang chế độ tư vấn dự phòng thông minh.";
        }

        return Ok(fallbackResponse);
    }

    private async Task<IActionResult> HandleAdminChat(
        AiChatRequest request,
        List<CategoryDto> categories,
        List<BrandDto> brands,
        CancellationToken ct)
    {
        var lower = request.Message.ToLowerInvariant();

        // 1. Nhận diện kỳ thời gian mà Admin hỏi từ câu hỏi
        string period = "30days";
        if (lower.Contains("hôm nay") || lower.Contains("today"))
            period = "today";
        else if (lower.Contains("7 ngày") || lower.Contains("tuần") || lower.Contains("week"))
            period = "7days";
        else if (lower.Contains("tháng này") || lower.Contains("tháng") || lower.Contains("month"))
            period = "this_month";
        else if (lower.Contains("tất cả") || lower.Contains("toàn bộ") || lower.Contains("all"))
            period = "all";

        // 2. ĐỌC DỮ LIỆU THỰC TẾ TRỰC TIẾP TỪ DATABASE QUA DASHBOARD SERVICE & ORDER SERVICE
        DashboardOverviewDto? overview = null;
        try
        {
            overview = await _dashboardService.GetOverviewAsync(new DashboardQueryParams
            {
                Period = period,
                TopProductsLimit = 5,
                LowStockThreshold = 5
            });
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to load dashboard overview for Admin AI chat.");
        }

        List<AdminOrderDto> recentOrders = [];
        try
        {
            var ordersPaged = await _orderService.GetAdminOrdersAsync(1, 6, null);
            recentOrders = ordersPaged.Items;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to load recent orders for Admin AI chat.");
        }

        // Tạo Snapshot thống kê
        DashboardSnapshotDto? snapshot = null;
        if (overview != null)
        {
            snapshot = new DashboardSnapshotDto
            {
                Period = period,
                TotalRevenue = overview.Summary.TotalRevenue,
                TotalProfit = overview.Summary.TotalProfit,
                ProfitMarginPercentage = overview.Summary.ProfitMarginPercentage,
                TotalOrders = overview.Summary.TotalOrders,
                DeliveredOrders = overview.Summary.DeliveredOrders,
                PendingOrders = overview.Summary.PendingOrders,
                CancelledOrders = overview.Summary.CancelledOrders,
                TotalProducts = overview.Summary.TotalProducts,
                LowStockProductsCount = overview.Summary.LowStockProductsCount,
                OutOfStockProductsCount = overview.Summary.OutOfStockProductsCount,
                TopSellingProducts = overview.TopSellingProducts.Select(t => new TopProductSnapshotDto
                {
                    Name = t.ProductName,
                    UnitsSold = t.UnitsSold,
                    Revenue = t.TotalRevenue
                }).ToList(),
                LowStockAlerts = overview.LowStockAlerts.Select(l => new LowStockSnapshotDto
                {
                    Name = l.ProductName,
                    Sku = l.Sku,
                    Stock = l.StockQuantity
                }).ToList()
            };
        }

        // 3. Thử phân tích dữ liệu qua Gemini AI nếu đã cấu hình
        if (IsConfigured)
        {
            try
            {
                var geminiRes = await ConsultAdminAnalyticsWithGeminiAsync(
                    request.Message,
                    overview,
                    recentOrders,
                    categories,
                    brands,
                    snapshot,
                    ct);

                if (geminiRes != null)
                {
                    return Ok(geminiRes);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Gemini admin chat failed: {Message}. Kích hoạt chế độ phân tích dự phòng từ Database.", ex.Message);
            }
        }

        // 4. Fallback thông minh: Đọc các chỉ số DB thực tế và sinh báo cáo quản trị đầy đủ
        var fallbackResponse = GenerateLocalSmartAdminAnalytics(
            request.Message,
            overview,
            recentOrders,
            categories,
            brands,
            snapshot);

        return Ok(fallbackResponse);
    }

    private async Task<AiChatResponseDto?> ConsultAdminAnalyticsWithGeminiAsync(
        string message,
        DashboardOverviewDto? overview,
        List<AdminOrderDto> recentOrders,
        List<CategoryDto> categories,
        List<BrandDto> brands,
        DashboardSnapshotDto? snapshot,
        CancellationToken ct)
    {
        var dbSummary = new StringBuilder();
        if (overview != null)
        {
            dbSummary.AppendLine($"=== DỮ LIỆU THỰC TẾ TRUY VẤN TRỰC TIẾP TỪ DATABASE TECHGADGET STORE (KỲ: {overview.Summary.Period}) ===");
            dbSummary.AppendLine($"- Doanh thu thực tế: {overview.Summary.TotalRevenue:N0} VNĐ");
            dbSummary.AppendLine($"- Lợi nhuận gộp: {overview.Summary.TotalProfit:N0} VNĐ");
            dbSummary.AppendLine($"- Tỷ suất lợi nhuận: {overview.Summary.ProfitMarginPercentage:F1}%");
            dbSummary.AppendLine($"- Tổng số đơn hàng: {overview.Summary.TotalOrders} đơn (Giao thành công: {overview.Summary.DeliveredOrders}, Đang chờ duyệt/xử lý: {overview.Summary.PendingOrders}, Đã hủy: {overview.Summary.CancelledOrders})");
            dbSummary.AppendLine($"- Tổng số sản phẩm trong CSDL: {overview.Summary.TotalProducts} sản phẩm");
            dbSummary.AppendLine($"- Tình trạng kho: {overview.Summary.LowStockProductsCount} sản phẩm sắp hết hàng (tồn <= 5), {overview.Summary.OutOfStockProductsCount} sản phẩm đã hết hàng");

            if (overview.TopSellingProducts.Count > 0)
            {
                dbSummary.AppendLine("\nTop sản phẩm bán chạy nhất trong CSDL:");
                foreach (var top in overview.TopSellingProducts.Take(5))
                {
                    dbSummary.AppendLine($"  • {top.ProductName} - Đã bán: {top.UnitsSold} cái | Doanh thu: {top.TotalRevenue:N0}đ");
                }
            }

            if (overview.LowStockAlerts.Count > 0)
            {
                dbSummary.AppendLine("\nCảnh báo tồn kho thấp (Cần nhập thêm):");
                foreach (var low in overview.LowStockAlerts.Take(5))
                {
                    dbSummary.AppendLine($"  ⚠️ {low.ProductName} ({low.Sku}) - Tồn kho chỉ còn: {low.StockQuantity} cái");
                }
            }
        }

        if (recentOrders.Count > 0)
        {
            dbSummary.AppendLine("\nCác đơn hàng mới nhất trong hệ thống:");
            foreach (var o in recentOrders.Take(5))
            {
                var code = o.PayOSOrderCode?.ToString() ?? o.Id.ToString()[..8];
                dbSummary.AppendLine($"  • [Đơn #{code}] Khách: {o.ShippingName ?? "Khách hàng"} | Trạng thái: {o.Status} | TT: {o.PaymentStatus} | Tổng: {o.TotalAmount:N0}đ");
            }
        }

        var systemPrompt = $@"
Bạn là Trợ lý AI Cố vấn Quản trị & Phân tích Dữ liệu Kinh doanh (Business Intelligence AI) của TechGadget Store dành riêng cho Quản trị viên (Admin).
Dữ liệu dưới đây được đọc TRỰC TIẾP và CHÍNH XÁC từ Database của hệ thống:

{dbSummary}

Câu hỏi của Quản trị viên: ""{message}""

NHIỆM VỤ CỦA BẠN:
1. Đọc kỹ và trích xuất đúng các con số thực tế từ Database ở trên để trả lời câu hỏi của Admin.
2. Trả lời chuyên nghiệp, sắc bén, định dạng Markdown đẹp mắt (dùng emoji, bullet points, in đậm số tiền, phần trăm).
3. Đưa ra nhận xét, đánh giá tình hình kinh doanh (doanh số, tỷ lệ hủy đơn, sản phẩm bán chạy, rủi ro hết hàng kho...).
4. Đề xuất hành động chiến lược thiết thực cho Admin (ví dụ: cần xử lý đơn chờ duyệt, kế hoạch nhập thêm hàng nào, giải pháp kích cầu...).
5. Nếu Admin có ý định muốn đăng bài bán sản phẩm mới (chứa từ khóa 'viết bài' hoặc 'đăng sản phẩm'): Hãy tạo thêm 'productDraft' tương ứng.

TRẢ VỀ DUY NHẤT CHUỖI JSON HỢP LỆ (KHÔNG DÙNG MARKDOWN BAO NGOÀI JSON):
{{
  ""reply"": ""Câu trả lời phân tích số liệu chi tiết bằng tiếng Việt..."",
  ""productDraft"": null
}}";

        var modelsToTry = new List<string>();
        if (!string.IsNullOrWhiteSpace(ConfiguredModel)) modelsToTry.Add(ConfiguredModel);
        foreach (var m in CandidateModels)
        {
            if (!modelsToTry.Contains(m)) modelsToTry.Add(m);
        }

        foreach (var model in modelsToTry)
        {
            try
            {
                var url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GeminiApiKey}";
                var payload = new
                {
                    contents = new[] { new { parts = new[] { new { text = systemPrompt } } } },
                    generationConfig = new { temperature = 0.25, maxOutputTokens = 2048 }
                };

                var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
                var response = await _httpClient.PostAsync(url, content, ct);

                if (response.IsSuccessStatusCode)
                {
                    var resJson = await response.Content.ReadAsStringAsync(ct);
                    using var doc = JsonDocument.Parse(resJson);
                    var candidates = doc.RootElement.GetProperty("candidates");
                    if (candidates.GetArrayLength() > 0)
                    {
                        var text = candidates[0].GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString();
                        if (!string.IsNullOrWhiteSpace(text))
                        {
                            var clean = CleanJson(text);
                            using var parsed = JsonDocument.Parse(clean);
                            var reply = parsed.RootElement.GetProperty("reply").GetString() ?? "";

                            ProductDraftDto? draft = null;
                            if (parsed.RootElement.TryGetProperty("productDraft", out var draftElem) && draftElem.ValueKind == JsonValueKind.Object)
                            {
                                draft = JsonSerializer.Deserialize<ProductDraftDto>(draftElem.GetRawText(), new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                            }

                            return new AiChatResponseDto
                            {
                                Reply = reply,
                                ProductDraft = draft,
                                DashboardSnapshot = snapshot,
                                IsConfigured = true,
                                Source = "TechGadget AI",
                                IsFallback = false
                            };
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Gemini attempt with model {Model} for admin analytics failed", model);
            }
        }

        return null;
    }

    private AiChatResponseDto GenerateLocalSmartAdminAnalytics(
        string message,
        DashboardOverviewDto? overview,
        List<AdminOrderDto> recentOrders,
        List<CategoryDto> categories,
        List<BrandDto> brands,
        DashboardSnapshotDto? snapshot)
    {
        var lower = message.ToLowerInvariant();
        var replyBuilder = new StringBuilder();

        // 1. Kiểm tra ý định tạo bài đăng sản phẩm
        var isDraftIntent = lower.Contains("viết bài") || lower.Contains("tạo bài") || lower.Contains("đăng sản phẩm");
        if (isDraftIntent)
        {
            var clean = message.Replace("viết bài:", "").Replace("Viết bài:", "").Trim();
            var draft = GenerateLocalSmartDraft(clean, categories, brands);
            return new AiChatResponseDto
            {
                Reply = $"Tôi đã phân tích yêu cầu và soạn sẵn nội dung bài đăng cho **{draft.Name}**!\n\nNhấn nút **'Áp dụng vào Đăng sản phẩm ngay'** bên dưới để tự động điền form nhé.",
                ProductDraft = draft,
                DashboardSnapshot = snapshot,
                IsConfigured = IsConfigured,
                Source = "TechGadget AI",
                IsFallback = true
            };
        }

        // 2. Báo cáo thống kê đọc từ Database
        if (overview != null)
        {
            var s = overview.Summary;
            replyBuilder.AppendLine($"📊 **BÁO CÁO THỐNG KÊ KINH DOANH TỪ CSDL (Kỳ: {s.Period})**\n");

            if (lower.Contains("doanh thu") || lower.Contains("lợi nhuận") || lower.Contains("tiền"))
            {
                replyBuilder.AppendLine($"💰 **Chỉ số Tài chính:**");
                replyBuilder.AppendLine($"• **Tổng doanh thu thực tế:** **{s.TotalRevenue:N0}₫**");
                replyBuilder.AppendLine($"• **Lợi nhuận gộp:** **{s.TotalProfit:N0}₫**");
                replyBuilder.AppendLine($"• **Biên lợi nhuận:** **{s.ProfitMarginPercentage:F1}%**");
                replyBuilder.AppendLine(s.TotalRevenue > 0
                    ? "\n💡 *Đánh giá:* Doanh thu duy trì ổn định. Biên lợi nhuận ở mức tốt trong ngành hàng thiết bị công nghệ."
                    : "\n💡 *Lưu ý:* Chưa ghi nhận doanh thu hoàn tất trong kỳ này.");
            }
            else if (lower.Contains("đơn hàng") || lower.Contains("đơn") || lower.Contains("order"))
            {
                replyBuilder.AppendLine($"📦 **Tình hình Đơn hàng:**");
                replyBuilder.AppendLine($"• **Tổng đơn hàng ghi nhận:** **{s.TotalOrders} đơn**");
                replyBuilder.AppendLine($"• **Đã giao thành công:** **{s.DeliveredOrders} đơn**");
                replyBuilder.AppendLine($"• **Đang chờ duyệt xử lý:** **{s.PendingOrders} đơn** ⚠️");
                replyBuilder.AppendLine($"• **Đã hủy:** **{s.CancelledOrders} đơn**");

                if (recentOrders.Count > 0)
                {
                    replyBuilder.AppendLine("\n📋 **Đơn hàng mới nhất:**");
                    foreach (var o in recentOrders.Take(3))
                    {
                        var code = o.PayOSOrderCode?.ToString() ?? o.Id.ToString()[..8];
                        replyBuilder.AppendLine($"• Đơn #{code}: {o.TotalAmount:N0}₫ ({o.Status}) - {o.ShippingName ?? "Khách hàng"}");
                    }
                }
            }
            else if (lower.Contains("bán chạy") || lower.Contains("top") || lower.Contains("hot"))
            {
                replyBuilder.AppendLine($"🔥 **Top Sản Phẩm Bán Chạy Nhất (CSDL):**");
                if (overview.TopSellingProducts.Count > 0)
                {
                    for (int i = 0; i < overview.TopSellingProducts.Count; i++)
                    {
                        var top = overview.TopSellingProducts[i];
                        replyBuilder.AppendLine($"{i + 1}. **{top.ProductName}**");
                        replyBuilder.AppendLine($"   • Số lượng bán: **{top.UnitsSold}** cái | Doanh thu: **{top.TotalRevenue:N0}₫**");
                    }
                }
                else
                {
                    replyBuilder.AppendLine("• Chưa có dữ liệu phát sinh đơn bán cho các sản phẩm trong kỳ này.");
                }
            }
            else if (lower.Contains("tồn kho") || lower.Contains("hết hàng") || lower.Contains("kho"))
            {
                replyBuilder.AppendLine($"⚠️ **Cảnh Báo Tồn Kho CSDL:**");
                replyBuilder.AppendLine($"• Tổng sản phẩm trong kho: **{s.TotalProducts}**");
                replyBuilder.AppendLine($"• Sản phẩm sắp hết hàng (tồn <= 5): **{s.LowStockProductsCount}**");
                replyBuilder.AppendLine($"• Sản phẩm đã hết sạch hàng: **{s.OutOfStockProductsCount}**");

                if (overview.LowStockAlerts.Count > 0)
                {
                    replyBuilder.AppendLine("\nDanh sách cần ưu tiên nhập thêm:");
                    foreach (var low in overview.LowStockAlerts.Take(4))
                    {
                        replyBuilder.AppendLine($"• **{low.ProductName}** ({low.Sku}): còn **{low.StockQuantity}** sản phẩm");
                    }
                }
            }
            else
            {
                // Tổng quan tất cả
                replyBuilder.AppendLine($"✨ **Tổng quan Toàn Cửa hàng:**");
                replyBuilder.AppendLine($"• 💰 Doanh thu: **{s.TotalRevenue:N0}₫** | Lợi nhuận: **{s.TotalProfit:N0}₫** ({s.ProfitMarginPercentage:F1}%)");
                replyBuilder.AppendLine($"• 📦 Đơn hàng: **{s.TotalOrders} đơn** (Chờ duyệt: **{s.PendingOrders}**, Đã giao: **{s.DeliveredOrders}**)");
                replyBuilder.AppendLine($"• 🏪 Kho hàng: **{s.TotalProducts}** sản phẩm (Cảnh báo tồn thấp: **{s.LowStockProductsCount}**)");

                if (overview.TopSellingProducts.Count > 0)
                {
                    var top1 = overview.TopSellingProducts[0];
                    replyBuilder.AppendLine($"• 🏆 Sản phẩm bán chạy nhất: **{top1.ProductName}** ({top1.UnitsSold} đã bán)");
                }

                replyBuilder.AppendLine("\n💡 *Gợi ý cho Quản trị viên:*");
                if (s.PendingOrders > 0)
                    replyBuilder.AppendLine($"• Có **{s.PendingOrders} đơn hàng** đang chờ duyệt xử lý để giao cho khách kịp thời.");
                if (s.LowStockProductsCount > 0)
                    replyBuilder.AppendLine($"• Có **{s.LowStockProductsCount} mặt hàng** tồn kho dưới 5, nên liên hệ nhà cung cấp nhập đợt mới.");
            }
        }
        else
        {
            replyBuilder.AppendLine("Xin chào Quản trị viên! Tôi là **Trợ lý AI Phân tích Dữ liệu CSDL** của TechGadget Store.");
            replyBuilder.AppendLine("Tôi có thể đọc dữ liệu trực tiếp từ CSDL để báo cáo:");
            replyBuilder.AppendLine("• Doanh thu, lợi nhuận thực tế theo ngày / tuần / tháng");
            replyBuilder.AppendLine("• Tình hình đơn hàng & tỷ lệ hoàn thành");
            replyBuilder.AppendLine("• Top sản phẩm bán chạy nhất và cảnh báo tồn kho");
            replyBuilder.AppendLine("\nBạn muốn kiểm tra chỉ số thống kê nào hôm nay?");
        }

        return new AiChatResponseDto
        {
            Reply = replyBuilder.ToString().Trim(),
            DashboardSnapshot = snapshot,
            IsConfigured = IsConfigured,
            Source = "TechGadget AI",
            IsFallback = true
        };
    }

    private async Task<AiChatResponseDto?> ConsultCustomerWithGeminiAsync(
        string message,
        List<ProductListItemDto> products,
        List<CategoryDto> categories,
        List<BrandDto> brands,
        ProductDetailDto? focusedProduct,
        List<ChatMessageDto>? history,
        CancellationToken ct)
    {
        var categoryList = string.Join(", ", categories.Select(c => c.Name));
        var brandList = string.Join(", ", brands.Select(b => b.Name));

        var productCatalogSummary = new StringBuilder();
        foreach (var p in products.Take(25))
        {
            var priceStr = p.DiscountPrice.HasValue
                ? $"{p.DiscountPrice.Value:N0}đ (gốc {p.BasePrice:N0}đ)"
                : $"{p.BasePrice:N0}đ";
            productCatalogSummary.AppendLine($"- [ID: {p.Id}] {p.Name} | Hãng: {p.Brand?.Name} | Loại: {p.Category?.Name} | Giá: {priceStr} | Tồn: {p.TotalStockQuantity}");
        }

        var focusedProductInfo = focusedProduct != null
            ? $@"Sản phẩm khách hàng đang xem trên màn hình:
- Tên: {focusedProduct.Name}
- Giá: {(focusedProduct.DiscountPrice.HasValue ? $"{focusedProduct.DiscountPrice:N0}đ (giảm từ {focusedProduct.BasePrice:N0}đ)" : $"{focusedProduct.BasePrice:N0}đ")}
- Thương hiệu: {focusedProduct.Brand?.Name}
- Mô tả tóm tắt: {focusedProduct.Description}
- Thông số kỹ thuật: {JsonSerializer.Serialize(focusedProduct.Specifications)}"
            : "Khách hàng đang duyệt chung tại cửa hàng.";

        var historyContext = "";
        if (history != null && history.Count > 0)
        {
            var histLines = history.TakeLast(6).Select(h => $"{(h.Role == "user" ? "Khách hàng" : "AI Tư Vấn")}: {h.Content}");
            historyContext = "\nLịch sử hội thoại trước đó:\n" + string.Join("\n", histLines) + "\n";
        }

        var systemPrompt = $@"
Bạn là Trợ lý AI Tư vấn Bán hàng Cao cấp của TechGadget Store (cửa hàng công nghệ hàng đầu tại Việt Nam).
Mục tiêu của bạn:
1. Tư vấn lịch sự, tận tâm, thân thiện, xưng hô 'Dạ/Em' và 'Anh/Chị' hoặc 'Bạn'.
2. Trả lời chi tiết, dễ hiểu, dùng gạch đầu dòng Markdown rõ ràng, có emoji sinh động.
3. Nếu khách hàng hỏi về sản phẩm, cấu hình, nhu cầu (chơi game, văn phòng, chụp ảnh, ngân sách...):
   - Đưa ra lời khuyên khách quan, so sánh ưu nhược điểm.
   - GỢI Ý các sản phẩm phù hợp từ danh sách sản phẩm thật của TechGadget Store bên dưới.
4. Nếu khách hàng hỏi về chính sách cửa hàng:
   - Bảo hành: 12 - 24 tháng chính hãng, lỗi 1 đổi 1 trong 30 ngày đầu.
   - Thanh toán: Hỗ trợ chuyển khoản ngân hàng quét mã VietQR tự động (PayOS), thẻ ATM/Visa/MasterCard, hoặc thanh toán khi nhận hàng COD.
   - Giao hàng: Giao nhanh toàn quốc, miễn phí vận chuyển cho đơn hàng từ 500.000đ.
5. Danh mục có sẵn: [{categoryList}]
6. Thương hiệu có sẵn: [{brandList}]

{focusedProductInfo}

Kho sản phẩm hiện có tại TechGadget Store:
{productCatalogSummary}
{historyContext}
Câu hỏi của khách hàng: ""{message}""

YÊU CẦU ĐỊNH DẠNG ĐẦU RA (TRẢ VỀ DUY NHẤT CHUỖI JSON HỢP LỆ, KHÔNG BỌC TRONG BẤT KỲ VĂN BẢN NGOÀI):
{{
  ""reply"": ""Câu tư vấn bằng tiếng Việt chuyên nghiệp, định dạng Markdown đẹp mắt..."",
  ""recommendedProductIds"": [""<Guid-id-1>"", ""<Guid-id-2>""]
}}
(Lưu ý: Chỉ đưa ID của sản phẩm nếu nó có trong danh sách kho sản phẩm ở trên và thực sự phù hợp với câu hỏi).";

        var modelsToTry = new List<string>();
        if (!string.IsNullOrWhiteSpace(ConfiguredModel)) modelsToTry.Add(ConfiguredModel);
        foreach (var m in CandidateModels)
        {
            if (!modelsToTry.Contains(m)) modelsToTry.Add(m);
        }

        foreach (var model in modelsToTry)
        {
            try
            {
                var url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GeminiApiKey}";
                var payload = new
                {
                    contents = new[] { new { parts = new[] { new { text = systemPrompt } } } },
                    generationConfig = new { temperature = 0.35, maxOutputTokens = 2048 }
                };

                var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
                var response = await _httpClient.PostAsync(url, content, ct);

                if (response.IsSuccessStatusCode)
                {
                    var resJson = await response.Content.ReadAsStringAsync(ct);
                    using var doc = JsonDocument.Parse(resJson);
                    var candidates = doc.RootElement.GetProperty("candidates");
                    if (candidates.GetArrayLength() > 0)
                    {
                        var text = candidates[0].GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString();
                        if (!string.IsNullOrWhiteSpace(text))
                        {
                            var clean = CleanJson(text);
                            using var parsed = JsonDocument.Parse(clean);
                            var reply = parsed.RootElement.GetProperty("reply").GetString() ?? "";

                            var recs = new List<ProductRecommendationDto>();
                            if (parsed.RootElement.TryGetProperty("recommendedProductIds", out var recIdsElem) && recIdsElem.ValueKind == JsonValueKind.Array)
                            {
                                foreach (var item in recIdsElem.EnumerateArray())
                                {
                                    var idStr = item.GetString();
                                    if (Guid.TryParse(idStr, out var idGuid))
                                    {
                                        var matched = products.FirstOrDefault(p => p.Id == idGuid);
                                        if (matched != null)
                                        {
                                            recs.Add(new ProductRecommendationDto
                                            {
                                                Id = matched.Id,
                                                Name = matched.Name,
                                                Slug = matched.Slug,
                                                BasePrice = matched.BasePrice,
                                                DiscountPrice = matched.DiscountPrice,
                                                ThumbnailUrl = matched.ThumbnailUrl,
                                                CategoryName = matched.Category?.Name ?? "",
                                                BrandName = matched.Brand?.Name ?? "",
                                                Reason = "Sản phẩm được gợi ý phù hợp nhất với nhu cầu"
                                            });
                                        }
                                    }
                                }
                            }

                            if (recs.Count == 0 && focusedProduct != null)
                            {
                                recs.Add(new ProductRecommendationDto
                                {
                                    Id = focusedProduct.Id,
                                    Name = focusedProduct.Name,
                                    Slug = focusedProduct.Slug,
                                    BasePrice = focusedProduct.BasePrice,
                                    DiscountPrice = focusedProduct.DiscountPrice,
                                    ThumbnailUrl = focusedProduct.ThumbnailUrl ?? focusedProduct.Images.FirstOrDefault(),
                                    CategoryName = focusedProduct.Category?.Name ?? "",
                                    BrandName = focusedProduct.Brand?.Name ?? "",
                                    Reason = "Sản phẩm bạn đang xem"
                                });
                            }

                            return new AiChatResponseDto
                            {
                                Reply = reply,
                                RecommendedProducts = recs,
                                IsConfigured = true,
                                Source = "TechGadget AI",
                                IsFallback = false
                            };
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Gemini attempt with model {Model} failed: {Message}", model, ex.Message);
            }
        }

        return null;
    }

    private AiChatResponseDto GenerateLocalSmartCustomerAdvisory(
        string message,
        List<ProductListItemDto> products,
        List<CategoryDto> categories,
        List<BrandDto> brands,
        ProductDetailDto? focusedProduct)
    {
        var lower = message.ToLowerInvariant();
        var recs = new List<ProductRecommendationDto>();
        var replyBuilder = new StringBuilder();

        if (lower.Contains("bảo hành") || lower.Contains("bao hanh") || lower.Contains("đổi trả") || lower.Contains("doi tra"))
        {
            replyBuilder.AppendLine("Dạ chào bạn! **Chính sách bảo hành & đổi trả tại TechGadget Store**:");
            replyBuilder.AppendLine("• **Bảo hành chính hãng:** 12 - 24 tháng đối với toàn bộ thiết bị mới nguyên seal.");
            replyBuilder.AppendLine("• **Chính sách 1 đổi 1:** Đổi máy mới miễn phí trong vòng **30 ngày đầu** nếu phát sinh lỗi phần cứng từ nhà sản xuất.");
            replyBuilder.AppendLine("• **Hỗ trợ trọn đời:** Hỗ trợ cài đặt phần mềm, vệ sinh máy và kiểm tra kỹ thuật hoàn toàn miễn phí tại cửa hàng.");
            replyBuilder.AppendLine("\nBạn có thể mang thiết bị đến cửa hàng hoặc gửi chuyển phát nhanh để được trung tâm bảo hành hỗ trợ nhanh nhất nhé!");
        }
        else if (lower.Contains("giao hàng") || lower.Contains("ship") || lower.Contains("vận chuyển") || lower.Contains("bao lau"))
        {
            replyBuilder.AppendLine("Dạ chào bạn! **Chính sách vận chuyển của TechGadget Store**:");
            replyBuilder.AppendLine("• **Giao hàng hỏa tốc:** 1 - 2 giờ trong khu vực nội thành.");
            replyBuilder.AppendLine("• **Giao hàng toàn quốc:** Từ 2 - 4 ngày làm việc qua đối tác vận chuyển uy tín.");
            replyBuilder.AppendLine("• **Miễn phí ship:** Đơn hàng từ **500.000đ** được freeship 100%.");
            replyBuilder.AppendLine("• **Kiểm tra hàng trước khi nhận:** Quý khách được đồng kiểm tra tem seal sản phẩm trước khi thanh toán.");
        }
        else if (lower.Contains("thanh toán") || lower.Contains("payos") || lower.Contains("cod") || lower.Contains("chuyển khoản") || lower.Contains("quet ma"))
        {
            replyBuilder.AppendLine("Dạ chào bạn! **TechGadget Store hỗ trợ đa dạng phương thức thanh toán an toàn tiện lợi**:");
            replyBuilder.AppendLine("• **Quét mã VietQR tự động qua PayOS:** Xác nhận thanh toán ngay lập tức không cần chụp màn hình chuyển khoản.");
            replyBuilder.AppendLine("• **Thanh toán khi nhận hàng (COD):** Nhận hàng, kiểm tra rồi mới thanh toán tiền mặt cho shipper.");
            replyBuilder.AppendLine("• **Thẻ tín dụng / Ghi nợ:** Visa, MasterCard, JCB.");
        }
        else
        {
            string categoryMatch = "";
            if (lower.Contains("iphone") || lower.Contains("điện thoại") || lower.Contains("smartphone") || lower.Contains("samsung") || lower.Contains("galaxy"))
            {
                categoryMatch = "smartphones";
            }
            else if (lower.Contains("laptop") || lower.Contains("macbook") || lower.Contains("máy tính") || lower.Contains("dell") || lower.Contains("asus"))
            {
                categoryMatch = "laptops";
            }
            else if (lower.Contains("tai nghe") || lower.Contains("loa") || lower.Contains("chuột") || lower.Contains("bàn phím") || lower.Contains("phụ kiện"))
            {
                categoryMatch = "accessories";
            }

            var matchedProducts = products.Where(p =>
            {
                if (!string.IsNullOrEmpty(categoryMatch) && !p.Category.Slug.Contains(categoryMatch) && !p.Category.Name.ToLower().Contains(categoryMatch))
                    return false;
                return true;
            }).ToList();

            if (matchedProducts.Count == 0)
            {
                matchedProducts = products.Take(4).ToList();
            }

            replyBuilder.AppendLine("Dạ chào bạn! Cảm ơn bạn đã quan tâm đến các sản phẩm công nghệ tại **TechGadget Store**! 🌟");
            replyBuilder.AppendLine("\nTôi đã phân tích nhu cầu của bạn và xin đề xuất những sự lựa chọn nổi bật, chất lượng với giá tốt nhất:");

            foreach (var p in matchedProducts.Take(3))
            {
                var priceStr = p.DiscountPrice.HasValue
                    ? $"**{p.DiscountPrice.Value:N0}₫** *(giá gốc {p.BasePrice:N0}₫)*"
                    : $"**{p.BasePrice:N0}₫**";

                replyBuilder.AppendLine($"\n🔹 **{p.Name}**");
                replyBuilder.AppendLine($"   • Giá ưu đãi: {priceStr}");
                replyBuilder.AppendLine($"   • Hãng: {p.Brand?.Name} | Đánh giá: {p.AverageRating:0.0}⭐");
                replyBuilder.AppendLine($"   • Tình trạng: {(p.InStock ? "Còn hàng sẵn tại shop" : "Sắp về đợt mới")}");

                recs.Add(new ProductRecommendationDto
                {
                    Id = p.Id,
                    Name = p.Name,
                    Slug = p.Slug,
                    BasePrice = p.BasePrice,
                    DiscountPrice = p.DiscountPrice,
                    ThumbnailUrl = p.ThumbnailUrl,
                    CategoryName = p.Category?.Name ?? "",
                    BrandName = p.Brand?.Name ?? "",
                    Reason = "Được chọn lọc theo tiêu chí tối ưu chi phí & hiệu năng tốt nhất"
                });
            }

            replyBuilder.AppendLine("\nBạn có thể nhấn vào thẻ sản phẩm bên dưới để xem hình ảnh thực tế và cấu hình chi tiết, hoặc cho tôi biết thêm mức ngân sách cụ thể để tôi gợi ý chính xác nhất nhé!");
        }

        if (focusedProduct != null && !recs.Any(r => r.Id == focusedProduct.Id))
        {
            recs.Insert(0, new ProductRecommendationDto
            {
                Id = focusedProduct.Id,
                Name = focusedProduct.Name,
                Slug = focusedProduct.Slug,
                BasePrice = focusedProduct.BasePrice,
                DiscountPrice = focusedProduct.DiscountPrice,
                ThumbnailUrl = focusedProduct.ThumbnailUrl ?? focusedProduct.Images.FirstOrDefault(),
                CategoryName = focusedProduct.Category?.Name ?? "",
                BrandName = focusedProduct.Brand?.Name ?? "",
                Reason = "Sản phẩm bạn đang xem trên màn hình"
            });
        }

        return new AiChatResponseDto
        {
            Reply = replyBuilder.ToString().Trim(),
            RecommendedProducts = recs,
            IsConfigured = IsConfigured,
            Source = "TechGadget AI",
            IsFallback = true
        };
    }

    private async Task<ProductDraftDto?> GenerateWithGeminiAsync(string userPrompt, List<CategoryDto> categories, List<BrandDto> brands, CancellationToken ct)
    {
        var categoryList = string.Join(", ", categories.Select(c => $"{c.Name} ({c.Slug})"));
        var brandList = string.Join(", ", brands.Select(b => b.Name));

        var prompt = $@"
Bạn là Trợ lý AI TechGadget Store chuyên hỗ trợ Quản trị viên (Admin) tạo bài đăng sản phẩm công nghệ.
Yêu cầu của Admin: ""{userPrompt}""

Danh mục có sẵn trong hệ thống: [{categoryList}]
Thương hiệu có sẵn trong hệ thống: [{brandList}]

NHIỆM VỤ:
1. Đọc và nhận diện chuẩn xác tên thiết bị, model, dung lượng, màu sắc.
2. Khớp đúng danh mục (categoryHint) và thương hiệu (brandHint) từ danh sách ở trên.
3. Ước tính giá gốc (basePrice) và giá khuyến mãi (discountPrice) VNĐ chuẩn thị trường Việt Nam.
4. Đặt tồn kho (stock: 10 - 50) và mã SKU (VD: TG-IP16PM-256G).
5. Viết bài mô tả (description) hấp dẫn, chuẩn SEO có emoji (thiết kế, hiệu năng, pin/sạc, bảo hành chính hãng).
6. Tạo bảng thông số kỹ thuật (specifications) dạng Dictionary JSON (man_hinh, cpu, ram, rom, pin, camera, trong_luong, bao_hanh...).

TRẢ VỀ DUY NHẤT CHUỖI JSON HỢP LỆ (KHÔNG DÙNG MARKDOWN):
{{
  ""name"": ""..."",
  ""categoryHint"": ""..."",
  ""brandHint"": ""..."",
  ""basePrice"": 34990000,
  ""discountPrice"": 32490000,
  ""stock"": 25,
  ""sku"": ""TG-IP16PM-256G"",
  ""description"": ""..."",
  ""specifications"": {{
    ""man_hinh"": ""..."",
    ""cpu"": ""..."",
    ""ram"": ""..."",
    ""pin"": ""...""
  }}
}}";

        var modelsToTry = new List<string>();
        if (!string.IsNullOrWhiteSpace(ConfiguredModel)) modelsToTry.Add(ConfiguredModel);
        foreach (var m in CandidateModels)
        {
            if (!modelsToTry.Contains(m)) modelsToTry.Add(m);
        }

        foreach (var model in modelsToTry)
        {
            try
            {
                var url = $"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={GeminiApiKey}";
                var payload = new
                {
                    contents = new[] { new { parts = new[] { new { text = prompt } } } },
                    generationConfig = new { temperature = 0.2, maxOutputTokens = 2048 }
                };

                var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
                var response = await _httpClient.PostAsync(url, content, ct);

                if (response.IsSuccessStatusCode)
                {
                    var resJson = await response.Content.ReadAsStringAsync(ct);
                    using var doc = JsonDocument.Parse(resJson);
                    var candidates = doc.RootElement.GetProperty("candidates");
                    if (candidates.GetArrayLength() > 0)
                    {
                        var text = candidates[0].GetProperty("content").GetProperty("parts")[0].GetProperty("text").GetString();
                        if (!string.IsNullOrEmpty(text))
                        {
                            var clean = CleanJson(text);
                            var draft = JsonSerializer.Deserialize<ProductDraftDto>(clean, new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
                            if (draft != null)
                            {
                                draft.Source = "TechGadget AI";
                                return draft;
                            }
                        }
                    }
                }
            }
            catch
            {
                // Try next model
            }
        }

        return null;
    }

    private ProductDraftDto GenerateLocalSmartDraft(string prompt, List<CategoryDto> categories, List<BrandDto> brands)
    {
        var lower = prompt.ToLowerInvariant();
        var name = prompt.Trim();
        var categoryHint = "smartphones";
        var brandHint = "Apple";
        decimal basePrice = 25000000m;
        decimal? discountPrice = 22990000m;
        int stock = 20;
        var sku = $"TG-AI-{Random.Shared.Next(1000, 9999)}";
        var desc = "";
        var specs = new Dictionary<string, object>();

        if (lower.Contains("apple") || lower.Contains("iphone") || lower.Contains("macbook") || lower.Contains("ipad") || lower.Contains("airpods"))
            brandHint = "Apple";
        else if (lower.Contains("samsung") || lower.Contains("galaxy"))
            brandHint = "Samsung";
        else if (lower.Contains("dell") || lower.Contains("xps"))
            brandHint = "Dell";
        else if (lower.Contains("sony"))
            brandHint = "Sony";
        else if (lower.Contains("asus") || lower.Contains("rog"))
            brandHint = "Asus";

        if (lower.Contains("lap") || lower.Contains("macbook") || lower.Contains("xps") || lower.Contains("máy tính"))
        {
            categoryHint = "laptops";
            basePrice = 35900000m;
            discountPrice = 32900000m;
            stock = 15;
            if (!name.ToLower().Contains("laptop") && !name.ToLower().Contains("macbook")) name = "Laptop " + name;
            desc = $"Sản phẩm cao cấp {name} mang lại hiệu năng vượt trội cho công việc và giải trí.\n\n✨ Điểm nổi bật:\n• Thiết kế mỏng nhẹ sang trọng, tản nhiệt êm ái.\n• Màn hình chống chói sắc nét, thời lượng pin cả ngày dài.\n\n🛡️ Bảo hành chính hãng 12-24 tháng.";
            specs["man_hinh"] = "15.6 inch FHD IPS 100% sRGB";
            specs["cpu"] = "Intel Core i7 / AMD Ryzen 7 thế hệ mới";
            specs["ram"] = "16GB DDR5";
            specs["o_cung"] = "512GB SSD NVMe Gen 4";
            specs["pin"] = "Thời lượng 10-12 giờ";
        }
        else if (lower.Contains("tai nghe") || lower.Contains("chuột") || lower.Contains("phím") || lower.Contains("watch"))
        {
            categoryHint = "accessories";
            basePrice = 2490000m;
            discountPrice = 2090000m;
            stock = 40;
            desc = $"Phụ kiện công nghệ cao cấp {name} nâng cao hiệu suất làm việc và sự tiện nghi.\n\n✨ Điểm nổi bật:\n• Hoàn thiện tỉ mỉ, độ bền vượt trội.\n• Tương thích hoàn hảo mọi hệ điều hành.\n\n🛡️ Bảo hành 12 tháng 1 đổi 1.";
            specs["ket_noi"] = "Wireless / Bluetooth / Type-C";
            specs["bao_hanh"] = "12 tháng";
        }
        else
        {
            categoryHint = "smartphones";
            basePrice = 28990000m;
            discountPrice = 25990000m;
            stock = 25;
            desc = $"Điện thoại thông minh {name} kết hợp hoàn hảo giữa thiết kế cao cấp đón đầu xu hướng và sức mạnh hiệu năng đỉnh cao.\n\n✨ Điểm nổi bật:\n• Màn hình OLED 120Hz rực rỡ.\n• Camera AI chụp đêm ấn tượng, pin dung lượng lớn sạc nhanh.\n\n🛡️ Cam kết chính hãng 100%, bảo hành 12 tháng.";
            specs["man_hinh"] = "6.7 inch OLED 120Hz";
            specs["cpu"] = "Chipset 8 nhân AI thế hệ mới";
            specs["ram"] = "8GB / 12GB";
            specs["rom"] = "256GB";
            specs["pin"] = "5000 mAh, sạc nhanh";
        }

        return new ProductDraftDto
        {
            Name = name,
            CategoryHint = categoryHint,
            BrandHint = brandHint,
            BasePrice = basePrice,
            DiscountPrice = discountPrice,
            Stock = stock,
            Sku = sku,
            Description = desc,
            Specifications = specs,
            Source = "TechGadget AI"
        };
    }

    private static string CleanJson(string text)
    {
        var clean = text.Trim();
        if (clean.StartsWith("```json")) clean = clean[7..];
        else if (clean.StartsWith("```")) clean = clean[3..];
        if (clean.EndsWith("```")) clean = clean[..^3];
        clean = clean.Trim();

        var first = clean.IndexOf('{');
        var last = clean.LastIndexOf('}');
        if (first != -1 && last != -1 && last > first)
        {
            clean = clean.Substring(first, last - first + 1);
        }
        return clean;
    }
}
