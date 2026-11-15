import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../services/review_api_service.dart';
import '../widgets/review_widgets.dart';

/// Admin: Xem & phản hồi đánh giá.
/// Có chủ đích KHÔNG có chức năng ẩn/xóa/sửa đánh giá của khách – Shop chỉ phản hồi công khai.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({super.key});

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  final _api = ReviewApiService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  final List<AdminReview> _items = [];
  bool? _hasReply = false; // mặc định: chưa phản hồi
  int? _rating;
  int _page = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

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

  Future<void> _load({bool reset = false}) async {
    final token = context.read<AuthProvider>().accessToken;
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
      final result = await _api.getAdminReviews(
        token,
        page: nextPage,
        rating: _rating,
        hasReply: _hasReply,
        search: _searchCtrl.text,
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

  Future<void> _openReply(AdminReview review) async {
    final ctrl = TextEditingController(text: review.adminReply ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(review.hasReply ? 'Sửa phản hồi' : 'Phản hồi đánh giá',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Phản hồi sẽ hiển thị công khai ngay dưới đánh giá của khách.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in [
                  'Cảm ơn bạn đã tin tưởng và ủng hộ TechGadget Store!',
                  'Shop rất xin lỗi vì trải nghiệm chưa tốt. Shop sẽ liên hệ để hỗ trợ bạn ngay.',
                  'Cảm ơn góp ý của bạn, Shop sẽ cải thiện dịch vụ tốt hơn.',
                ])
                  ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 11)),
                    onPressed: () => ctrl.text = t,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(hintText: 'Nhập phản hồi...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (review.hasReply)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, ''),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Gỡ phản hồi'),
                  ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Gửi phản hồi')),
              ],
            ),
          ],
        ),
      ),
    );
    // Dispose sau khi animation đóng sheet kết thúc để tránh dùng controller đã hủy
    Future.delayed(const Duration(milliseconds: 500), ctrl.dispose);

    if (result == null || !mounted) return;
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;

    try {
      final updated = await _api.reply(token, review.id, result.trim().isEmpty ? null : result.trim());
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((x) => x.id == review.id);
        if (idx < 0) return;
        // Đang lọc "chưa phản hồi" mà vừa phản hồi xong → bỏ khỏi danh sách
        if (_hasReply == false && updated.hasReply) {
          _items.removeAt(idx);
          _totalCount = _totalCount > 0 ? _totalCount - 1 : 0;
        } else {
          _items[idx] = updated;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(updated.hasReply ? 'Đã gửi phản hồi.' : 'Đã gỡ phản hồi.'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Quản lý đánh giá'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : () => _load(reset: true)),
        ],
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
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () => _load(reset: true));
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên sản phẩm hoặc nội dung',
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
                    children: [
                      _chip('Chưa phản hồi', _hasReply == false, () => _hasReply = false),
                      _chip('Đã phản hồi', _hasReply == true, () => _hasReply = true),
                      _chip('Tất cả', _hasReply == null, () => _hasReply = null),
                      const VerticalDivider(width: 16),
                      _chip('Mọi số sao', _rating == null, () => _rating = null),
                      for (final s in [1, 2, 3, 4, 5]) _chip('$s★', _rating == s, () => _rating = s),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đảm bảo minh bạch: Shop không thể ẩn, xóa hay sửa đánh giá của khách – chỉ có thể phản hồi công khai.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
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

  Widget _chip(String label, bool selected, VoidCallback apply) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) {
            setState(apply);
            _load(reset: true);
          },
        ),
      );

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _load(reset: true), child: const Text('Thử lại')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: _items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Icon(Icons.reviews_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _hasReply == false ? 'Tuyệt vời! Không còn đánh giá nào chờ phản hồi.' : 'Không có đánh giá nào.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _items.length + 2,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('$_totalCount đánh giá', style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                if (i == _items.length + 1) {
                  if (_page >= _totalPages) return const SizedBox(height: 24);
                  return Center(
                    child: _loadingMore
                        ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                        : TextButton(onPressed: () => _load(), child: const Text('Tải thêm')),
                  );
                }
                final r = _items[i - 1];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: r.rating <= 2 && !r.hasReply ? Colors.red.shade200 : Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ReviewCard(
                      review: r,
                      productName: r.productName,
                      footer: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openReply(r),
                          icon: Icon(r.hasReply ? Icons.edit_outlined : Icons.reply, size: 18),
                          label: Text(r.hasReply ? 'Sửa phản hồi' : 'Phản hồi'),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
