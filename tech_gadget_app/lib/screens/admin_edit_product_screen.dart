import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../services/product_api_service.dart';

class AdminEditProductScreen extends StatefulWidget {
  final String productId;

  const AdminEditProductScreen({super.key, required this.productId});

  @override
  State<AdminEditProductScreen> createState() => _AdminEditProductScreenState();
}

class _AdminEditProductScreenState extends State<AdminEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productService = ProductApiService();
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _basePriceCtrl = TextEditingController();
  final _discountPriceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _specsCtrl = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedBrandId;
  bool _isActive = true;

  List<Category> _categories = [];
  List<Brand> _brands = [];
  List<String> _existingImages = [];
  final List<XFile> _newImages = [];

  bool _isLoading = false;
  bool _isInitDataLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
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

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitDataLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken ?? '';

      final results = await Future.wait([
        _productService.getCategories(),
        _productService.getBrands(),
        _productService.getAdminProductById(widget.productId, accessToken: token),
      ]);

      final categories = results[0] as List<Category>;
      final brands = results[1] as List<Brand>;
      final product = results[2] as ProductDetail;

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _brands = brands;

        _nameCtrl.text = product.name;
        _selectedCategoryId = product.category.id;
        _selectedBrandId = product.brand.id;
        _basePriceCtrl.text = product.basePrice.toStringAsFixed(0);
        if (product.discountPrice != null) {
          _discountPriceCtrl.text = product.discountPrice!.toStringAsFixed(0);
        }
        _stockCtrl.text = (product.totalStockQuantity > 0
                ? product.totalStockQuantity
                : (product.variants.isNotEmpty ? product.variants.first.stockQuantity : 0))
            .toString();
        _skuCtrl.text = product.variants.isNotEmpty ? product.variants.first.sku : '';
        _descCtrl.text = product.description ?? '';
        _isActive = product.isActive;

        // Định dạng specifications
        try {
          final parsed = jsonDecode(product.specifications);
          const encoder = JsonEncoder.withIndent('  ');
          _specsCtrl.text = encoder.convert(parsed);
        } catch (_) {
          _specsCtrl.text = product.specifications;
        }

        // Ảnh hiện tại
        _existingImages = List<String>.from(product.images);
        if (_existingImages.isEmpty && product.thumbnailUrl != null) {
          _existingImages.add(product.thumbnailUrl!);
        }

        _isInitDataLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi khi tải thông tin sản phẩm: $e';
        _isInitDataLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newImages.addAll(pickedFiles);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImages.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn danh mục cho sản phẩm')),
      );
      return;
    }

    if (_selectedBrandId == null || _selectedBrandId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thương hiệu')),
      );
      return;
    }

    final basePrice = double.tryParse(_basePriceCtrl.text.trim()) ?? 0;
    final discountPrice = _discountPriceCtrl.text.trim().isNotEmpty
        ? double.tryParse(_discountPriceCtrl.text.trim())
        : null;

    if (discountPrice != null && discountPrice > basePrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giá khuyến mãi không được lớn hơn giá gốc')),
      );
      return;
    }

    // Kiểm tra định dạng JSON của specifications
    String validSpecs = '{}';
    if (_specsCtrl.text.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(_specsCtrl.text.trim());
        validSpecs = jsonEncode(decoded);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Thông số kỹ thuật JSON không hợp lệ: $e')),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.accessToken;

      if (token == null) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      final dto = UpdateProductDto(
        name: _nameCtrl.text.trim(),
        categoryId: _selectedCategoryId!,
        brandId: _selectedBrandId!,
        basePrice: basePrice,
        discountPrice: discountPrice,
        stockQuantity: int.tryParse(_stockCtrl.text.trim()) ?? 0,
        sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        specifications: validSpecs,
        isActive: _isActive,
        existingImages: _existingImages,
      );

      final newPaths = _newImages.map((x) => x.path).toList();

      await _productService.updateProduct(token, widget.productId, dto, newPaths);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật sản phẩm thành công!'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Chỉnh sửa sản phẩm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0.5,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _submitUpdate,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)),
                  )
                : const Icon(Icons.check, color: Color(0xFFF97316), size: 20),
            label: const Text(
              'Lưu',
              style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isInitDataLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInitialData,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Trạng thái kinh doanh Switch
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _isActive ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                          ),
                        ),
                        color: _isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        child: SwitchListTile(
                          value: _isActive,
                          onChanged: (val) {
                            setState(() {
                              _isActive = val;
                            });
                          },
                          thumbColor: WidgetStateProperty.resolveWith((states) => _isActive ? const Color(0xFF16A34A) : Colors.grey),
                          title: Text(
                            _isActive ? 'Đang kinh doanh (Hiển thị)' : 'Ngừng kinh doanh (Đã ẩn)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isActive ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            ),
                          ),
                          subtitle: Text(
                            _isActive
                                ? 'Sản phẩm đang được bày bán cho khách hàng trên cửa hàng.'
                                : 'Sản phẩm đang tạm ẩn khỏi danh mục cửa hàng.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Thông tin cơ bản
                      _buildSectionTitle('1. Thông tin cơ bản', Icons.info_outline),
                      const SizedBox(height: 8),
                      _buildCard(
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Tên sản phẩm *',
                                hintText: 'Nhập tên đầy đủ của sản phẩm',
                                prefixIcon: Icon(Icons.shopping_bag_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Vui lòng nhập tên sản phẩm' : null,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCategoryId,
                                    decoration: const InputDecoration(
                                      labelText: 'Danh mục *',
                                      prefixIcon: Icon(Icons.category_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _categories.map((c) {
                                      return DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                                    validator: (val) => val == null ? 'Chọn danh mục' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedBrandId,
                                    decoration: const InputDecoration(
                                      labelText: 'Thương hiệu *',
                                      prefixIcon: Icon(Icons.branding_watermark_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _brands.map((b) {
                                      return DropdownMenuItem(
                                        value: b.id,
                                        child: Text(b.name, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedBrandId = val),
                                    validator: (val) => val == null ? 'Chọn thương hiệu' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _skuCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Mã SKU',
                                hintText: 'VD: TG-IP16PM-256',
                                prefixIcon: Icon(Icons.qr_code),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Giá & Kho
                      _buildSectionTitle('2. Giá bán & Tồn kho', Icons.attach_money),
                      const SizedBox(height: 8),
                      _buildCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _basePriceCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Giá niêm yết (gốc) *',
                                      suffixText: '₫',
                                      prefixIcon: Icon(Icons.price_check),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Nhập giá gốc';
                                      if (double.tryParse(val) == null) return 'Giá không hợp lệ';
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
                                      labelText: 'Giá khuyến mãi',
                                      suffixText: '₫',
                                      prefixIcon: Icon(Icons.local_offer_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _stockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Số lượng trong kho *',
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Nhập số lượng';
                                if (int.tryParse(val) == null) return 'Phải là số nguyên';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quản lý hình ảnh
                      _buildSectionTitle('3. Hình ảnh sản phẩm', Icons.photo_library_outlined),
                      const SizedBox(height: 8),
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tổng: ${_existingImages.length + _newImages.length} ảnh',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickImages,
                                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                                  label: const Text('Thêm ảnh mới'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFF97316),
                                    side: const BorderSide(color: Color(0xFFF97316)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (_existingImages.isEmpty && _newImages.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(Icons.image_outlined, size: 36, color: Colors.grey),
                                    SizedBox(height: 6),
                                    Text('Chưa có hình ảnh nào', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                height: 110,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    // Ảnh hiện tại
                                    ..._existingImages.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final url = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.network(
                                                url,
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, p1, p2) => Container(
                                                  width: 100,
                                                  height: 100,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () => _removeExistingImage(idx),
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                            if (idx == 0)
                                              Positioned(
                                                bottom: 4,
                                                left: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.6),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Bìa',
                                                    style: TextStyle(color: Colors.white, fontSize: 10),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),

                                    // Ảnh mới chọn
                                    ..._newImages.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final file = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.file(
                                                File(file.path),
                                                width: 100,
                                                height: 100,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () => _removeNewImage(idx),
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 4,
                                              left: 4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withValues(alpha: 0.8),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Mới',
                                                  style: TextStyle(color: Colors.white, fontSize: 10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mô tả & Thông số
                      _buildSectionTitle('4. Mô tả & Thông số kỹ thuật', Icons.description_outlined),
                      const SizedBox(height: 8),
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _descCtrl,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Mô tả chi tiết',
                                hintText: 'Giới thiệu tính năng, cấu hình, ưu điểm nổi bật...',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _specsCtrl,
                              maxLines: 6,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              decoration: const InputDecoration(
                                labelText: 'Thông số kỹ thuật (JSON format)',
                                hintText: '{\n  "ram": "8GB",\n  "pin": "5000 mAh"\n}',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nút lưu
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Đang lưu thay đổi...'),
                                ],
                              )
                            : const Text(
                                'LƯU THAY ĐỔI SẢN PHẨM',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFF97316)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1F2937)),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
