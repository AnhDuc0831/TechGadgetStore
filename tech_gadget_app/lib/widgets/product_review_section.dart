import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../screens/product_reviews_screen.dart';
import '../screens/write_review_screen.dart';
import '../services/review_api_service.dart';
import 'review_widgets.dart';

/// Khối "Đánh giá sản phẩm" nhúng trong trang chi tiết sản phẩm:
/// tổng quan sao, nút viết/sửa đánh giá (nếu đã mua), 3 đánh giá mới nhất, nút xem tất cả.
class ProductReviewSection extends StatefulWidget {
  final String productId;
  final String productName;
  final String? thumbnailUrl;

  const ProductReviewSection({
    super.key,
    required this.productId,
    required this.productName,
    this.thumbnailUrl,
  });

  @override
  State<ProductReviewSection> createState() => _ProductReviewSectionState();
}

class _ProductReviewSectionState extends State<ProductReviewSection> {
  final _api = ReviewApiService();

  ProductReviewsPage? _page;
  MyReviewStatus? _myStatus;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().accessToken;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await _api.getProductReviews(widget.productId, accessToken: token, pageSize: 3);
      MyReviewStatus? status;
      if (token != null) {
        try {
          status = await _api.getMyStatus(token, widget.productId);
        } catch (_) {
          // Không chặn hiển thị đánh giá nếu không kiểm tra được quyền
        }
      }
      if (!mounted) return;
      setState(() {
        _page = page;
        _myStatus = status;
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

  Future<void> _openWrite() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteReviewScreen(
          productId: widget.productId,
          productName: widget.productName,
          thumbnailUrl: widget.thumbnailUrl,
        ),
      ),
    );
    if (done == true) _load();
  }

  void _openAll({int? rating, bool hasImages = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductReviewsScreen(
          productId: widget.productId,
          productName: widget.productName,
          initialRating: rating,
          initialHasImages: hasImages,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Đánh giá sản phẩm', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Row(
            children: [
              Expanded(child: Text('Không tải được đánh giá: $_error', style: TextStyle(color: Colors.grey.shade600))),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          )
        else ...[
          ReviewSummaryHeader(summary: _page!.summary),
          const SizedBox(height: 12),
          _buildMyReviewAction(),
          if (_page!.summary.totalCount > 0) ...[
            const SizedBox(height: 8),
            ReviewFilterBar(
              summary: _page!.summary,
              rating: null,
              hasImages: false,
              onChanged: (r, img) => _openAll(rating: r, hasImages: img),
            ),
          ],
          if (_page!.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Chưa có đánh giá nào. Hãy là người đầu tiên đánh giá sau khi mua sản phẩm!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ..._page!.items.map((r) => ReviewCard(review: r, onEdit: r.isMine ? _openWrite : null)),
          if (_page!.summary.totalCount > _page!.items.length)
            TextButton(
              onPressed: () => _openAll(),
              child: Text('Xem tất cả ${_page!.summary.totalCount} đánh giá'),
            ),
        ],
      ],
    );
  }

  Widget _buildMyReviewAction() {
    final status = _myStatus;
    if (status == null || !status.canReview) return const SizedBox.shrink();

    final hasReview = status.myReview != null;
    return OutlinedButton.icon(
      onPressed: _openWrite,
      icon: Icon(hasReview ? Icons.edit_outlined : Icons.rate_review_outlined),
      label: Text(hasReview ? 'Sửa đánh giá của bạn' : 'Viết đánh giá'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
