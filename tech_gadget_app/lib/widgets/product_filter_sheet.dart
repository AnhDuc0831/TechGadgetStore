import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../utils/formatters.dart';

/// Kết quả bộ lọc trả về khi người dùng bấm "Áp dụng"
class ProductFilter {
  final Set<String> brandIds;
  final int? minPrice;
  final int? maxPrice;

  const ProductFilter({this.brandIds = const {}, this.minPrice, this.maxPrice});

  bool get hasPriceRange => minPrice != null || maxPrice != null;

  /// Số bộ lọc đang bật (hiển thị trên badge nút "Lọc")
  int get activeCount => brandIds.length + (hasPriceRange ? 1 : 0);
}

class _PricePreset {
  final String label;
  final int? min;
  final int? max;

  const _PricePreset(this.label, this.min, this.max);
}

const _pricePresets = [
  _PricePreset('Dưới 5 triệu', null, 5000000),
  _PricePreset('5 - 10 triệu', 5000000, 10000000),
  _PricePreset('10 - 20 triệu', 10000000, 20000000),
  _PricePreset('Trên 20 triệu', 20000000, null),
];

/// Bottom sheet lọc theo thương hiệu và khoảng giá
class ProductFilterSheet extends StatefulWidget {
  final List<Brand> brands;
  final ProductFilter initialFilter;

  const ProductFilterSheet({super.key, required this.brands, required this.initialFilter});

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late final Set<String> _brandIds = Set.of(widget.initialFilter.brandIds);
  late final TextEditingController _minController =
      TextEditingController(text: widget.initialFilter.minPrice?.toString() ?? '');
  late final TextEditingController _maxController =
      TextEditingController(text: widget.initialFilter.maxPrice?.toString() ?? '');
  String? _priceError;

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  int? get _minPrice => int.tryParse(_minController.text);
  int? get _maxPrice => int.tryParse(_maxController.text);

  void _selectPreset(_PricePreset preset) {
    setState(() {
      _minController.text = preset.min?.toString() ?? '';
      _maxController.text = preset.max?.toString() ?? '';
      _priceError = null;
    });
  }

  void _reset() {
    setState(() {
      _brandIds.clear();
      _minController.clear();
      _maxController.clear();
      _priceError = null;
    });
  }

  void _apply() {
    final min = _minPrice;
    final max = _maxPrice;
    if (min != null && max != null && min > max) {
      setState(() => _priceError = 'Giá "Từ" không được lớn hơn giá "Đến".');
      return;
    }
    Navigator.pop(context, ProductFilter(brandIds: _brandIds, minPrice: min, maxPrice: max));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const titleStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

    return SafeArea(
      child: Padding(
        // Đẩy nội dung lên khi bàn phím hiện
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bộ lọc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(onPressed: _reset, child: const Text('Bỏ chọn tất cả')),
                ],
              ),
              const SizedBox(height: 8),

              // Thương hiệu
              const Text('Thương hiệu', style: titleStyle),
              const SizedBox(height: 8),
              if (widget.brands.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Chưa có thương hiệu nào.'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.brands.map((brand) {
                    return FilterChip(
                      label: Text(brand.name),
                      selected: _brandIds.contains(brand.id),
                      onSelected: (selected) => setState(() {
                        selected ? _brandIds.add(brand.id) : _brandIds.remove(brand.id);
                      }),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),

              // Khoảng giá
              const Text('Khoảng giá (₫)', style: titleStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _pricePresets.map((preset) {
                  final selected = _minPrice == preset.min && _maxPrice == preset.max;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => _selectPreset(preset),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildPriceField(_minController, 'Từ')),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('-'),
                  ),
                  Expanded(child: _buildPriceField(_maxController, 'Đến')),
                ],
              ),
              if (_priceError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _priceError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: _apply, child: const Text('Áp dụng')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceField(TextEditingController controller, String label) {
    final value = int.tryParse(controller.text);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() => _priceError = null),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        // Hiển thị giá đã định dạng để dễ đọc số 0, vd: 5.000.000 ₫
        helperText: value == null ? ' ' : formatVnd(value.toDouble()),
      ),
    );
  }
}
