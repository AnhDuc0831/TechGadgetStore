import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/formatters.dart';
import 'product_image.dart';
import 'rating_stars.dart';

class ProductCard extends StatelessWidget {
  final ProductListItem product;
  final VoidCallback onTap;

  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ProductImage(url: product.thumbnailUrl),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.brand.name,
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 40,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  RatingStars(rating: product.averageRating, reviewCount: product.reviewCount),
                  const SizedBox(height: 6),
                  if (product.hasPriceRange)
                    Text(
                      'Từ',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey.shade600),
                    ),
                  Text(
                    formatVnd(product.minPrice),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.inStock ? 'Còn hàng' : 'Tạm hết hàng',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: product.inStock ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
