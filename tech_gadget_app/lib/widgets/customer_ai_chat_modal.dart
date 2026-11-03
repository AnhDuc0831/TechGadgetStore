import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';
import '../services/gemini_service.dart';
import 'product_image.dart';

/// Tin nhắn trong hộp thoại Trợ lý AI Khách hàng
class CustomerChatMessage {
  final String role; // 'user' hoặc 'assistant'
  final String content;
  final List<ProductRecommendation> recommendedProducts;
  final String time;

  CustomerChatMessage({
    required this.role,
    required this.content,
    this.recommendedProducts = const [],
    required this.time,
  });
}

/// Modal Chatbot AI Tư vấn Bán hàng dành cho Khách hàng
/// Giao diện chống tràn tuyệt đối, không hiển thị lõi kỹ thuật
class CustomerAiChatModal extends StatefulWidget {
  final List<ProductListItem> currentProducts;
  final List<Category> categories;
  final List<Brand> brands;
  final String? initialPrompt;
  final String? focusedProductId;
  final String? focusedProductName;

  const CustomerAiChatModal({
    super.key,
    this.currentProducts = const [],
    this.categories = const [],
    this.brands = const [],
    this.initialPrompt,
    this.focusedProductId,
    this.focusedProductName,
  });

  /// Mở giao diện AI Chatbox tư vấn khách hàng
  static Future<void> show({
    required BuildContext context,
    List<ProductListItem> currentProducts = const [],
    List<Category> categories = const [],
    List<Brand> brands = const [],
    String? initialPrompt,
    String? focusedProductId,
    String? focusedProductName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerAiChatModal(
        currentProducts: currentProducts,
        categories: categories,
        brands: brands,
        initialPrompt: initialPrompt,
        focusedProductId: focusedProductId,
        focusedProductName: focusedProductName,
      ),
    );
  }

  @override
  State<CustomerAiChatModal> createState() => _CustomerAiChatModalState();
}

class _CustomerAiChatModalState extends State<CustomerAiChatModal> {
  final _messages = <CustomerChatMessage>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  bool _loading = false;
  String? _lastErrorNotice;

  final _quickPrompts = const [
    '📱 Điện thoại chụp ảnh đẹp pin trâu',
    '💻 Laptop mỏng nhẹ dưới 20 triệu',
    '🎧 Tai nghe chống ồn tốt nhất',
    '🔥 Sản phẩm giảm giá hot hôm nay',
    '🛡️ Chính sách bảo hành & 1 đổi 1',
    '🚚 Phí ship và thời gian giao hàng',
    '💳 Thanh toán qua quét mã PayOS',
  ];

