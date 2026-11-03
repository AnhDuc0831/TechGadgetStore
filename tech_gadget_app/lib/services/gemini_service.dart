import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/product.dart';

/// DTO sản phẩm gợi ý do AI đề xuất cho khách hàng
class ProductRecommendation {
  final String id;
  final String name;
  final String slug;
  final double basePrice;
  final double? discountPrice;
  final String? thumbnailUrl;
  final String categoryName;
  final String brandName;
  final String? reason;

  ProductRecommendation({
    required this.id,
    required this.name,
    required this.slug,
    required this.basePrice,
    this.discountPrice,
    this.thumbnailUrl,
    required this.categoryName,
    required this.brandName,
    this.reason,
  });

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) {
    return ProductRecommendation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      categoryName: json['categoryName']?.toString() ?? '',
      brandName: json['brandName']?.toString() ?? '',
      reason: json['reason']?.toString(),
    );
  }

  factory ProductRecommendation.fromProductListItem(ProductListItem item, {String? reason}) {
    return ProductRecommendation(
      id: item.id,
      name: item.name,
      slug: item.slug,
      basePrice: item.basePrice,
      discountPrice: item.discountPrice,
      thumbnailUrl: item.thumbnailUrl,
      categoryName: item.category.name,
      brandName: item.brand.name,
      reason: reason ?? 'Sản phẩm nổi bật tại cửa hàng',
    );
  }
}

/// DTO kết quả bài đăng do AI sinh ra cho Admin (tương tự JobDraft của GiGood)
class ProductAiDraft {
  final String name;
  final String categoryHint;
  final String brandHint;
  final double basePrice;
  final double? discountPrice;
  final int stock;
  final String sku;
  final String description;
  final Map<String, dynamic> specifications;
  final String source;

  ProductAiDraft({
    required this.name,
    required this.categoryHint,
    required this.brandHint,
    required this.basePrice,
    this.discountPrice,
    required this.stock,
    required this.sku,
    required this.description,
    required this.specifications,
    this.source = 'TechGadget AI',
  });

  factory ProductAiDraft.fromJson(Map<String, dynamic> json) {
    return ProductAiDraft(
      name: json['name']?.toString() ?? '',
      categoryHint: json['categoryHint']?.toString() ?? '',
      brandHint: json['brandHint']?.toString() ?? '',
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      discountPrice: (json['discountPrice'] as num?)?.toDouble(),
      stock: (json['stock'] as num?)?.toInt() ?? 20,
      sku: json['sku']?.toString() ?? 'TG-AI',
      description: json['description']?.toString() ?? '',
      specifications: json['specifications'] is Map
          ? Map<String, dynamic>.from(json['specifications'] as Map)
          : {},
      source: json['source']?.toString() ?? 'TechGadget AI',
    );
  }
}

/// Thông tin trạng thái cấu hình AI từ Backend .NET
class AiStatusInfo {
  final bool configured;
  final String model;
  final String message;

  AiStatusInfo({
    required this.configured,
    required this.model,
    required this.message,
  });

  factory AiStatusInfo.fromJson(Map<String, dynamic> json) {
    return AiStatusInfo(
      configured: json['configured'] as bool? ?? false,
      model: json['model']?.toString() ?? 'gemini-flash-lite-latest',
      message: json['message']?.toString() ?? '',
    );
  }
}

/// DTO thống kê snapshot đọc từ CSDL cho Admin
class TopProductSnapshot {
  final String name;
  final int unitsSold;
  final double revenue;

  TopProductSnapshot({
    required this.name,
    required this.unitsSold,
    required this.revenue,
  });

