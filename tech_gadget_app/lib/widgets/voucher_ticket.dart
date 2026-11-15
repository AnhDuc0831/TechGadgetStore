import 'package:flutter/material.dart';
import '../models/voucher.dart';

/// Thẻ voucher dạng "vé" dùng chung cho Kho voucher, Ví voucher, màn chọn voucher khi checkout và Admin.
class VoucherTicket extends StatelessWidget {
  final VoucherDisplay voucher;
  final String title;
  final String? subtitle;

  /// Dòng phụ dưới cùng (VD: "Còn 12 suất", lý do không dùng được...)
  final Widget? footer;

  /// Nút / nhãn bên phải (VD: nút "Lưu", Radio, badge "Đã dùng")
  final Widget? trailing;
  final bool dimmed;
  final bool selected;
  final VoidCallback? onTap;

  const VoucherTicket({
    super.key,
    required this.voucher,
    required this.title,
    this.subtitle,
    this.footer,
    this.trailing,
    this.dimmed = false,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = voucher.isPercent ? const Color(0xFFEA580C) : const Color(0xFF2563EB);
    final leftColor = dimmed ? Colors.grey.shade400 : accent;

    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Phần bên trái: mức giảm
                  Container(
                    width: 96,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: leftColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11),
                        bottomLeft: Radius.circular(11),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          voucher.isPercent ? Icons.percent_rounded : Icons.local_offer_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          voucher.discountTitle.replaceFirst('Giảm ', ''),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          voucher.code,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Phần bên phải: thông tin
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle ?? voucher.conditionText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            voucher.expiryText,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          if (footer != null) ...[
                            const SizedBox(height: 6),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Center(child: trailing),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