  @override
  void initState() {
    super.initState();
    _initGreeting();

    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(widget.initialPrompt!);
      });
    }
  }

  void _initGreeting() {
    final now = DateFormat('HH:mm').format(DateTime.now());
    String welcomeText;

    if (widget.focusedProductName != null && widget.focusedProductName!.isNotEmpty) {
      welcomeText =
          'Dạ chào bạn! 👋 Tôi là **Trợ lý Tư vấn TechGadget**.\n\n'
          'Tôi thấy bạn đang quan tâm đến sản phẩm **${widget.focusedProductName}**.\n\n'
          'Bạn cần tôi tư vấn thêm về cấu hình, ưu nhược điểm, mức giá hay so sánh với dòng máy khác không ạ?';
    } else {
      welcomeText =
          'Dạ TechGadget Store xin chào bạn! 👋 Tôi là **Chuyên viên AI Tư vấn Công nghệ**.\n\n'
          'Tôi có thể giúp bạn:\n'
          '• **Gợi ý thiết bị phù hợp** theo tầm giá và nhu cầu (học tập, gaming, đồ họa, chụp ảnh...)\n'
          '• **So sánh tính năng & cấu hình** các dòng điện thoại, laptop, phụ kiện\n'
          '• **Giải đáp chính sách** bảo hành 1 đổi 1, giao hàng và thanh toán VietQR PayOS\n\n'
          'Hôm nay bạn đang muốn tìm kiếm thiết bị công nghệ nào?';
    }

    _messages.add(
      CustomerChatMessage(
        role: 'assistant',
        content: welcomeText,
        time: now,
      ),
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend([String? textToSend]) async {
    final text = (textToSend ?? _inputCtrl.text).trim();
    if (text.isEmpty || _loading) return;

    final now = DateFormat('HH:mm').format(DateTime.now());
    setState(() {
      _messages.add(CustomerChatMessage(role: 'user', content: text, time: now));
      if (textToSend == null) _inputCtrl.clear();
      _loading = true;
      _lastErrorNotice = null;
    });
    _scrollToBottom();

    final history = _messages
        .take(_messages.length - 1)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    try {
      final res = await GeminiService.sendCustomerChat(
        message: text,
        productId: widget.focusedProductId,
        history: history,
        availableProducts: widget.currentProducts,
        categories: widget.categories,
        brands: widget.brands,
      );

      final replyTime = DateFormat('HH:mm').format(DateTime.now());

      if (mounted) {
        setState(() {
          _messages.add(
            CustomerChatMessage(
              role: 'assistant',
              content: res.reply,
              recommendedProducts: res.recommendedProducts,
              time: replyTime,
            ),
          );
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      final replyTime = DateFormat('HH:mm').format(DateTime.now());
      if (mounted) {
        setState(() {
          _messages.add(
            CustomerChatMessage(
              role: 'assistant',
              content:
                  'Dạ xin lỗi bạn, hệ thống tư vấn vừa gặp gián đoạn tạm thời. Tôi đã ghi nhận và bạn có thể thử hỏi lại hoặc chọn các gợi ý bên dưới nhé!',
              time: replyTime,
            ),
          );
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _lastErrorNotice = null;
      _initGreeting();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          if (_lastErrorNotice != null) _buildNoticeBanner(),
          _buildQuickPromptsBar(),
          Expanded(child: _buildMessagesList()),
          if (_loading) _buildTypingIndicator(),
          _buildInputBar(bottomInset),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Bot Avatar
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF1E3A8A),
                child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'TechGadget AI Tư Vấn',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      _LiveBadge(),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Trực tuyến • Hỗ trợ tư vấn mua sắm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFBAE6FD),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
              tooltip: 'Làm mới cuộc hội thoại',
              onPressed: _clearChat,
            ),
            const SizedBox(width: 4),
            IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lastErrorNotice!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.orange.shade900, fontSize: 11),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 16, color: Colors.orange),
            onPressed: () => setState(() => _lastErrorNotice = null),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptsBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final prompt = _quickPrompts[idx];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
            ),
            backgroundColor: const Color(0xFFF1F5F9),
            side: BorderSide(color: Colors.grey.shade300),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            onPressed: _loading ? null : () => _handleSend(prompt),
          );
        },
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (ctx, idx) {
        final msg = _messages[idx];
        final isUser = msg.role == 'user';
        return _buildMessageItem(msg, isUser);
      },
    );
  }

  Widget _buildMessageItem(CustomerChatMessage msg, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              child: const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFF2563EB),
                child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 16),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    border: isUser ? null : Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormattedText(msg.content, isUser),
                      const SizedBox(height: 4),
                      Align(
                        alignment: isUser ? Alignment.bottomRight : Alignment.bottomLeft,
                        child: Text(
                          msg.time,
                          style: TextStyle(
                            color: isUser ? Colors.white70 : Colors.grey.shade500,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Danh sách sản phẩm gợi ý kèm thẻ trực quan
                if (!isUser && msg.recommendedProducts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildRecommendationsSection(msg.recommendedProducts),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            Container(
              margin: const EdgeInsets.only(top: 2, left: 8),
              child: const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFF0F172A),
                child: Icon(Icons.person, color: Colors.white, size: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isUser) {
    final style = TextStyle(
      color: isUser ? Colors.white : const Color(0xFF1E293B),
      fontSize: 13.5,
      height: 1.45,
    );

    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (i.isOdd) {
        spans.add(TextSpan(
          text: parts[i],
          style: style.copyWith(fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(text: parts[i], style: style));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildRecommendationsSection(List<ProductRecommendation> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text(
              'Sản phẩm gợi ý cho bạn (${products.length})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) => _buildProductCard(products[idx]),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(ProductRecommendation product) {
    final hasDiscount = product.discountPrice != null && product.discountPrice! < product.basePrice;
    final displayPrice = product.discountPrice ?? product.basePrice;

    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 80,
              width: double.infinity,
              child: ProductImage(
                url: product.thumbnailUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currencyFormat.format(displayPrice),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      if (hasDiscount)
                        Text(
                          _currencyFormat.format(product.basePrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 24,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(productId: product.id),
                          ),
                        );
                      },
                      child: const Text('Xem ngay', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFF2563EB),
            child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade600),
                ),
                const SizedBox(width: 8),
                Text(
                  'Đang xử lý câu hỏi...',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(double bottomInset) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: 'Hỏi về cấu hình, so sánh, giá cả...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
              ),
              child: IconButton(
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _loading ? null : () => _handleSend(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.greenAccent, width: 0.8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 2.5, backgroundColor: Colors.greenAccent),
          SizedBox(width: 3),
          Text(
            '24/7',
            style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