  factory TopProductSnapshot.fromJson(Map<String, dynamic> json) {
    return TopProductSnapshot(
      name: json['name']?.toString() ?? '',
      unitsSold: (json['unitsSold'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LowStockSnapshot {
  final String name;
  final String sku;
  final int stock;

  LowStockSnapshot({
    required this.name,
    required this.sku,
    required this.stock,
  });

  factory LowStockSnapshot.fromJson(Map<String, dynamic> json) {
    return LowStockSnapshot(
      name: json['name']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardSnapshot {
  final String period;
  final double totalRevenue;
  final double totalProfit;
  final double profitMarginPercentage;
  final int totalOrders;
  final int deliveredOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final int totalProducts;
  final int lowStockProductsCount;
  final int outOfStockProductsCount;
  final List<TopProductSnapshot> topSellingProducts;
  final List<LowStockSnapshot> lowStockAlerts;

  DashboardSnapshot({
    required this.period,
    required this.totalRevenue,
    required this.totalProfit,
    required this.profitMarginPercentage,
    required this.totalOrders,
    required this.deliveredOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.totalProducts,
    required this.lowStockProductsCount,
    required this.outOfStockProductsCount,
    this.topSellingProducts = const [],
    this.lowStockAlerts = const [],
  });

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    var tops = <TopProductSnapshot>[];
    if (json['topSellingProducts'] is List) {
      tops = (json['topSellingProducts'] as List)
          .map((e) => TopProductSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    var lows = <LowStockSnapshot>[];
    if (json['lowStockAlerts'] is List) {
      lows = (json['lowStockAlerts'] as List)
          .map((e) => LowStockSnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return DashboardSnapshot(
      period: json['period']?.toString() ?? '30days',
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      totalProfit: (json['totalProfit'] as num?)?.toDouble() ?? 0,
      profitMarginPercentage: (json['profitMarginPercentage'] as num?)?.toDouble() ?? 0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      deliveredOrders: (json['deliveredOrders'] as num?)?.toInt() ?? 0,
      pendingOrders: (json['pendingOrders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (json['cancelledOrders'] as num?)?.toInt() ?? 0,
      totalProducts: (json['totalProducts'] as num?)?.toInt() ?? 0,
      lowStockProductsCount: (json['lowStockProductsCount'] as num?)?.toInt() ?? 0,
      outOfStockProductsCount: (json['outOfStockProductsCount'] as num?)?.toInt() ?? 0,
      topSellingProducts: tops,
      lowStockAlerts: lows,
    );
  }
}

/// DTO phản hồi trò chuyện của Trợ lý AI
class AiChatResult {
  final String reply;
  final ProductAiDraft? productDraft;
  final List<ProductRecommendation> recommendedProducts;
  final DashboardSnapshot? dashboardSnapshot;
  final bool isConfigured;
  final String source;
  final bool isFallback;
  final String? errorDetail;

  AiChatResult({
    required this.reply,
    this.productDraft,
    this.recommendedProducts = const [],
    this.dashboardSnapshot,
    required this.isConfigured,
    this.source = 'TechGadget AI',
    this.isFallback = false,
    this.errorDetail,
  });

  factory AiChatResult.fromJson(Map<String, dynamic> json) {
    var recs = <ProductRecommendation>[];
    if (json['recommendedProducts'] is List) {
      recs = (json['recommendedProducts'] as List)
          .map((e) => ProductRecommendation.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return AiChatResult(
      reply: json['reply']?.toString() ?? '',
      productDraft: json['productDraft'] != null
          ? ProductAiDraft.fromJson(json['productDraft'] as Map<String, dynamic>)
          : null,
      recommendedProducts: recs,
      dashboardSnapshot: json['dashboardSnapshot'] != null
          ? DashboardSnapshot.fromJson(json['dashboardSnapshot'] as Map<String, dynamic>)
          : null,
      isConfigured: json['isConfigured'] as bool? ?? false,
      source: json['source']?.toString() ?? 'TechGadget AI',
      isFallback: json['isFallback'] as bool? ?? false,
      errorDetail: json['errorDetail']?.toString(),
    );
  }
}

/// Dịch vụ kết nối Gemini AI (Hỗ trợ gọi Backend .NET API & Fallback trực tiếp chống lỗi)
class GeminiService {
  static final String _baseUrl = SupabaseConfig.apiBaseUrl;
  static const String _directGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const List<String> _geminiModels = [
    'gemini-flash-lite-latest',
    'gemini-3.5-flash-lite',
    'gemini-flash-latest',
  ];

  /// Lấy trạng thái AI từ backend .NET API (GET /api/ai/status)
  static Future<AiStatusInfo> getAiStatus() async {
    try {
      final url = Uri.parse('$_baseUrl/api/ai/status');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AiStatusInfo.fromJson(data);
      }
    } catch (_) {}

    return AiStatusInfo(
      configured: true,
      model: 'TechGadget AI',
      message: 'Trợ lý TechGadget AI sẵn sàng hỗ trợ khách hàng.',
    );
  }

  /// Gửi tin nhắn tư vấn khách hàng (Dành riêng cho Role Customer)
  /// Tự động xử lý lỗi Gemini: Backend -> Gemini Direct -> Smart Local Fallback
  static Future<AiChatResult> sendCustomerChat({
    required String message,
    String? productId,
    List<Map<String, String>> history = const [],
    List<ProductListItem> availableProducts = const [],
    List<Category> categories = const [],
    List<Brand> brands = const [],
  }) async {
    // 1. Thử gọi qua Backend .NET API
    try {
      final url = Uri.parse('$_baseUrl/api/ai/chat');
      final body = jsonEncode({
        'message': message,
        'role': 'customer',
        'productId': productId,
        'history': history,
      });

      final res = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AiChatResult.fromJson(data);
      }
    } catch (e) {
      debugPrint('Backend AI endpoint unreachable: $e. Thử gọi trực tiếp Google Gemini...');
    }

    // 2. Fallback nếu Backend chưa bật: Gọi trực tiếp Google Gemini API từ App (chỉ khi có API Key)
    if (_directGeminiApiKey.isNotEmpty) {
      try {
        final directResult = await _callDirectGeminiCustomerChat(
          message: message,
          availableProducts: availableProducts,
          categories: categories,
          brands: brands,
          history: history,
        );
        if (directResult != null) {
          return directResult;
        }
      } catch (e) {
        debugPrint('Direct Gemini API call failed: $e. Chuyển sang Smart Local Engine...');
      }
    }

    // 3. Fallback cấp 3: Bộ máy tư vấn dự phòng thông minh nội bộ
    return _generateSmartLocalCustomerAdvisory(
      message: message,
      availableProducts: availableProducts,
      errorNotice: 'Đang phản hồi từ Chế độ Dự phòng Thông minh (Hệ thống đang bận).',
    );
  }

  /// Gửi tin nhắn trò chuyện phân tích CSDL cho Admin (POST /api/ai/chat với role = 'admin')
  static Future<AiChatResult> sendAdminAnalyticsChat({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/ai/chat');
      final body = jsonEncode({
        'message': message,
        'role': 'admin',
        'history': history,
      });

      final res = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AiChatResult.fromJson(data);
      }
    } catch (e) {
      debugPrint('sendAdminAnalyticsChat error: $e');
    }

    return _generateSmartLocalAdminChat(message);
  }

  /// Gửi tin nhắn cho vai trò Admin (POST /api/ai/chat với role = 'admin')
  static Future<AiChatResult> sendAiChat({
    required String message,
    List<Map<String, String>> history = const [],
    required List<Category> categories,
    required List<Brand> brands,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/ai/chat');
      final body = jsonEncode({
        'message': message,
        'role': 'admin',
        'history': history,
      });

      final res = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return AiChatResult.fromJson(data);
      }
    } catch (_) {}

    return _generateSmartLocalAdminChat(message);
  }

  /// Gọi trực tiếp Google Gemini API khi Backend không phản hồi
  static Future<AiChatResult?> _callDirectGeminiCustomerChat({
    required String message,
    required List<ProductListItem> availableProducts,
    required List<Category> categories,
    required List<Brand> brands,
    required List<Map<String, String>> history,
  }) async {
    final catalogBuffer = StringBuffer();
    for (final p in availableProducts.take(20)) {
      final priceStr = p.discountPrice != null
          ? '${p.discountPrice!.toStringAsFixed(0)}đ (gốc ${p.basePrice.toStringAsFixed(0)}đ)'
          : '${p.basePrice.toStringAsFixed(0)}đ';
      catalogBuffer.writeln('- [ID: ${p.id}] ${p.name} | Loại: ${p.category.name} | Giá: $priceStr');
    }

    final prompt = '''
Bạn là Trợ lý AI Tư vấn Bán hàng TechGadget Store chuyên tư vấn đồ công nghệ cho Khách hàng.
Hãy trả lời câu hỏi: "$message"
Sản phẩm hiện có tại cửa hàng:
$catalogBuffer

Nhiệm vụ:
1. Tư vấn thân thiện, chuyên nghiệp, dùng Markdown có gạch đầu dòng rõ ràng.
2. Trả về DUY NHẤT chuỗi JSON:
{
  "reply": "câu tư vấn bằng tiếng Việt...",
  "recommendedProductIds": ["<id-1>", "<id-2>"]
}
''';

    final payload = {
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 1500,
      }
    };

    for (final model in _geminiModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_directGeminiApiKey',
        );

        final res = await http
            .post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final text = candidates[0]['content']?['parts']?[0]?['text'] as String?;
            if (text != null && text.isNotEmpty) {
              final clean = _cleanJson(text);
              final jsonParsed = jsonDecode(clean) as Map<String, dynamic>;
              final reply = jsonParsed['reply']?.toString() ?? text;

              final recs = <ProductRecommendation>[];
              final ids = jsonParsed['recommendedProductIds'] as List?;
              if (ids != null) {
                for (final id in ids) {
                  final match = availableProducts.where((p) => p.id == id.toString()).firstOrNull;
                  if (match != null) {
                    recs.add(ProductRecommendation.fromProductListItem(match));
                  }
                }
              }

              return AiChatResult(
                reply: reply,
                recommendedProducts: recs,
                isConfigured: true,
                source: 'TechGadget AI',
                isFallback: false,
              );
            }
          }
        }
      } catch (_) {
        // Thử model tiếp theo
      }
    }
    return null;
  }

  /// Bộ máy tư vấn dự phòng cục bộ cho khách hàng (Khi Gemini gặp lỗi/quá tải)
  static AiChatResult _generateSmartLocalCustomerAdvisory({
    required String message,
    required List<ProductListItem> availableProducts,
    String? errorNotice,
  }) {
    final lower = message.toLowerCase();
    final recs = <ProductRecommendation>[];
    final buffer = StringBuffer();

    if (lower.contains('bảo hành') || lower.contains('đổi trả') || lower.contains('chính sách')) {
      buffer.writeln('Dạ chào bạn! **Chính sách bảo hành & đổi trả tại TechGadget Store**:');
      buffer.writeln('• **Bảo hành chính hãng:** 12 - 24 tháng cho toàn bộ thiết bị mới 100%.');
      buffer.writeln('• **Lỗi 1 đổi 1 trong 30 ngày:** Áp dụng ngay nếu lỗi do nhà sản xuất.');
      buffer.writeln('• **Hỗ trợ trọn đời:** Cài đặt phần mềm, vệ sinh máy miễn phí tại cửa hàng.');
    } else if (lower.contains('giao hàng') || lower.contains('ship') || lower.contains('vận chuyển')) {
      buffer.writeln('Dạ chào bạn! **Chính sách giao hàng của TechGadget Store**:');
      buffer.writeln('• **Giao hỏa tốc:** 1 - 2 giờ trong nội thành.');
      buffer.writeln('• **Giao toàn quốc:** 2 - 4 ngày làm việc.');
      buffer.writeln('• **Miễn phí ship:** Áp dụng cho đơn hàng từ **500.000₫**.');
    } else if (lower.contains('thanh toán') || lower.contains('payos') || lower.contains('cod')) {
      buffer.writeln('Dạ chào bạn! **Phương thức thanh toán tiện lợi tại TechGadget Store**:');
      buffer.writeln('• **Quét mã VietQR qua PayOS:** Tự động xác nhận sau 3 giây.');
      buffer.writeln('• **Thanh toán khi nhận hàng (COD):** Đồng kiểm rồi mới thanh toán.');
      buffer.writeln('• **Thẻ ATM / Visa / Mastercard:** Hỗ trợ mọi ngân hàng.');
    } else {
      buffer.writeln('Dạ chào bạn! Cảm ơn bạn đã liên hệ **Trợ lý Tư vấn TechGadget AI**! 🌟');
      buffer.writeln('Dưới đây là một số thiết bị nổi bật, giá tốt đang được ưa chuộng tại cửa hàng:');

      // Chọn lọc sản phẩm theo từ khóa
      var matched = availableProducts.where((p) {
        if (lower.contains('iphone') || lower.contains('điện thoại')) {
          return p.category.slug.contains('phone') || p.name.toLowerCase().contains('iphone');
        }
        if (lower.contains('laptop') || lower.contains('macbook')) {
          return p.category.slug.contains('lap') || p.name.toLowerCase().contains('lap');
        }
        if (lower.contains('tai nghe') || lower.contains('loa') || lower.contains('phụ kiện')) {
          return p.category.slug.contains('acc') || p.name.toLowerCase().contains('tai nghe');
        }
        return true;
      }).toList();

      if (matched.isEmpty) {
        matched = availableProducts.take(3).toList();
      }

      for (final p in matched.take(3)) {
        recs.add(ProductRecommendation.fromProductListItem(p));
      }

      buffer.writeln('\nBạn có thể nhấn vào các thẻ sản phẩm bên dưới để xem cấu hình chi tiết và đặt hàng nhé!');
    }

    return AiChatResult(
      reply: buffer.toString().trim(),
      recommendedProducts: recs,
      isConfigured: true,
      source: 'TechGadget Smart Engine (Chế độ dự phòng thông minh)',
      isFallback: true,
      errorDetail: errorNotice,
    );
  }

  /// Sinh bản thảo sản phẩm từ Backend .NET API (POST /api/ai/draft-product)
  static Future<ProductAiDraft> generateProductDraft({
    required String userPrompt,
    required List<Category> categories,
    required List<Brand> brands,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/ai/draft-product');
      final body = jsonEncode({'prompt': userPrompt});

      final res = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return ProductAiDraft.fromJson(data);
      }
    } catch (_) {}

    return generateSmartLocalProductDraft(userPrompt);
  }

  /// Bộ máy Smart Local Engine nội bộ cho Admin
  static AiChatResult _generateSmartLocalAdminChat(String message) {
    final lower = message.toLowerCase();
    final isDraftIntent = lower.contains('viết bài') ||
        lower.contains('đăng') ||
        lower.contains('tạo bài') ||
        lower.contains('iphone') ||
        lower.contains('laptop') ||
        lower.contains('samsung') ||
        lower.contains('macbook') ||
        lower.contains('dell') ||
        lower.contains('sony') ||
        lower.contains('asus') ||
        lower.contains('tai nghe') ||
        lower.contains('chuột') ||
        lower.contains('phím') ||
        lower.contains('watch');

    if (isDraftIntent) {
      final cleanPrompt = message
          .replaceAll(RegExp(r'^(viết bài|đăng|tạo bài|soạn bài|🪄|✨|:\s*)+', caseSensitive: false), '')
          .trim();
      final draft = generateSmartLocalProductDraft(cleanPrompt.isNotEmpty ? cleanPrompt : message);

      return AiChatResult(
        reply:
            'Tôi đã phân tích yêu cầu và soạn sẵn nội dung bài đăng cho **${draft.name}**!\n\nNhấn nút **"Áp dụng vào Đăng sản phẩm ngay"** bên dưới để tự động điền form nhé.',
        productDraft: draft,
        isConfigured: false,
        source: 'Smart Local Engine (Dự phòng)',
        isFallback: true,
      );
    }

    return AiChatResult(
      reply:
          'Xin chào Quản trị viên! Tôi là **Trợ lý TechGadget AI**.\n\nTôi có thể giúp bạn:\n• **Tự động viết bài & lập cấu hình** cho sản phẩm (ví dụ: gõ "iPhone 16 Pro Max 256GB" hoặc "Laptop Dell XPS 15").\n• **Định giá & tính khuyến mãi** chuẩn thị trường.\n• **Tạo thông số kỹ thuật JSON** chuẩn xác.\n\nBạn muốn đăng bán thiết bị nào hôm nay?',
      productDraft: null,
      isConfigured: false,
      source: 'Smart Local Engine (Dự phòng)',
      isFallback: true,
    );
  }

  /// Sinh bản thảo sản phẩm Smart Local cho Admin
  static ProductAiDraft generateSmartLocalProductDraft(String prompt) {
    final lower = prompt.toLowerCase();
    String name = prompt.trim();
    String categoryHint = 'smartphones';
    String brandHint = 'Apple';
    double basePrice = 25000000;
    double? discountPrice = 22990000;
    int stock = 20;
    String sku = 'TG-AI-${Random().nextInt(9000) + 1000}';
    String description = '';
    Map<String, dynamic> specs = {};

    if (lower.contains('apple') || lower.contains('iphone') || lower.contains('macbook') || lower.contains('ipad') || lower.contains('airpods')) {
      brandHint = 'Apple';
    } else if (lower.contains('samsung') || lower.contains('galaxy') || lower.contains('fold') || lower.contains('flip')) {
      brandHint = 'Samsung';
    } else if (lower.contains('dell') || lower.contains('xps') || lower.contains('alienware')) {
      brandHint = 'Dell';
    } else if (lower.contains('sony')) {
      brandHint = 'Sony';
    } else if (lower.contains('logitech')) {
      brandHint = 'Logitech';
    } else if (lower.contains('asus') || lower.contains('rog') || lower.contains('tuf')) {
      brandHint = 'Asus';
    }

    if (lower.contains('lap') || lower.contains('macbook') || lower.contains('xps') || lower.contains('thinkpad') || lower.contains('máy tính')) {
      categoryHint = 'laptops';
      basePrice = 35900000;
      discountPrice = 32900000;
      stock = 15;
      if (!name.toLowerCase().contains('laptop') && !name.toLowerCase().contains('macbook')) {
        name = 'Laptop $name';
      }
      description =
          'Sản phẩm cao cấp $name mang đến hiệu năng vượt trội cho cả công việc chuyên nghiệp và giải trí đỉnh cao.\n\n'
          '✨ Điểm nổi bật:\n'
          '• Thiết kế kim loại nguyên khối siêu mỏng nhẹ, độ bền đạt chuẩn quân đội.\n'
          '• Màn hình sắc nét độ phân giải cao, tần số quét mượt mà bảo vệ mắt.\n'
          '• Hệ thống tản nhiệt thông minh vận hành êm ái, pin dung lượng lớn cho cả ngày làm việc.\n'
          '• Đầy đủ các cổng kết nối tốc độ cao và sạc nhanh Type-C Power Delivery.\n\n'
          '🛡️ Cam kết: Hàng mới 100% nguyên seal, bảo hành chính hãng toàn diện, hỗ trợ 1 đổi 1 trong 30 ngày.';
      specs = {
        'man_hinh': '15.6 inch IPS FHD/QHD, 100% sRGB, chống chói',
        'cpu': 'Bộ vi xử lý hiệu năng cao thế hệ mới nhất',
        'ram': '16GB DDR5 tốc độ cao đa nhiệm mượt mà',
        'o_cung': '512GB SSD PCIe NVMe siêu nhanh',
        'vga': 'Card đồ họa tối ưu đồ họa và dựng video',
        'pin': 'Thời lượng pin ấn tượng lên tới 10-12 giờ',
        'trong_luong': '1.65 kg',
        'bao_hanh': '12-24 tháng chính hãng',
      };
    } else if (lower.contains('tai nghe') || lower.contains('sound') || lower.contains('audio') || lower.contains('loa') || lower.contains('headphone')) {
      categoryHint = 'accessories';
      basePrice = 5490000;
      discountPrice = 4890000;
      stock = 35;
      description =
          'Thiết bị âm thanh thế hệ mới $name mang đến trải nghiệm thưởng thức âm nhạc đỉnh cao với dải âm chi tiết và âm bass sâu lắng.\n\n'
          '✨ Điểm nổi bật:\n'
          '• Công nghệ chống ồn chủ động ANC tiên tiến, loại bỏ tạp âm môi trường hiệu quả.\n'
          '• Thời lượng pin bền bỉ liên tục nhiều giờ cùng công nghệ sạc nhanh tiện lợi.\n'
          '• Thiết kế công thái học êm ái, đeo thoải mái suốt cả ngày mà không gây đau tai.\n'
          '• Kết nối Bluetooth chuẩn mới nhất ổn định, độ trễ cực thấp khi xem phim và chơi game.\n\n'
          '🛡️ Bảo hành chính hãng 12 tháng lỗi 1 đổi 1.';
      specs = {
        'kieu_tai_nghe': 'Chống ồn chủ động ANC thông minh',
        'chuan_am_thanh': 'Hi-Res Audio Wireless / Âm thanh vòm 360',
        'thoi_luong_pin': '30 giờ (kèm hộp sạc), sạc nhanh Type-C',
        'chong_nuoc': 'IPX4 chống mồ hôi và nước bắn',
        'bao_hanh': '12 tháng chính hãng',
      };
    } else if (lower.contains('chuột') || lower.contains('bàn phím') || lower.contains('sạc') || lower.contains('cáp') || lower.contains('watch') || lower.contains('đồng hồ')) {
      categoryHint = 'accessories';
      basePrice = 2290000;
      discountPrice = 1890000;
      stock = 50;
      description =
          'Phụ kiện công nghệ cao cấp $name được thiết kế nhằm nâng cao hiệu suất làm việc và sự tiện nghi tối đa cho người dùng hiện đại.\n\n'
          '✨ Điểm nổi bật:\n'
          '• Hoàn thiện tỉ mỉ từ vật liệu cao cấp, độ bền vượt thời gian.\n'
          '• Khả năng tương thích hoàn hảo với hệ điều hành Windows, macOS, Android và iOS.\n'
          '• Thiết kế tinh tế, hiện đại nâng tầm không gian bàn làm việc của bạn.\n\n'
          '🛡️ Bảo hành 12 tháng chính hãng.';
      specs = {
        'ket_noi': 'Không dây Wireless / Bluetooth / Type-C',
        'tinh_nang': 'Tối ưu độ chính xác và tiết kiệm năng lượng',
        'chat_lieu': 'Cao cấp chống bám vân tay và mồ hôi',
        'bao_hanh': '12 tháng chính hãng',
      };
    } else {
      categoryHint = 'smartphones';
      basePrice = 28990000;
      discountPrice = 25990000;
      stock = 25;
      description =
          'Điện thoại thông minh $name kết hợp hoàn hảo giữa thiết kế sang trọng đón đầu xu hướng và sức mạnh hiệu năng đỉnh cao.\n\n'
          '✨ Điểm nổi bật:\n'
          '• Màn hình tràn viền công nghệ hiển thị rực rỡ, tần số quét 120Hz mượt mà.\n'
          '• Cụm camera chuyên nghiệp tích hợp AI xử lý ảnh và quay video đêm sắc nét.\n'
          '• Bộ vi xử lý mạnh mẽ cân mượt mọi tựa game nặng và tác vụ AI thông minh.\n'
          '• Dung lượng pin lớn hỗ trợ công nghệ sạc nhanh, sử dụng trọn vẹn cả ngày dài.\n\n'
          '🛡️ Cam kết: Máy mới 100% nguyên hộp, phụ kiện đầy đủ, bảo hành chính hãng 12 tháng.';
      specs = {
        'man_hinh': '6.7 inch AMOLED / OLED 120Hz, độ sáng cực cao',
        'cpu': 'Chipset 8 nhân thế hệ mới xử lý AI thông minh',
        'ram': '8GB / 12GB LPDDR5X',
        'rom': '256GB bộ nhớ trong tốc độ cao',
        'camera': 'Hệ thống camera AI chuyên nghiệp OIS chống rung',
        'pin': '5000 mAh, sạc nhanh công suất lớn',
        'bao_hanh': '12 tháng chính hãng',
      };
    }

    return ProductAiDraft(
      name: name,
      categoryHint: categoryHint,
      brandHint: brandHint,
      basePrice: basePrice,
      discountPrice: discountPrice,
      stock: stock,
      sku: sku,
      description: description,
      specifications: specs,
      source: 'Smart Local Engine',
    );
  }

  static String _cleanJson(String text) {
    var clean = text.trim();
    if (clean.startsWith('```json')) {
      clean = clean.substring(7);
    } else if (clean.startsWith('```')) {
      clean = clean.substring(3);
    }
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
    clean = clean.trim();

    final first = clean.indexOf('{');
    final last = clean.lastIndexOf('}');
    if (first != -1 && last != -1 && last > first) {
      clean = clean.substring(first, last + 1);
    }
    return clean;
  }
}
