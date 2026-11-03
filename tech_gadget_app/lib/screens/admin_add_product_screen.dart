import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/product_api_service.dart';
import '../widgets/ai_assistant_modal.dart';

/// Model cho mẫu sản phẩm đăng nhanh
class ProductTemplate {
  final String title;
  final String categoryHint;
  final String brandHint;
  final double basePrice;
  final double? discountPrice;
  final int stock;
  final String sku;
  final String description;
  final Map<String, dynamic> specifications;
  final IconData icon;
  final Color badgeColor;

  const ProductTemplate({
    required this.title,
    required this.categoryHint,
    required this.brandHint,
    required this.basePrice,
    this.discountPrice,
    required this.stock,
    required this.sku,
    required this.description,
    required this.specifications,
    required this.icon,
    this.badgeColor = const Color(0xFF0D9488),
  });
}

class AdminAddProductScreen extends StatefulWidget {
  const AdminAddProductScreen({super.key});

  @override
  State<AdminAddProductScreen> createState() => _AdminAddProductScreenState();
}

class _AdminAddProductScreenState extends State<AdminAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productService = ProductApiService();
  final _picker = ImagePicker();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  final _nameCtrl = TextEditingController();
  final _basePriceCtrl = TextEditingController();
  final _discountPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '10');
  final _skuCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _specsCtrl = TextEditingController(
    text: '{\n  "man_hinh": "6.7 inch OLED",\n  "cpu": "Apple A17 Pro",\n  "ram": "8GB",\n  "pin": "4422 mAh"\n}',
  );

  String? _selectedCategoryId;
  String? _selectedBrandId;
  List<Category> _categories = [];
  List<Brand> _brands = [];
  final List<XFile> _selectedImages = [];

  bool _isLoading = false;
  bool _isInitDataLoading = true;
  String? _errorMessage;

  /// Danh sách mẫu sản phẩm nhanh (Quick Templates) tương tự GiGood
  static const List<ProductTemplate> _templates = [
    ProductTemplate(
      title: 'iPhone 16 Pro Max 256GB Titan Tự Nhiên',
      categoryHint: 'smartphones',
      brandHint: 'Apple',
      basePrice: 34990000,
      discountPrice: 32490000,
      stock: 25,
      sku: 'TG-IP16PM-256-NAT',
      icon: Icons.smartphone,
      badgeColor: Color(0xFFF97316),
      description:
          'iPhone 16 Pro Max với thiết kế khung Titan cao cấp siêu bền và nhẹ, viền màn hình mỏng nhất lịch sử Apple. Trang bị chip A18 Pro 3nm mạnh mẽ dẫn đầu, nút Điều khiển Camera (Camera Control) cảm ứng lực mới, camera Fusion 48MP và thời lượng pin vượt bậc.',
      specifications: {
        'man_hinh': '6.9 inch Super Retina XDR OLED, 120Hz ProMotion, 2000 nits',
        'cpu': 'Apple A18 Pro (6 nhân CPU, 6 nhân GPU, 16 nhân Neural Engine)',
        'ram': '8GB',
        'rom': '256GB NVMe',
        'camera_sau': 'Chính 48MP + Góc siêu rộng 48MP + Tele 5x 12MP',
        'camera_truoc': '12MP TrueDepth với Autofocus',
        'pin': '4685 mAh, Sạc nhanh không dây MagSafe 25W',
        'ket_noi': 'USB-C 3.0 (10Gbps), Wi-Fi 7, 5G Sub-6',
        'tinh_nang': 'Camera Control, Action Button, Ceramic Shield thế hệ mới',
        'bao_hanh': '12 tháng chính hãng Apple VN (VN/A)',
      },
    ),
    ProductTemplate(
      title: 'Samsung Galaxy S24 Ultra 5G 256GB Titanium Gray',
      categoryHint: 'smartphones',
      brandHint: 'Samsung',
      basePrice: 31990000,
      discountPrice: 27990000,
      stock: 20,
      sku: 'TG-S24U-256-GRY',
      icon: Icons.phone_android,
      badgeColor: Color(0xFF2563EB),
      description:
          'Samsung Galaxy S24 Ultra mở ra kỷ nguyên quyền năng với Galaxy AI (Khoanh tròn tìm kiếm, Phiên dịch trực tiếp, Trợ lý ghi chú thông minh). Khung viền Titan sang trọng, màn hình phẳng chống chói Corning Gorilla Armor và bút S-Pen tích hợp.',
      specifications: {
        'man_hinh': '6.8 inch Dynamic AMOLED 2X, QHD+ (3120x1440), 120Hz, 2600 nits',
        'cpu': 'Qualcomm Snapdragon 8 Gen 3 for Galaxy (4nm)',
        'ram': '12GB LPDDR5X',
        'rom': '256GB UFS 4.0',
        'camera_sau': '200MP OIS + 50MP (Zoom quang 5x) + 10MP (Zoom quang 3x) + 12MP',
        'pin': '5000 mAh, Sạc siêu nhanh 45W, Sạc không dây 15W',
        'but_spen': 'Tích hợp sẵn trong thân máy với độ trễ 2.8ms',
        'khang_nuoc': 'IP68 (1.5m trong 30 phút)',
        'bao_hanh': '12 tháng chính hãng Samsung Việt Nam',
      },
    ),
    ProductTemplate(
      title: 'MacBook Pro 14 M3 Pro (18GB RAM / 512GB SSD)',
      categoryHint: 'laptops',
      brandHint: 'Apple',
      basePrice: 49990000,
      discountPrice: 46490000,
      stock: 15,
      sku: 'TG-MBP14-M3P-18G',
      icon: Icons.laptop_mac,
      badgeColor: Color(0xFF6B7280),
      description:
          'MacBook Pro 14 inch M3 Pro mang lại bước nhảy vọt về hiệu năng đồ họa và điện toán cho lập trình viên, nhà sáng tạo nội dung và kỹ sư đồ họa. Màn hình Liquid Retina XDR sống động với độ sáng 1600 nits và thời lượng pin đột phá lên đến 18 tiếng.',
      specifications: {
        'man_hinh': '14.2 inch Liquid Retina XDR (3024 x 1964), 120Hz ProMotion, 1600 nits',
        'cpu': 'Apple M3 Pro (11 nhân CPU, 14 nhân GPU)',
        'ram': '18GB Unified Memory (RAM hợp nhất)',
        'o_cung': '512GB SSD tốc độ cao',
        'cong_ket_noi': '3x Thunderbolt 4, HDMI, Khe thẻ SDXC, Cổng MagSafe 3',
        'trong_luong': '1.61 kg',
        'pin': '70 Wh lithium-polymer, Thời lượng xem video 18 giờ',
        'bao_hanh': '12 tháng chính hãng Apple toàn cầu',
      },
    ),
    ProductTemplate(
      title: 'Dell XPS 15 9530 Core i7-13700H RTX 4050 16GB/512GB',
      categoryHint: 'laptops',
      brandHint: 'Dell',
      basePrice: 42500000,
      discountPrice: 38900000,
      stock: 12,
      sku: 'TG-DELL-XPS15-4050',
      icon: Icons.laptop_windows,
      badgeColor: Color(0xFF0284C7),
      description:
          'Dell XPS 15 9530 là biểu tượng máy trạm di động mỏng nhẹ cao cấp. Thân máy chế tác từ nhôm CNC nguyên khối kết hợp chiếu nghỉ tay sợi carbon chống trầy. Sức mạnh ấn tượng từ Intel Core i7 thế hệ 13 và card đồ họa chuyên nghiệp NVIDIA RTX 4050.',
      specifications: {
        'man_hinh': '15.6 inch FHD+ InfinityEdge (1920x1200), 500 nits, 100% sRGB',
        'cpu': 'Intel Core i7-13700H (14 nhân, 20 luồng, up to 5.0 GHz, 24MB Cache)',
        'ram': '16GB DDR5 4800MHz (Hỗ trợ nâng cấp tối đa 64GB)',
        'o_cung': '512GB PCIe NVMe M.2 SSD Gen 4',
        'vga': 'NVIDIA GeForce RTX 4050 6GB GDDR6',
        'trong_luong': '1.92 kg',
        'am_thanh': 'Hệ thống 4 loa Waves MaxxAudio Pro 8W studio',
        'bao_hanh': '12 tháng Dell ProSupport tận nơi',
      },
    ),
    ProductTemplate(
      title: 'Tai nghe Sony WH-1000XM5 Chống Ồn Flagship',
      categoryHint: 'accessories',
      brandHint: 'Sony',
      basePrice: 8490000,
      discountPrice: 7290000,
      stock: 30,
      sku: 'TG-SONY-WH1000XM5',
      icon: Icons.headphones,
      badgeColor: Color(0xFF7C3AED),
      description:
          'Tai nghe over-ear chống ồn chủ động đỉnh cao số 1 thế giới với bộ vi xử lý V1 và QN1 độc quyền. Củ loa 30mm màng composite sợi carbon tái tạo âm thanh chuẩn Hi-Res Audio Wireless sống động. Đệm da êm ái, pin 30 giờ và sạc nhanh 3 phút nghe 3 giờ.',
      specifications: {
        'kieu_tai_nghe': 'Over-ear (Chụp tai ôm kín vành tai)',
        'chong_on': 'Chống ồn chủ động kép ANC thông minh với 8 micro',
        'chuan_am_thanh': 'Hi-Res Audio Wireless, LDAC, DSEE Extreme',
        'thoi_luong_pin': '30 giờ (bật ANC), 40 giờ (tắt ANC)',
        'cong_sac': 'USB-C (Sạc 3 phút dùng 3 giờ với củ sạc USB-PD)',
        'dam_thoai': '4 micro tạo chùm tia khử tạp âm AI khi gọi thoại',
        'trong_luong': '250g',
        'bao_hanh': '12 tháng chính hãng Sony Việt Nam',
      },
    ),
    ProductTemplate(
      title: 'Chuột không dây Logitech MX Master 3S Bluetooth & USB',
      categoryHint: 'accessories',
      brandHint: 'Dell',
      basePrice: 2490000,
      discountPrice: 2090000,
      stock: 50,
      sku: 'TG-LOGI-MXM3S-BLK',
      icon: Icons.mouse,
      badgeColor: Color(0xFF0D9488),
      description:
          'Logitech MX Master 3S là trợ thủ đắc lực cho lập trình viên và nhà thiết kế. Con lăn MagSpeed cơ điện từ siêu cuộn 1000 dòng/giây với độ chính xác đến từng pixel. Cảm biến 8000 DPI theo dõi mượt mà trên mọi bề mặt kính, nút bấm Quiet Clicks êm ái.',
      specifications: {
        'cam_bien': 'Darkfield High Precision 8000 DPI (hoạt động trên kính >4mm)',
        'con_lan': 'MagSpeed siêu cuộn cơ điện từ tự động chuyển chế độ',
        'ket_noi': 'Bluetooth Low Energy hoặc đầu thu Logi Bolt USB',
        'pin': 'Pin sạc Li-Po 500 mAh (dùng đến 70 ngày một lần sạc)',
        'tinh_nang': 'Logitech Flow chuyển file giữa 3 máy tính, nút bấm êm Silent',
        'tuong_thich': 'Windows, macOS, iPadOS, Linux',
        'bao_hanh': '12 tháng chính hãng 1 đổi 1',
      },
    ),
    ProductTemplate(
      title: 'Apple Watch Series 10 Nhôm GPS 42mm Dây Thể Thao',
      categoryHint: 'accessories',
      brandHint: 'Apple',
      basePrice: 10990000,
      discountPrice: 9990000,
      stock: 18,
      sku: 'TG-AW10-42MM-SLV',
      icon: Icons.watch,
      badgeColor: Color(0xFFDB2777),
      description:
          'Apple Watch Series 10 sở hữu màn hình OLED góc nhìn rộng lớn nhất và thiết kế mỏng nhất lịch sử Apple Watch. Bổ sung cảm biến phát hiện chứng ngưng thở khi ngủ, theo dõi nhiệt độ nước, cảm biến độ sâu khi bơi và khả năng sạc siêu tốc 80% trong 30 phút.',
      specifications: {
        'kich_thuoc_mat': '42mm (Vỏ nhôm tái chế 100%)',
        'man_hinh': 'OLED Always-On góc nhìn rộng, độ sáng tối đa 2000 nits',
        'chip': 'Apple S10 SiP 64-bit lõi kép',
        'cam_bien': 'Điện tâm đồ ECG, Đo SpO2, Đo nhiệt độ nước, Đo độ sâu',
        'chong_nuoc': '50m (WR50) theo chuẩn ISO 22810:2010',
        'thoi_luong_pin': '18 giờ sử dụng thông thường, 36 giờ chế độ tiết kiệm pin',
        'bao_hanh': '12 tháng chính hãng Apple',
      },
    ),
    ProductTemplate(
      title: 'Bàn phím cơ không dây RK84 RGB Hotswap 3 Chế Độ',
      categoryHint: 'accessories',
      brandHint: 'Dell',
      basePrice: 1390000,
      discountPrice: 1190000,
      stock: 40,
      sku: 'TG-KB-RK84-RGB',
      icon: Icons.keyboard,
      badgeColor: Color(0xFF8B5CF6),
      description:
          'Bàn phím cơ Royal Kludge RK84 layout 84 phím (75%) nhỏ gọn tiện lợi nhưng giữ trọn phím mũi tên và hàng F. Kết nối linh hoạt 3 chế độ (Type-C, 2.4Ghz, Bluetooth 5.0 kết nối 3 thiết bị). Hỗ trợ hotswap 5 pin thay switch tự do cùng LED RGB rực rỡ.',
      specifications: {
        'layout': '84 phím (75% Compact)',
        'ket_noi': 'Bluetooth 5.0, Wireless 2.4Ghz, Dây cáp USB Type-C',
        'switch': 'RK Switch (Red / Brown / Blue) - Hotswap 3 pin / 5 pin',
        'led': 'RGB 16.8 triệu màu với 20 hiệu ứng ánh sáng',
        'pin': '3750 mAh (Thời gian chờ 200 giờ khi tắt đèn nền)',
        'keycap': 'ABS Double-shot xuyên LED chống phai chữ',
        'bao_hanh': '12 tháng',
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _basePriceCtrl.dispose();
    _discountPriceCtrl.dispose();
    _stockCtrl.dispose();
    _skuCtrl.dispose();
    _descCtrl.dispose();
    _specsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final cats = await _productService.getCategories();
      final brs = await _productService.getBrands();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _brands = brs;
        if (cats.isNotEmpty) _selectedCategoryId = cats.first.id;
        if (brs.isNotEmpty) _selectedBrandId = brs.first.id;
        _isInitDataLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không tải được danh mục hoặc thương hiệu: $e';
        _isInitDataLoading = false;
      });
    }
  }

  Category? _findBestCategoryMatch(String hint) {
    if (_categories.isEmpty) return null;
    final lower = hint.toLowerCase();

    for (final c in _categories) {
      if (c.slug.toLowerCase().contains(lower) || c.name.toLowerCase().contains(lower)) {
        return c;
      }
    }

    if (lower.contains('phone') || lower.contains('thoai') || lower.contains('smart') || lower.contains('mobile')) {
      final match = _categories.where((c) =>
          c.slug.toLowerCase().contains('phone') ||
          c.name.toLowerCase().contains('phone') ||
          c.name.toLowerCase().contains('thoại')).firstOrNull;
      if (match != null) return match;
    }

    if (lower.contains('lap') || lower.contains('tinh') || lower.contains('macbook') || lower.contains('pc')) {
      final match = _categories.where((c) =>
          c.slug.toLowerCase().contains('lap') ||
          c.name.toLowerCase().contains('lap') ||
          c.name.toLowerCase().contains('tính')).firstOrNull;
      if (match != null) return match;
    }

    if (lower.contains('acc') || lower.contains('kien') || lower.contains('tai nghe') || lower.contains('chuot') || lower.contains('watch')) {
      final match = _categories.where((c) =>
          c.slug.toLowerCase().contains('acc') ||
          c.name.toLowerCase().contains('kiện') ||
          c.slug.toLowerCase().contains('phu')).firstOrNull;
      if (match != null) return match;
    }

    return _categories.first;
  }

  Brand? _findBestBrandMatch(String hint) {
    if (_brands.isEmpty) return null;
    final lower = hint.toLowerCase();

    for (final b in _brands) {
      if (b.name.toLowerCase().contains(lower) || lower.contains(b.name.toLowerCase())) {
        return b;
      }
    }

    if (lower.contains('apple') || lower.contains('iphone') || lower.contains('macbook') || lower.contains('ipad')) {
      final match = _brands.where((b) => b.name.toLowerCase().contains('apple')).firstOrNull;
      if (match != null) return match;
    }

    if (lower.contains('samsung') || lower.contains('galaxy')) {
      final match = _brands.where((b) => b.name.toLowerCase().contains('samsung')).firstOrNull;
      if (match != null) return match;
    }

    if (lower.contains('dell') || lower.contains('xps') || lower.contains('alienware')) {
      final match = _brands.where((b) => b.name.toLowerCase().contains('dell')).firstOrNull;
      if (match != null) return match;
    }

    return _brands.first;
  }

  void _applyTemplate(ProductTemplate template) {
    _nameCtrl.text = template.title;
    _basePriceCtrl.text = template.basePrice.toStringAsFixed(0);
    _discountPriceCtrl.text =
        template.discountPrice != null ? template.discountPrice!.toStringAsFixed(0) : '';
    _stockCtrl.text = template.stock.toString();
    _skuCtrl.text = template.sku;
    _descCtrl.text = template.description;
    _specsCtrl.text = const JsonEncoder.withIndent('  ').convert(template.specifications);

    final cat = _findBestCategoryMatch(template.categoryHint);
    if (cat != null) _selectedCategoryId = cat.id;

    final brand = _findBestBrandMatch(template.brandHint);
    if (brand != null) _selectedBrandId = brand.id;

    setState(() {});

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Đã điền tự động mẫu: ${template.title}')),
          ],
        ),
        backgroundColor: const Color(0xFF0F766E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _generateSku() {
    final name = _nameCtrl.text.trim();
    final randomSuffix = Random().nextInt(900) + 100;
    String prefix = 'TG';

    if (_selectedBrandId != null && _brands.isNotEmpty) {
      final b = _brands.where((b) => b.id == _selectedBrandId).firstOrNull;
      if (b != null) {
        prefix = 'TG-${b.name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').padRight(3, 'X').substring(0, 3)}';
      }
    }

    String model = '';
    if (name.isNotEmpty) {
      final words = name.split(' ');
      model = words.take(3).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    }
    if (model.isEmpty) model = 'PROD';

    setState(() {
      _skuCtrl.text = '$prefix-$model-$randomSuffix';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã tạo mã SKU: ${_skuCtrl.text}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _formatSpecsJson() {
    try {
      final decoded = jsonDecode(_specsCtrl.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      setState(() => _specsCtrl.text = formatted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã căn chỉnh định dạng JSON chuẩn!'), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON không hợp lệ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _applySpecsPreset(String type) {
    Map<String, dynamic> sampleSpecs;
    switch (type) {
      case 'phone':
        sampleSpecs = {
          'man_hinh': '6.7 inch AMOLED 120Hz',
          'cpu': 'Chipset 8 nhân thế hệ mới',
          'ram': '8GB LPDDR5',
          'rom': '128GB / 256GB UFS',
          'camera_sau': '50MP OIS + 12MP Ultra-wide',
          'pin': '5000 mAh, Sạc nhanh 45W',
          'bao_hanh': '12 tháng chính hãng',
        };
        break;
      case 'laptop':
        sampleSpecs = {
          'man_hinh': '15.6 inch FHD 144Hz IPS chống chói',
          'cpu': 'Intel Core i7 Gen 13 / AMD Ryzen 7',
          'ram': '16GB DDR5 5200MHz',
          'o_cung': '512GB NVMe PCIe Gen4 SSD',
          'vga': 'Card đồ họa rời 6GB GDDR6',
          'trong_luong': '1.85 kg',
          'pin': '70 Whr, Sạc 100W Type-C',
          'bao_hanh': '24 tháng',
        };
        break;
      case 'audio':
        sampleSpecs = {
          'kieu_tai_nghe': 'True Wireless / Chụp tai Over-ear',
          'chong_on': 'Chống ồn chủ động ANC & Xuyên âm Ambient Sound',
          'chuan_am_thanh': 'Hi-Res Audio, Codec AAC/LDAC',
          'pin_tai_nghe': '8 giờ liên tục',
          'pin_hop_sac': '24 giờ kèm hộp sạc',
          'khang_nuoc': 'IPX4 chống mồ hôi và tia nước bắn',
          'bao_hanh': '12 tháng',
        };
        break;
      case 'watch':
        sampleSpecs = {
          'kich_thuoc': '44mm / 40mm',
          'man_hinh': 'AMOLED Always-on Display',
          'cam_bien': 'Đo nhịp tim quang học, Đo SpO2, Theo dõi giấc ngủ',
          'chong_nuoc': '5 ATM (50 mét)',
          'pin': 'Thời lượng sử dụng 7 ngày',
          'ket_noi': 'Bluetooth 5.3, GPS độc lập',
          'bao_hanh': '12 tháng',
        };
        break;
      default:
        sampleSpecs = {
          'chat_lieu': 'Nhôm nguyên khối / Nhựa ABS cao cấp',
          'chuan_ket_noi': 'USB Type-C / Bluetooth',
          'nguon_dien': 'Điện áp 100-240V',
          'tinh_nang': 'Tương thích mọi thiết bị iOS & Android',
          'bao_hanh': '12 tháng lỗi 1 đổi 1',
        };
    }

    setState(() {
      _specsCtrl.text = const JsonEncoder.withIndent('  ').convert(sampleSpecs);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã điền mẫu thông số kỹ thuật cho: $type'), duration: const Duration(seconds: 1)),
    );
  }

  /// Mở modal Trợ lý TechGadget AI (Chatbot & Tạo bài tự động giống 100% GiGood)
  void _openAiAssistantModal([String? prompt]) {
    AiAssistantModal.show(
      context: context,
      categories: _categories,
      brands: _brands,
      initialPrompt: prompt,
      onApplyDraft: (draft) {
        _nameCtrl.text = draft.name;
        _basePriceCtrl.text = draft.basePrice.toStringAsFixed(0);
        _discountPriceCtrl.text = draft.discountPrice != null
            ? draft.discountPrice!.toStringAsFixed(0)
            : '';
        _stockCtrl.text = draft.stock.toString();
        _skuCtrl.text = draft.sku;
        _descCtrl.text = draft.description;
        _specsCtrl.text = const JsonEncoder.withIndent('  ').convert(draft.specifications);

        final cat = _findBestCategoryMatch(draft.categoryHint);
        if (cat != null) _selectedCategoryId = cat.id;

        final brand = _findBestBrandMatch(draft.brandHint);
        if (brand != null) _selectedBrandId = brand.id;

        setState(() {});

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Đã điền tự động nội dung từ TechGadget AI: ${draft.name}')),
              ],
            ),
            backgroundColor: const Color(0xFF0F766E),
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage();
      if (!mounted) return;
      if (images.isNotEmpty) {
        setState(() => _selectedImages.addAll(images));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn ảnh: $e')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedBrandId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục và thương hiệu.')),
      );
      return;
    }

    final token = context.read<AuthProvider>().accessToken;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dto = CreateProductDto(
        name: _nameCtrl.text.trim(),
        categoryId: _selectedCategoryId!,
        brandId: _selectedBrandId!,
        basePrice: double.parse(_basePriceCtrl.text.trim()),
        discountPrice: _discountPriceCtrl.text.trim().isNotEmpty
            ? double.parse(_discountPriceCtrl.text.trim())
            : null,
        stockQuantity: int.tryParse(_stockCtrl.text.trim()) ?? 0,
        sku: _skuCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        specifications: _specsCtrl.text.trim(),
      );

      await _productService.createProduct(
        token,
        dto,
        _selectedImages.map((e) => e.path).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng sản phẩm lên Cloudinary & CSDL thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Banner Trợ lý AI GiGood style
  Widget _buildAiBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED), // orange-50
        border: Border.all(color: const Color(0xFFFED7AA)), // orange-200
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openAiAssistantModal,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316), // orange-500
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '✨ Trợ lý AI: Tự động viết & điền bài đăng',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF431407), // orange-950
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Nhập yêu cầu (ví dụ: iPhone 16 Pro, Laptop ROG, Tai nghe...), AI sẽ tự tạo mô tả và điền form cho bạn!',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9A3412), // orange-800
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Thử ngay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mẫu sản phẩm nhanh (Quick Templates) tương tự GiGood
  Widget _buildQuickTemplates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MẪU SẢN PHẨM NHANH CHO ADMIN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '1 chạm để điền',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 115,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _templates.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final t = _templates[idx];
              return InkWell(
                onTap: () => _applyTemplate(t),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(t.icon, size: 16, color: t.badgeColor),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t.brandHint,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: t.badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                          height: 1.2,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(t.discountPrice ?? t.basePrice),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Chips chọn nhanh danh mục
  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn nhanh danh mục:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((c) {
              final isSelected = _selectedCategoryId == c.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(c.name),
                  selected: isSelected,
                  selectedColor: Colors.orange.shade100,
                  checkmarkColor: Colors.deepOrange,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.deepOrange.shade900 : Colors.black87,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategoryId = c.id);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  /// Chips chọn nhanh thương hiệu
  Widget _buildBrandChips() {
    if (_brands.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn nhanh thương hiệu:',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _brands.map((b) {
              final isSelected = _selectedBrandId == b.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(b.name),
                  selected: isSelected,
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue.shade800,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.blue.shade900 : Colors.black87,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedBrandId = b.id);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đăng sản phẩm mới')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Chỉ tài khoản Quản trị viên (Admin) mới có quyền truy cập.',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ),
      );
    }

    if (_isInitDataLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng sản phẩm mới'),
        actions: [
          IconButton(
            tooltip: 'Trợ lý AI',
            icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
            onPressed: _openAiAssistantModal,
          ),
          TextButton.icon(
            onPressed: _isLoading ? null : _submitForm,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('LƯU', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner Trợ lý AI phong cách GiGood
                  _buildAiBanner(),

                  // Mẫu đăng nhanh tương tự GiGood
                  _buildQuickTemplates(),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tên sản phẩm
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên sản phẩm *',
                      hintText: 'Ví dụ: iPhone 16 Pro Max 256GB',
                      prefixIcon: Icon(Icons.devices_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên sản phẩm' : null,
                  ),
                  const SizedBox(height: 14),

                  // Danh mục & Thương hiệu Quick Chips
                  _buildCategoryChips(),
                  _buildBrandChips(),

                  // Dropdowns dự phòng / chi tiết
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Danh mục *',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedBrandId,
                          decoration: const InputDecoration(
                            labelText: 'Thương hiệu *',
                            border: OutlineInputBorder(),
                          ),
                          items: _brands
                              .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedBrandId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Giá gốc & Giá khuyến mãi
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _basePriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giá gốc (VNĐ) *',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Nhập giá gốc';
                            final val = double.tryParse(v.trim());
                            if (val == null || val < 0) return 'Giá không hợp lệ';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _discountPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Giá KM (nếu có)',
                            prefixIcon: Icon(Icons.discount_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final disc = double.tryParse(v.trim());
                            final base = double.tryParse(_basePriceCtrl.text.trim()) ?? 0;
                            if (disc == null || disc < 0) return 'Giá KM không hợp lệ';
                            if (disc > base) return 'Giá KM phải <= giá gốc';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Tồn kho & SKU
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: _stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số lượng tồn *',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Nhập tồn kho';
                            final val = int.tryParse(v.trim());
                            if (val == null || val < 0) return 'Số không hợp lệ';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 6,
                        child: TextFormField(
                          controller: _skuCtrl,
                          decoration: InputDecoration(
                            labelText: 'Mã SKU',
                            prefixIcon: const Icon(Icons.qr_code),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.flash_on, color: Colors.orange, size: 20),
                              tooltip: 'Tự sinh mã SKU',
                              onPressed: _generateSku,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Mô tả sản phẩm
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả sản phẩm',
                      hintText: 'Nhập thông tin giới thiệu, tính năng nổi bật...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Thông số kỹ thuật JSON với Preset Chips & Format
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Thông số kỹ thuật (JSON):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      TextButton.icon(
                        onPressed: _formatSpecsJson,
                        icon: const Icon(Icons.format_align_left, size: 16),
                        label: const Text('Định dạng JSON', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.phone_android, size: 14),
                          label: const Text('Điện thoại', style: TextStyle(fontSize: 11)),
                          onPressed: () => _applySpecsPreset('phone'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.laptop, size: 14),
                          label: const Text('Laptop', style: TextStyle(fontSize: 11)),
                          onPressed: () => _applySpecsPreset('laptop'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.headphones, size: 14),
                          label: const Text('Tai nghe', style: TextStyle(fontSize: 11)),
                          onPressed: () => _applySpecsPreset('audio'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.watch, size: 14),
                          label: const Text('Đồng hồ', style: TextStyle(fontSize: 11)),
                          onPressed: () => _applySpecsPreset('watch'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          avatar: const Icon(Icons.cable, size: 14),
                          label: const Text('Phụ kiện', style: TextStyle(fontSize: 11)),
                          onPressed: () => _applySpecsPreset('acc'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _specsCtrl,
                    maxLines: 5,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Nội dung JSON',
                      hintText: '{\n  "ram": "8GB",\n  "cpu": "A18 Pro"\n}',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Upload ảnh Cloudinary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hình ảnh sản phẩm (Cloudinary):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Thêm ảnh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_selectedImages.isEmpty)
                    InkWell(
                      onTap: _pickImages,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 36, color: Colors.blueAccent),
                              SizedBox(height: 6),
                              Text('Bấm để chọn nhiều ảnh từ thiết bị', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length + 1,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          if (index == _selectedImages.length) {
                            return InkWell(
                              onTap: _pickImages,
                              child: Container(
                                width: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: const Icon(Icons.add, size: 32, color: Colors.grey),
                              ),
                            );
                          }

                          final file = _selectedImages[index];
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(file.path),
                                  width: 100,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                              if (index == 0)
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Ảnh đại diện', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 30),

                  // Nút Submit
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _submitForm,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text(
                      'ĐĂNG SẢN PHẨM LÊN APP',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Đang upload ảnh lên Cloudinary\nvà tạo sản phẩm...', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
