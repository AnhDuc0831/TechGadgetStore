import 'package:flutter/material.dart';
import '../models/review.dart';

/// Hàng sao cố định (số nguyên) dùng trong thẻ đánh giá
class StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const StarRow({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size, color: Colors.amber.shade700),
      ),
    );
  }
}

/// Ô chọn sao tương tác (màn viết đánh giá)
class StarPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarPicker({super.key, required this.value, required this.onChanged, this.size = 40});

  static const labels = ['', 'Rất tệ', 'Tệ', 'Bình thường', 'Tốt', 'Tuyệt vời'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              iconSize: size,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(),
              onPressed: () => onChanged(star),
              icon: Icon(
                star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Colors.amber.shade700,
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          value == 0 ? 'Chạm để chọn số sao' : labels[value],
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: value == 0 ? Colors.grey : Colors.amber.shade800,
          ),
        ),
      ],
    );
  }
}

/// Mở ảnh toàn màn hình (có zoom)
void showReviewImageViewer(BuildContext context, List<String> images, int initialIndex) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) {
      final controller = PageController(initialPage: initialIndex);
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: images.length,
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: Image.network(
                    images[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Ảnh vuông nhỏ trong đánh giá
class ReviewThumb extends StatelessWidget {
  final String url;
  final double size;
  final VoidCallback? onTap;

  const ReviewThumb({super.key, required this.url, this.size = 72, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: Colors.grey.shade200,
            child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
          ),
        ),
      ),
    );
  }
}

/// Thẻ hiển thị 1 đánh giá
class ReviewCard extends StatelessWidget {
  final Review review;

  /// Hiện thêm dòng tên sản phẩm (dùng cho Admin)
  final String? productName;
  final Widget? footer;
  final VoidCallback? onEdit;

  const ReviewCard({super.key, required this.review, this.productName, this.footer, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final r = review;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (productName != null) ...[
            Text(productName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: (r.reviewerAvatarUrl != null && r.reviewerAvatarUrl!.isNotEmpty)
                    ? NetworkImage(r.reviewerAvatarUrl!)
                    : null,
                child: (r.reviewerAvatarUrl == null || r.reviewerAvatarUrl!.isEmpty)
                    ? Text(
                        r.reviewerName.isNotEmpty ? r.reviewerName[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.reviewerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        if (r.isMine) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Của bạn',
                                style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    StarRow(rating: r.rating, size: 14),
                  ],
                ),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Sửa'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (r.isVerifiedPurchase)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 3),
                    Text('Đã mua hàng',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  ],
                ),
              if (r.variantSku != null && r.variantSku!.isNotEmpty)
                Text('Phân loại: ${r.variantSku}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              Text(
                '${formatReviewDate(r.createdAt)}${r.isEdited ? ' · đã chỉnh sửa' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.comment!, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < r.images.length; i++)
                  ReviewThumb(url: r.images[i], onTap: () => showReviewImageViewer(context, r.images, i)),
              ],
            ),
          ],
          if (r.hasReply) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: Colors.blue.shade300, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text('Phản hồi của Shop',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      if (r.repliedAt != null) ...[
                        const SizedBox(width: 6),
                        Text(formatReviewDate(r.repliedAt!),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.adminReply!, style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Khối tổng quan: điểm trung bình + biểu đồ thanh 5★..1★
class ReviewSummaryHeader extends StatelessWidget {
  final ReviewSummary summary;

  const ReviewSummaryHeader({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: Column(
            children: [
              Text(
                summary.totalCount == 0 ? '–' : summary.averageRating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
              ),
              StarRow(rating: summary.averageRating.round(), size: 14),
              const SizedBox(height: 4),
              Text('${summary.totalCount} đánh giá', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              for (final star in [5, 4, 3, 2, 1])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 14, child: Text('$star', style: const TextStyle(fontSize: 12))),
                      Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: summary.ratioFor(star),
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade200,
                            color: Colors.amber.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 28,
                        child: Text('${summary.countFor(star)}',
                            textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bộ lọc: Tất cả / 5★ ... 1★ / Có hình ảnh
class ReviewFilterBar extends StatelessWidget {
  final ReviewSummary summary;
  final int? rating;
  final bool hasImages;
  final void Function(int? rating, bool hasImages) onChanged;

  const ReviewFilterBar({
    super.key,
    required this.summary,
    required this.rating,
    required this.hasImages,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
        );

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Tất cả', rating == null && !hasImages, () => onChanged(null, false)),
          chip('Có hình ảnh (${summary.withImagesCount})', hasImages, () => onChanged(null, true)),
          for (final star in [5, 4, 3, 2, 1])
            chip('$star★ (${summary.countFor(star)})', rating == star, () => onChanged(star, false)),
        ],
      ),
    );
  }
}
