import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/voucher.dart';
import '../providers/auth_provider.dart';
import '../services/voucher_api_service.dart';
import '../widgets/voucher_ticket.dart';
import 'admin_voucher_form_screen.dart';

/// Admin: Danh sách & quản lý voucher
class AdminVouchersScreen extends StatefulWidget {
  const AdminVouchersScreen({super.key});

  @override
  State<AdminVouchersScreen> createState() => _AdminVouchersScreenState();
}

class _AdminVouchersScreenState extends State<AdminVouchersScreen> {
  static const _pageSize = 20;
  static const _filters = <String?, String>{
    null: 'Tất cả',
    'running': 'Đang chạy',
    'upcoming': 'Sắp diễn ra',
    'expired': 'Hết hạn',
    'disabled': 'Đã tắt',
  };

  final _api = VoucherApiService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  final List<AdminVoucher> _items = [];
  String? _status;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthProvider>().accessToken;

  Future<void> _load({bool reset = false}) async {
    final token = _token;
    if (token == null) return;

    final nextPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final result = await _api.getAdminVouchers(
        token,
        page: nextPage,
        pageSize: _pageSize,
        search: _searchCtrl.text,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(result.items);
        _page = nextPage;
        _totalPages = result.totalPages;
        _totalCount = result.totalCount;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
  }

  Future<void> _openForm([AdminVoucher? voucher]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminVoucherFormScreen(voucher: voucher)),
    );
    if (changed == true) _load(reset: true);
  }

  void _replaceItem(AdminVoucher updated) {
    final idx = _items.indexWhere((x) => x.id == updated.id);
    if (idx >= 0) setState(() => _items[idx] = updated);
  }

  Future<void> _toggle(AdminVoucher v) async {
    final token = _token;
    if (token == null) return;
    setState(() => _busyIds.add(v.id));
    try {
      final updated = await _api.toggleVoucher(token, v.id);
      if (!mounted) return;
      _replaceItem(updated);
      _snack(updated.isActive ? 'Đã bật voucher ${v.code}' : 'Đã tắt voucher ${v.code}', success: true);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyIds.remove(v.id));
    }
  }

  Future<void> _delete(AdminVoucher v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa voucher?'),
        content: Text('Voucher ${v.code} sẽ bị xóa vĩnh viễn.'),
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
    if (confirmed != true) return;

    final token = _token;
    if (token == null) return;
    setState(() => _busyIds.add(v.id));
    try {
      await _api.deleteVoucher(token, v.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((x) => x.id == v.id);
        _totalCount = _totalCount > 0 ? _totalCount - 1 : 0;
      });
      _snack('Đã xóa voucher ${v.code}', success: true);
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busyIds.remove(v.id));
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: success ? Colors.green.shade600 : Colors.red.shade700),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'running':
        return Colors.green;
      case 'upcoming':
        return Colors.orange;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Quản lý voucher'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : () => _load(reset: true)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tạo voucher'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo mã hoặc tên voucher',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(e.value),
                                selected: _status == e.key,
                                onSelected: (_) {
                                  setState(() => _status = e.key);
                                  _load(reset: true);
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => _load(reset: true), child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Chưa có voucher nào.\nBấm "Tạo voucher" để đăng voucher đầu tiên.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: _items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('$_totalCount voucher', style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                if (index == _items.length + 1) {
                  if (_page >= _totalPages) return const SizedBox.shrink();
                  return Center(
                    child: _loadingMore
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                        : TextButton(onPressed: () => _load(), child: const Text('Tải thêm')),
                  );
                }
                return _buildItem(_items[index - 1]);
              },
            ),
    );
  }

  Widget _buildItem(AdminVoucher v) {
    final busy = _busyIds.contains(v.id);
    final color = _statusColor(v.displayStatus);

    return VoucherTicket(
      voucher: v,
      title: v.name,
      dimmed: v.displayStatus == 'disabled' || v.displayStatus == 'expired',
      onTap: () => _openForm(v),
      footer: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _chip(v.displayStatusLabel, color),
          if (!v.isPublic) _chip('Ẩn', Colors.purple),
          Text(
            'Đã lưu ${v.claimedCount}/${v.totalQuantity} · Đã dùng ${v.usedCount}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      trailing: busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'edit':
                    _openForm(v);
                    break;
                  case 'toggle':
                    _toggle(v);
                    break;
                  case 'delete':
                    _delete(v);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Sửa'))),
                PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    leading: Icon(v.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
                    title: Text(v.isActive ? 'Tắt voucher' : 'Bật voucher'),
                  ),
                ),
                if (v.claimedCount == 0)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('Xóa', style: TextStyle(color: Colors.red)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      );
}
