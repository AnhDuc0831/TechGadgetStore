import 'package:flutter/material.dart';

/// Hiển thị số sao đánh giá (hỗ trợ nửa sao) kèm số lượt đánh giá
class RatingStars extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double size;

  const RatingStars({
    super.key,
    required this.rating,
    required this.reviewCount,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final stars = List.generate(5, (index) {
      final position = index + 1;
      final icon = rating >= position
          ? Icons.star
          : rating >= position - 0.5
              ? Icons.star_half
              : Icons.star_border;
      return Icon(icon, size: size, color: Colors.amber.shade700);
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...stars,
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            reviewCount > 0 ? '($reviewCount)' : 'Chưa có đánh giá',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: size - 2, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}
