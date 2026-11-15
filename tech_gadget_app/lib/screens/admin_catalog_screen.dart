import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/catalog_admin.dart';
import '../providers/auth_provider.dart';
import '../services/catalog_admin_api_service.dart';

/// Admin: Quản lý Danh mục & Thương hiệu (2 tab).
class AdminCatalogScreen extends StatefulWidget {
  final int initialTab;

  const AdminCatalogScreen({super.key, this.initialTab = 0});

  @override
  State<AdminCatalogScreen> createState() => _AdminCatalogScreenState();
}

class _AdminCatalogScreenState extends State<AdminCatalogScreen> with SingleTickerProviderStateMixin {
  final _api = CatalogAdminApiService();
  late final TabController _tab;

  List<AdminCategory> _categories = [];
  List<AdminBrand> _brands = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) setState(() {}); // cập nhật nhãn nút "Thêm"
    });
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthProvider>().accessToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_api.getCategories(token), _api.getBrands(token)]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<AdminCategory>;
        _brands = results[1] as List<AdminBrand>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green.shade600 : Colors.red.shade700),
    );
  }

  Future<void> _openForm({AdminCategory? category, AdminBrand? brand, required bool isCategory}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CatalogFormSheet(isCategory: isCategory, category: category, brand: brand),
    );
    if (saved == true) _load();
  }

  Future<void> _delete({AdminCategory? category, AdminBrand? brand}) async {
    final name = category?.name ?? brand!.name;
    final kind = category != null ? 'danh mục' : 'thương hiệu';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa $kind?'),
        content: Text('"$name" sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final token = _token;
    if (token == null) return;
    try {
      if (category != null) {
        await _api.deleteCategory(token, category.id);
      } else {
        await _api.deleteBrand(token, brand!.id);
      }
      if (!mounted) return;
      _snack('Đã xóa $kind "$name".', success: true);
      _load();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCategoryTab = _tab.index == 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Danh mục & Thương hiệu'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: 'Danh mục (${_categories.length})'),
            Tab(text: 'Thương hiệu (${_brands.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(isCategory: isCategoryTab),
        icon: const Icon(Icons.add),
        label: Text(isCategoryTab ? 'Thêm danh mục' : 'Thêm thương hiệu'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tab,
                  children: [_buildCategoryList(), _buildBrandList()],
                ),
    );
  }

  Widget _buildCategoryList() {
    if (_categories.isEmpty) return _empty('Chưa có danh mục nào.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c = _categories[i];
          return _tile(
            imageUrl: c.imageUrl,
            fallbackIcon: Icons.category_outlined,
            title: c.name,
            subtitle: '/${c.slug} · ${c.productCount} sản phẩm',
            canDelete: c.canDelete,
            onEdit: () => _openForm(isCategory: true, category: c),
            onDelete: () => _delete(category: c),
          );
        },
      ),
    );
  }

  Widget _buildBrandList() {
    if (_brands.isEmpty) return _empty('Chưa có thương hiệu nào.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _brands.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final b = _brands[i];
          return _tile(
            imageUrl: b.logoUrl,
            fallbackIcon: Icons.business_outlined,
            title: b.name,
            subtitle: '${b.productCount} sản phẩm',
            canDelete: b.canDelete,
            onEdit: () => _openForm(isCategory: false, brand: b),
            onDelete: () => _delete(brand: b),
          );
        },
      ),
    );
  }

  Widget _empty(String text) => ListView(
        children: [
          const SizedBox(height: 100),
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ],
      );

  Widget _tile({
    required String? imageUrl,
    required IconData fallbackIcon,
    required String title,
    required String subtitle,
    required bool canDelete,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onEdit,
        leading: _Thumb(url: imageUrl, fallbackIcon: fallbackIcon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Sửa'))),
            PopupMenuItem(
              value: 'delete',
              enabled: canDelete,
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: canDelete ? Colors.red : Colors.grey),
                title: Text('Xóa', style: TextStyle(color: canDelete ? Colors.red : Colors.grey)),
                subtitle: canDelete ? null : const Text('Còn sản phẩm', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final IconData fallbackIcon;
  final String? localPath;
  final double size;

  const _Thumb({this.url, required this.fallbackIcon, this.localPath, this.size = 48});

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: size,
          height: size,
          color: Colors.grey.shade100,
          child: Icon(fallbackIcon, color: Colors.grey.shade400),
        );

    Widget child;
    if (localPath != null) {
      child = Image.file(File(localPath!), width: size, height: size, fit: BoxFit.cover);
    } else if (url != null && url!.isNotEmpty) {
      child = Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback());
    } else {
      child = fallback();
    }
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: child);
  }
}

