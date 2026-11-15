import 'package:flutter/material.dart';
import '../models/voucher.dart';
import '../services/voucher_api_service.dart';
import '../utils/formatters.dart';
import 'voucher_ticket.dart';

/// Kết quả trả về khi đóng bottom sheet chọn voucher.
/// - `null`: người dùng đóng sheet, không thay đổi gì.
/// - `VoucherPickerResult(null)`: bỏ chọn voucher.
/// - `VoucherPickerResult(v)`: chọn voucher v.
class VoucherPickerResult {
  final MyVoucher? voucher;
  const VoucherPickerResult(this.voucher);
}

/// Bottom sheet chọn voucher từ ví ở màn hình Checkout.
/// Server tính sẵn voucher nào dùng được và giảm bao nhiêu dựa trên [subtotal].
class VoucherPickerSheet extends StatefulWidget {
  final String accessToken;
  final double subtotal;
  final String? selectedUserVoucherId;

  const VoucherPickerSheet({
    super.key,
    required this.accessToken,
    required this.subtotal,
    this.selectedUserVoucherId,
  });

  static Future<VoucherPickerResult?> show(
    BuildContext context, {
    required String accessToken,
    required double subtotal,
    String? selectedUserVoucherId,
  }) {
    return showModalBottomSheet<VoucherPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade50,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => VoucherPickerSheet(
        accessToken: accessToken,
        subtotal: subtotal,
        selectedUserVoucherId: selectedUserVoucherId,
      ),
    );
  }

  @override
  State<VoucherPickerSheet> createState() => _VoucherPickerSheetState();
}

class _VoucherPickerSheetState extends State<VoucherPickerSheet> {
  final _api = VoucherApiService();
  final _codeController = TextEditingController();

  List<MyVoucher> _vouchers = [];
  bool _loading = true;
  bool _claiming = false;
  String? _error;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedUserVoucherId;
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getMyVouchers(widget.accessToken, subtotal: widget.subtotal);
      if (!mounted) return;
      setState(() {
        // Chỉ hiện voucher còn có thể dùng (kể cả chưa đủ điều kiện), ẩn voucher đã dùng / hết hạn
        _vouchers = list.where((v) => v.isAvailable || v.status == 'upcoming').toList();
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

  Future<void> _claimByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _claiming = true);
    try {
      final claimed = await _api.claimByCode(widget.accessToken, code);
      _codeController.clear();
      await _load();
      if (!mounted) return;
      // Tự chọn luôn voucher vừa lưu nếu dùng được
      final match = _vouchers.where((v) => v.userVoucherId == claimed.userVoucherId).toList();
      if (match.isNotEmpty && match.first.isApplicable == true) {
        setState(() => _selectedId = claimed.userVoucherId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu voucher ${claimed.code}'), backgroundColor: Colors.green.shade600),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _confirm() {
    final selected = _vouchers.where((v) => v.userVoucherId == _selectedId).toList();
    Navigator.of(context).pop(VoucherPickerResult(selected.isEmpty ? null : selected.first));
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.8;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Chọn voucher', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            // Nhập mã
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (_) => _claimByCode(),
                      decoration: InputDecoration(
                        hintText: 'Nhập mã voucher',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.confirmation_number_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _claiming ? null : _claimByCode,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _claiming
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Áp dụng'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_vouchers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wallet_giftcard_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'Ví của bạn chưa có voucher.\nNhập mã ở trên hoặc vào "Kho voucher" trong mục Tài khoản để lưu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final applicable = _vouchers.where((v) => v.isApplicable == true).toList();
    final notApplicable = _vouchers.where((v) => v.isApplicable != true).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (applicable.isNotEmpty) ...[
          _sectionLabel('Có thể áp dụng (${applicable.length})'),
          ...applicable.map(_buildItem),
        ],
        if (notApplicable.isNotEmpty) ...[
          _sectionLabel('Chưa đủ điều kiện (${notApplicable.length})'),
          ...notApplicable.map(_buildItem),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      );

  Widget _buildItem(MyVoucher v) {
    final applicable = v.isApplicable == true;
    final selected = v.userVoucherId == _selectedId;

    return VoucherTicket(
      voucher: v,
      title: v.name,
      dimmed: !applicable,
      selected: selected,
      onTap: applicable ? () => setState(() => _selectedId = selected ? null : v.userVoucherId) : null,
      trailing: applicable
          ? Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? Theme.of(context).colorScheme.primary : Colors.grey,
            )
          : null,
      footer: applicable
          ? Text(
              'Giảm ${formatVnd(v.estimatedDiscount ?? 0)} cho đơn này',
              style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
            )
          : Text(
              v.ineligibleReason ?? 'Chưa đủ điều kiện',
              style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w600),
            ),
    );
  }

  Widget _buildBottomBar() {
    final selected = _vouchers.where((v) => v.userVoucherId == _selectedId).toList();
    final discount = selected.isEmpty ? 0.0 : (selected.first.estimatedDiscount ?? 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected.isEmpty ? 'Chưa chọn voucher' : 'Tiết kiệm ${formatVnd(discount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected.isEmpty ? Colors.grey : Colors.green.shade700,
                ),
              ),
            ),
            FilledButton(
              onPressed: _loading ? null : _confirm,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      ),
    );
  }
}
