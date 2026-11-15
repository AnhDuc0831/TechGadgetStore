import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/voucher.dart';
import '../providers/auth_provider.dart';
import '../services/voucher_api_service.dart';
import '../utils/formatters.dart';
import '../widgets/voucher_ticket.dart';

/// Màn hình Voucher của khách hàng:
///  - Tab "Kho voucher": voucher công khai do Admin đăng, bấm "Lưu" để đưa vào ví
///  - Tab "Ví của tôi": voucher đã lưu (Có thể dùng / Đã dùng / Hết hạn)
///  - Ô nhập mã để lưu voucher bằng mã (kể cả voucher ẩn)
class VoucherCenterScreen extends StatefulWidget {
  final int initialTab;

  const VoucherCenterScreen({super.key, this.initialTab = 0});

  @override
  State<VoucherCenterScreen> createState() => _VoucherCenterScreenState();
}

class _VoucherCenterScreenState extends State<VoucherCenterScreen> with SingleTickerProviderStateMixin {
  final _api = VoucherApiService();
  final _codeController = TextEditingController();
  late final TabController _tabController;

  List<PublicVoucher> _publicVouchers = [];
  List<MyVoucher> _myVouchers = [];
  bool _loading = true;
  String? _error;
  final Set<String> _claimingIds = {};
  bool _claimingCode = false;
  String _walletFilter = 'available'; // available | used | inactive

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthProvider>().accessToken;

  Future<void> _loadAll() async {
    final token = _token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Vui lòng đăng nhập để xem voucher.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getPublicVouchers(token),
        _api.getMyVouchers(token),
      ]);
      if (!mounted) return;
      setState(() {
        _publicVouchers = results[0] as List<PublicVoucher>;
        _myVouchers = results[1] as List<MyVoucher>;
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

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green.shade600 : Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _claim(PublicVoucher voucher) async {
    final token = _token;
    if (token == null) return;

    setState(() => _claimingIds.add(voucher.id));
    try {
      await _api.claim(token, voucher.id);
      if (!mounted) return;
      _showSnack('Đã lưu voucher ${voucher.code} vào ví!', success: true);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
      await _loadAll();
    } finally {
      if (mounted) setState(() => _claimingIds.remove(voucher.id));
    }
  }

  Future<void> _claimByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showSnack('Vui lòng nhập mã voucher.');
      return;
    }
    final token = _token;
    if (token == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _claimingCode = true);
    try {
      final v = await _api.claimByCode(token, code);
      if (!mounted) return;
      _codeController.clear();
      _showSnack('Đã lưu voucher ${v.code} vào ví!', success: true);
      await _loadAll();
      if (mounted) {
        setState(() => _walletFilter = 'available');
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _claimingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableCount = _myVouchers.where((v) => v.isAvailable).length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Voucher của tôi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Kho voucher'),
            Tab(text: availableCount > 0 ? 'Ví của tôi ($availableCount)' : 'Ví của tôi'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildCodeInput(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStoreTab(),
                          _buildWalletTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _claimByCode(),
              decoration: InputDecoration(
                hintText: 'Nhập mã voucher',
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _claimingCode ? null : _claimByCode,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _claimingCode
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String message, IconData icon) {
    return ListView(
      // ListView để RefreshIndicator vẫn kéo được
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  // ---------------- TAB KHO VOUCHER ----------------

  Widget _buildStoreTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: _publicVouchers.isEmpty
          ? _buildEmpty('Hiện chưa có voucher nào.\nHãy quay lại sau nhé!', Icons.local_offer_outlined)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _publicVouchers.length,
              itemBuilder: (context, index) {
                final v = _publicVouchers[index];
                final claiming = _claimingIds.contains(v.id);

                Widget trailing;
                if (v.isClaimed) {
                  trailing = _badge('Đã lưu', Colors.green);
                } else if (v.isSoldOut) {
                  trailing = _badge('Hết suất', Colors.grey);
                } else {
                  trailing = FilledButton(
                    onPressed: claiming ? null : () => _claim(v),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: claiming
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Lưu'),
                  );
                }

                return VoucherTicket(
                  voucher: v,
                  title: v.name,
                  dimmed: v.isSoldOut && !v.isClaimed,
                  trailing: trailing,
                  footer: _buildQuantityBar(v),
                );
              },
            ),
    );
  }

  Widget _buildQuantityBar(PublicVoucher v) {
    final almostOut = v.remainingQuantity > 0 && v.remainingQuantity <= (v.totalQuantity * 0.2).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: v.claimedRatio,
            minHeight: 5,
            backgroundColor: Colors.grey.shade200,
            color: almostOut ? Colors.red : Colors.orange,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          v.isUpcoming
              ? 'Bắt đầu: ${formatVoucherDate(v.startsAt)} · Còn ${v.remainingQuantity}/${v.totalQuantity} suất'
              : v.isSoldOut
                  ? 'Đã hết ${v.totalQuantity} suất'
                  : 'Còn ${v.remainingQuantity}/${v.totalQuantity} suất',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: almostOut ? Colors.red : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ---------------- TAB VÍ CỦA TÔI ----------------

  Widget _buildWalletTab() {
    final filtered = _myVouchers.where((v) {
      switch (_walletFilter) {
        case 'available':
          return v.isAvailable || v.status == 'upcoming';
        case 'used':
          return v.isUsed;
        default:
          return v.isInactive;
      }
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              _filterChip('available', 'Có thể dùng'),
              const SizedBox(width: 8),
              _filterChip('used', 'Đã dùng'),
              const SizedBox(width: 8),
              _filterChip('inactive', 'Hết hạn'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAll,
            child: filtered.isEmpty
                ? _buildEmpty(
                    _walletFilter == 'available'
                        ? 'Ví của bạn chưa có voucher dùng được.\nVào "Kho voucher" để lưu nhé!'
                        : 'Không có voucher nào.',
                    Icons.wallet_giftcard_outlined,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final v = filtered[index];
                      return VoucherTicket(
                        voucher: v,
                        title: v.name,
                        dimmed: !v.isAvailable,
                        trailing: v.isAvailable ? null : _badge(v.statusLabel, v.isUsed ? Colors.blueGrey : Colors.grey),
                        footer: v.isUsed && v.usedDiscountAmount != null
                            ? Text(
                                'Đã giảm ${formatVnd(v.usedDiscountAmount!)}'
                                '${v.usedAt != null ? ' · ${formatVoucherDate(v.usedAt!)}' : ''}',
                                style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600),
                              )
                            : v.status == 'upcoming'
                                ? Text(
                                    'Dùng được từ ${formatVoucherDate(v.startsAt)}',
                                    style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                                  )
                                : null,
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _walletFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _walletFilter = value),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
