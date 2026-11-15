import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/review.dart';
import '../providers/auth_provider.dart';
import '../services/review_api_service.dart';
import '../widgets/review_widgets.dart';

/// Màn hình viết / sửa đánh giá sản phẩm.
/// Trả về `true` khi gửi thành công.
class WriteReviewScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final String? thumbnailUrl;

  const WriteReviewScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.thumbnailUrl,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  static const _maxImages = 5;
  static const _maxLength = 1000;
  static const _quickTags = [
    'Đóng gói kỹ',
    'Giao hàng nhanh',
    'Đúng mô tả',
    'Chất lượng tốt',
    'Giá hợp lý',
    'Pin trâu',
    'Shop tư vấn nhiệt tình',
  ];

  final _api = ReviewApiService();
  final _picker = ImagePicker();
  final _commentCtrl = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _blockedReason;
  Review? _existing;

  int _rating = 0;
  final List<String> _keptImageUrls = [];
  final List<XFile> _newImages = [];

  int get _totalImages => _keptImageUrls.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    _commentCtrl.addListener(() => setState(() {}));
    _loadStatus();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _blockedReason = 'Vui lòng đăng nhập để đánh giá.';
      });
      return;
    }

    try {
      final status = await _api.getMyStatus(token, widget.productId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!status.canReview) {
          _blockedReason = status.reason ?? 'Bạn chưa thể đánh giá sản phẩm này.';
        }
        final mine = status.myReview;
        if (mine != null) {
          _existing = mine;
          _rating = mine.rating;
          _commentCtrl.text = mine.comment ?? '';
          _keptImageUrls.addAll(mine.images);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _blockedReason = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalImages;
    if (remaining <= 0) {
      _snack('Tối đa $_maxImages ảnh cho mỗi đánh giá.');
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
      if (picked.isEmpty || !mounted) return;
      setState(() => _newImages.addAll(picked.take(remaining)));
      if (picked.length > remaining) {
        _snack('Chỉ thêm được $remaining ảnh (tối đa $_maxImages ảnh).');
      }
    } catch (e) {
      _snack('Không thể chọn ảnh: $e');
    }
  }

  void _addTag(String tag) {
    final text = _commentCtrl.text.trim();
    if (text.contains(tag)) return;
    final next = text.isEmpty ? tag : '$text. $tag';
    if (next.length > _maxLength) return;
    _commentCtrl.text = next;
    _commentCtrl.selection = TextSelection.collapsed(offset: next.length);
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      _snack('Vui lòng chọn số sao.');
      return;
    }
    final token = context.read<AuthProvider>().accessToken;
    if (token == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await _api.submitReview(
        token,
        widget.productId,
        rating: _rating,
        comment: _commentCtrl.text,
        newImagePaths: _newImages.map((x) => x.path).toList(),
        keepImageUrls: _keptImageUrls,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_existing == null ? 'Cảm ơn bạn đã đánh giá!' : 'Đã cập nhật đánh giá.'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // Lỗi từ bộ lọc tự động (SĐT, link, từ ngữ...) hiện rõ để khách tự sửa
      _snack(e.toString().replaceFirst('Exception: ', ''), duration: 5);
    }
  }

  void _snack(String msg, {int duration = 3}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, duration: Duration(seconds: duration)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_existing == null ? 'Đánh giá sản phẩm' : 'Sửa đánh giá')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedReason != null
              ? _buildBlocked()
              : _buildForm(),
      bottomNavigationBar: (_loading || _blockedReason != null)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_existing == null ? 'Gửi đánh giá' : 'Cập nhật đánh giá',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
    );
  }

  Widget _buildBlocked() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(_blockedReason!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Quay lại')),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final length = _commentCtrl.text.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sản phẩm
        Row(
          children: [
            if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) ...[
              ReviewThumb(url: widget.thumbnailUrl!, size: 56),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(widget.productName,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const Divider(height: 32),

        // Sao
        StarPicker(value: _rating, onChanged: (v) => setState(() => _rating = v)),
        const SizedBox(height: 24),

        // Gợi ý nhanh
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickTags
              .map((t) => ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _addTag(t),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),

        // Nội dung
        TextField(
          controller: _commentCtrl,
          maxLines: 5,
          maxLength: _maxLength,
          decoration: InputDecoration(
            hintText: 'Chia sẻ trải nghiệm của bạn về sản phẩm (chất lượng, đóng gói, giao hàng...)',
            border: const OutlineInputBorder(),
            counterText: '$length/$_maxLength',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Không chèn số điện thoại, email, đường link hoặc từ ngữ thiếu lịch sự. '
                'Mọi đánh giá đều được hiển thị công khai và Shop không thể ẩn hay xóa.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Ảnh
        Text('Hình ảnh ($_totalImages/$_maxImages)', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final url in _keptImageUrls)
              _removableImage(
                Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                () => setState(() => _keptImageUrls.remove(url)),
              ),
            for (final x in _newImages)
              _removableImage(
                Image.file(File(x.path), width: 80, height: 80, fit: BoxFit.cover),
                () => setState(() => _newImages.remove(x)),
              ),
            if (_totalImages < _maxImages)
              InkWell(
                onTap: _pickImages,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade600),
                      const SizedBox(height: 4),
                      Text('Thêm ảnh', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _removableImage(Widget image, VoidCallback onRemove) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
