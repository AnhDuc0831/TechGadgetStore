import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../services/review_api_service.dart';
import '../widgets/review_widgets.dart';

/// Danh sách toàn bộ đánh giá của 1 sản phẩm (có lọc theo sao / có ảnh, phân trang)
class ProductReviewsScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final int? initialRating;
  final bool initialHasImages;

  const ProductReviewsScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.initialRating,
    this.initialHasImages = false,
  });

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  final _api = ReviewApiService();
  final _scroll = ScrollController();

  ReviewSummary _summary = ReviewSummary.empty();
  final List<Review> _items = [];
  int? _rating;
  bool _hasImages = false;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _hasImages = widget.initialHasImages;
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final token = context.read<AuthProvider>().accessToken;
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
      final result = await _api.getProductReviews(
        widget.productId,
        accessToken: token,
        page: nextPage,
        pageSize: 10,
        rating: _rating,
        hasImages: _hasImages,
      );
      if (!mounted) return;
      setState(() {
        _summary = result.summary;
        if (reset) _items.clear();
        _items.addAll(result.items);
        _page = nextPage;
        _totalPages = result.totalPages;
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

  void _loadMore() {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Đánh giá sản phẩm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.productName,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: () => _load(reset: true), child: const Text('Thử lại')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      ReviewSummaryHeader(summary: _summary),
                      const SizedBox(height: 16),
                      ReviewFilterBar(
                        summary: _summary,
                        rating: _rating,
                        hasImages: _hasImages,
                        onChanged: (r, img) {
                          setState(() {
                            _rating = r;
                            _hasImages = img;
                          });
                          _load(reset: true);
                        },
                      ),
                      const SizedBox(height: 4),
                      if (_loading) const LinearProgressIndicator(minHeight: 2),
                      if (_items.isEmpty && !_loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Text('Chưa có đánh giá phù hợp.',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      ..._items.map((r) => ReviewCard(review: r)),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
    );
  }
}
