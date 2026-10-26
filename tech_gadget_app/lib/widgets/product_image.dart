import 'package:flutter/material.dart';

/// Ảnh sản phẩm từ URL, hiển thị icon thay thế khi chưa có ảnh hoặc tải lỗi
class ProductImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double iconSize;

  const ProductImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Icon(Icons.devices_other, size: iconSize, color: Colors.grey.shade400),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return Container(
      color: Colors.white,
      child: Image.network(
        url!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
      ),
    );
  }
}