/// Bottom sheet tạo / sửa danh mục hoặc thương hiệu
class _CatalogFormSheet extends StatefulWidget {
  final bool isCategory;
  final AdminCategory? category;
  final AdminBrand? brand;

  const _CatalogFormSheet({required this.isCategory, this.category, this.brand});

  bool get isEdit => category != null || brand != null;

  @override
  State<_CatalogFormSheet> createState() => _CatalogFormSheetState();
}

class _CatalogFormSheetState extends State<_CatalogFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _api = CatalogAdminApiService();
  final _picker = ImagePicker();

  late final TextEditingController _name;
  late final TextEditingController _slug;
  late final TextEditingController _desc;
  String? _pickedPath;
  bool _removeImage = false;
  bool _saving = false;

  String? get _currentImageUrl => widget.category?.imageUrl ?? widget.brand?.logoUrl;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? widget.brand?.name ?? '');
    _slug = TextEditingController(text: widget.category?.slug ?? '');
    _desc = TextEditingController(text: widget.category?.description ?? '');
    _name.addListener(() => setState(() {}));
    _slug.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
      if (x != null && mounted) {
        setState(() {
          _pickedPath = x.path;
          _removeImage = false;
        });
      }
    } catch (e) {
      _error('Không thể chọn ảnh: $e');
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;

    setState(() => _saving = true);
    try {
      if (widget.isCategory) {
        await _api.saveCategory(
          token,
          id: widget.category?.id,
          name: _name.text,
          slug: _slug.text,
          description: _desc.text,
          imagePath: _pickedPath,
          removeImage: _removeImage,
        );
      } else {
        await _api.saveBrand(
          token,
          id: widget.brand?.id,
          name: _name.text,
          logoPath: _pickedPath,
          removeLogo: _removeImage,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Đã lưu thay đổi.' : 'Đã thêm "${_name.text.trim()}".'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.isCategory ? 'danh mục' : 'thương hiệu';
    final hasImage = _pickedPath != null || (!_removeImage && (_currentImageUrl?.isNotEmpty ?? false));
    final slugPreview = slugify(_slug.text.trim().isEmpty ? _name.text : _slug.text);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.isEdit ? 'Sửa $kind' : 'Thêm $kind',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Ảnh / logo
              Row(
                children: [
                  _Thumb(
                    url: _removeImage ? null : _currentImageUrl,
                    localPath: _pickedPath,
                    fallbackIcon: widget.isCategory ? Icons.category_outlined : Icons.business_outlined,
                    size: 72,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _pickImage,
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: Text(widget.isCategory ? 'Chọn ảnh' : 'Chọn logo'),
                        ),
                        if (hasImage)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _pickedPath = null;
                                      _removeImage = true;
                                    }),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Gỡ ảnh'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: 'Tên $kind *',
                  hintText: widget.isCategory ? 'VD: Đồng hồ thông minh' : 'VD: Xiaomi',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên $kind' : null,
              ),

              if (widget.isCategory) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _slug,
                  decoration: InputDecoration(
                    labelText: 'Đường dẫn (slug) – để trống sẽ tự tạo',
                    helperText: slugPreview.isEmpty ? null : 'Sẽ lưu là: /$slugPreview',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Mô tả (tuỳ chọn)', border: OutlineInputBorder()),
                ),
              ],

              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isEdit ? 'Lưu thay đổi' : 'Thêm $kind'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bản xem trước slug phía app (server mới là nơi chuẩn hóa chính thức).
String slugify(String input) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final lower = input.trim().toLowerCase();
  final sb = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    sb.write(i >= 0 ? to[i] : ch);
  }
  return sb
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}
