import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/voucher.dart';
import '../providers/auth_provider.dart';
import '../services/voucher_api_service.dart';
import '../widgets/voucher_ticket.dart';

/// Admin: Tạo mới / chỉnh sửa voucher.
/// Khi voucher đã có khách lưu (isLocked), không cho sửa mã, loại giảm, mức giảm, giảm tối đa, đơn tối thiểu.
class AdminVoucherFormScreen extends StatefulWidget {
  final AdminVoucher? voucher;

  const AdminVoucherFormScreen({super.key, this.voucher});

  bool get isEdit => voucher != null;

  @override
  State<AdminVoucherFormScreen> createState() => _AdminVoucherFormScreenState();
}

/// Dữ liệu tạm để vẽ thẻ xem trước
class _PreviewVoucher with VoucherDisplay {
  @override
  final String code;
  @override
  final String discountType;
  @override
  final double discountValue;
  @override
  final double? maxDiscount;
  @override
  final double minOrderValue;
  @override
  final DateTime endsAt;

  _PreviewVoucher({
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.maxDiscount,
    required this.minOrderValue,
    required this.endsAt,
  });
}

class _AdminVoucherFormScreenState extends State<AdminVoucherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = VoucherApiService();

  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _qtyCtrl;

  late String _discountType;
  late DateTime _startsAt;
  late DateTime _endsAt;
  late bool _isActive;
  late bool _isPublic;
  bool _saving = false;

  bool get _locked => widget.voucher?.isLocked ?? false;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;
    String fmt(double? x) => x == null ? '' : (x % 1 == 0 ? x.toInt().toString() : x.toString());

    _codeCtrl = TextEditingController(text: v?.code ?? '');
    _nameCtrl = TextEditingController(text: v?.name ?? '');
    _descCtrl = TextEditingController(text: v?.description ?? '');
    _valueCtrl = TextEditingController(text: fmt(v?.discountValue));
    _maxCtrl = TextEditingController(text: fmt(v?.maxDiscount));
    _minCtrl = TextEditingController(text: v == null ? '0' : fmt(v.minOrderValue));
    _qtyCtrl = TextEditingController(text: v?.totalQuantity.toString() ?? '100');
    _discountType = v?.discountType ?? 'fixed';

    final now = DateTime.now();
    _startsAt = v?.startsAt ?? DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _endsAt = v?.endsAt ?? _startsAt.add(const Duration(days: 30));
    _isActive = v?.isActive ?? true;
    _isPublic = v?.isPublic ?? true;

    for (final c in [_codeCtrl, _valueCtrl, _maxCtrl, _minCtrl]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameCtrl, _descCtrl, _valueCtrl, _maxCtrl, _minCtrl, _qtyCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim());

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_endsAt.isAfter(_startsAt)) {
      _showError('Thời gian kết thúc phải sau thời gian bắt đầu.');
      return;
    }

    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;

    final data = VoucherFormData(
      code: _codeCtrl.text.trim().toUpperCase(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      discountType: _discountType,
      discountValue: _parse(_valueCtrl.text) ?? 0,
      maxDiscount: _discountType == 'percent' ? _parse(_maxCtrl.text) : null,
      minOrderValue: _parse(_minCtrl.text) ?? 0,
      totalQuantity: int.tryParse(_qtyCtrl.text.trim()) ?? 0,
      startsAt: _startsAt,
      endsAt: _endsAt,
      isActive: _isActive,
      isPublic: _isPublic,
    );

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        await _api.updateVoucher(token, widget.voucher!.id, data);
      } else {
        await _api.createVoucher(token, data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Đã cập nhật voucher.' : 'Đã đăng voucher ${data.code}!'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _PreviewVoucher(
      code: _codeCtrl.text.trim().isEmpty ? 'MAVOUCHER' : _codeCtrl.text.trim().toUpperCase(),
      discountType: _discountType,
      discountValue: _parse(_valueCtrl.text) ?? 0,
      maxDiscount: _parse(_maxCtrl.text),
      minOrderValue: _parse(_minCtrl.text) ?? 0,
      endsAt: _endsAt,
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEdit ? 'Sửa voucher' : 'Tạo voucher mới')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Xem trước', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            VoucherTicket(
              voucher: preview,
              title: _nameCtrl.text.trim().isEmpty ? 'Tên voucher' : _nameCtrl.text.trim(),
            ),
            if (_locked)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.amber.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Đã có ${widget.voucher!.claimedCount} khách lưu voucher này nên không thể đổi mã và mức giảm. '
                        'Bạn vẫn có thể sửa tên, mô tả, thời gian, số lượng và trạng thái.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            // ---- Thông tin chung ----
            TextFormField(
              controller: _codeCtrl,
              enabled: !_locked,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
                LengthLimitingTextInputFormatter(30),
              ],
              decoration: const InputDecoration(
                labelText: 'Mã voucher *',
                hintText: 'VD: TECH50K',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Mã voucher tối thiểu 3 ký tự' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị *',
                hintText: 'VD: Giảm 50K cho đơn từ 1 triệu',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên voucher' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Mô tả (tuỳ chọn)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            // ---- Mức giảm ----
            const Text('Loại giảm giá', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'fixed', label: Text('Số tiền'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: 'percent', label: Text('Phần trăm'), icon: Icon(Icons.percent)),
              ],
              selected: {_discountType},
              onSelectionChanged: _locked ? null : (s) => setState(() => _discountType = s.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _valueCtrl,
              enabled: !_locked,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _discountType == 'percent' ? 'Phần trăm giảm (%) *' : 'Số tiền giảm (đ) *',
                suffixText: _discountType == 'percent' ? '%' : 'đ',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final n = _parse(v ?? '');
                if (n == null || n <= 0) return 'Giá trị giảm phải lớn hơn 0';
                if (_discountType == 'percent' && n > 100) return 'Không được vượt quá 100%';
                return null;
              },
            ),
            if (_discountType == 'percent') ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _maxCtrl,
                enabled: !_locked,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Giảm tối đa (đ) – để trống nếu không giới hạn',
                  suffixText: 'đ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _minCtrl,
              enabled: !_locked,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Giá trị đơn tối thiểu (đ)',
                suffixText: 'đ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Số lượng (số suất được lưu) *',
                helperText: _locked ? 'Không được nhỏ hơn ${widget.voucher!.claimedCount} (số suất đã lưu)' : null,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1) return 'Số lượng phải từ 1 trở lên';
                if (_locked && n < widget.voucher!.claimedCount) {
                  return 'Không được nhỏ hơn ${widget.voucher!.claimedCount}';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ---- Thời gian ----
            const Text('Thời gian áp dụng', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _dateTile('Bắt đầu', _startsAt, () => _pickDateTime(isStart: true))),
                const SizedBox(width: 10),
                Expanded(child: _dateTile('Kết thúc', _endsAt, () => _pickDateTime(isStart: false))),
              ],
            ),
            const SizedBox(height: 12),

            // ---- Trạng thái ----
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hiển thị trong Kho voucher'),
              subtitle: const Text('Tắt để tạo voucher ẩn – khách chỉ lưu được khi nhập đúng mã'),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kích hoạt'),
              subtitle: const Text('Tắt để tạm ngừng – khách không lưu và không dùng được'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(widget.isEdit ? Icons.save_outlined : Icons.campaign_outlined),
              label: Text(widget.isEdit ? 'Lưu thay đổi' : 'Đăng voucher'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(formatVoucherDate(value), style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
