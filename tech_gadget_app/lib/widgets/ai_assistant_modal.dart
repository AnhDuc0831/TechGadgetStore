import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/gemini_service.dart';

/// Tin nhắn trong đoạn hội thoại Trợ lý AI
class AiChatMessage {
  final String role; // 'user' hoặc 'assistant'
  final String content;
  final ProductAiDraft? productDraft;
  final String time;

  AiChatMessage({
    required this.role,
    required this.content,
    this.productDraft,
    required this.time,
  });
}

/// Modal Trợ lý AI tương tác Chatbot & Tự động tạo bài đăng giống 100% GiGood
class AiAssistantModal extends StatefulWidget {
  final List<Category> categories;
  final List<Brand> brands;
  final String? initialPrompt;
  final Function(ProductAiDraft draft) onApplyDraft;

  const AiAssistantModal({
    super.key,
    required this.categories,
    required this.brands,
    this.initialPrompt,
    required this.onApplyDraft,
  });

  /// Mở modal trợ lý AI
  static Future<void> show({
    required BuildContext context,
    required List<Category> categories,
    required List<Brand> brands,
    String? initialPrompt,
    required Function(ProductAiDraft draft) onApplyDraft,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiAssistantModal(
        categories: categories,
        brands: brands,
        initialPrompt: initialPrompt,
        onApplyDraft: onApplyDraft,
      ),
    );
  }

  @override
  State<AiAssistantModal> createState() => _AiAssistantModalState();
}

class _AiAssistantModalState extends State<AiAssistantModal> {
  final _messages = <AiChatMessage>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  bool _loading = false;
  bool _isConfigured = false;

  final _quickPrompts = const [
    '🪄 Viết bài: iPhone 16 Pro Max 256GB Titan Tự Nhiên',
    '🪄 Viết bài: MacBook Pro 14 M3 Pro 18GB/512GB',
    '🪄 Viết bài: Samsung Galaxy S24 Ultra 5G Titanium Gray',
    '🪄 Viết bài: Dell XPS 15 9530 Core i7 RTX 4050',
    '🪄 Viết bài: Tai nghe Sony WH-1000XM5 Chống Ồn',
    '🪄 Viết bài: Chuột Logitech MX Master 3S',
    '🪄 Viết bài: Apple Watch Series 10 GPS 42mm',
    '🪄 Viết bài: Bàn phím cơ không dây RK84 RGB',
  ];

  @override
  void initState() {
    super.initState();
    _initGreeting();
    _loadAiStatus();
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(widget.initialPrompt!);
      });
    }
  }

  Future<void> _loadAiStatus() async {
    final status = await GeminiService.getAiStatus();
    if (mounted) {
      setState(() {
        _isConfigured = status.configured;
      });
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _initGreeting() {
    final now = DateFormat('HH:mm').format(DateTime.now());
    _messages.add(
      AiChatMessage(
        role: 'assistant',
        content:
            'Xin chào Quản trị viên! Tôi là **Trợ lý TechGadget AI**.\n\n'
            'Tôi có thể giúp bạn:\n'
            '• **Tự động viết bài & lập thông số kỹ thuật** (ví dụ: gõ "iPhone 16 Pro Max 256GB", "Laptop Dell XPS 15", "Tai nghe Sony...").\n'
            '• **Định giá & tính khuyến mãi** chuẩn xu hướng thị trường.\n'
            '• **Tạo thông số kỹ thuật JSON** chuẩn xác cho hệ thống CSDL.\n\n'
            'Bạn muốn đăng bán thiết bị nào hôm nay?',
        time: now,
      ),
    );
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
      _messages.add(AiChatMessage(role: 'user', content: text, time: now));
      if (textToSend == null) _inputCtrl.clear();
      _loading = true;
    });
    _scrollToBottom();

    try {
      final historyPayload = _messages.take(_messages.length - 1).map((m) {
        return {'role': m.role, 'content': m.content};
      }).toList();

      final res = await GeminiService.sendAiChat(
        message: text,
        history: historyPayload,
        categories: widget.categories,
        brands: widget.brands,
      );

      if (!mounted) return;
      final replyTime = DateFormat('HH:mm').format(DateTime.now());
      setState(() {
        _isConfigured = res.isConfigured;
        _messages.add(
          AiChatMessage(
            role: 'assistant',
            content: res.reply,
            productDraft: res.productDraft,
            time: replyTime,
          ),
        );
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      final errTime = DateFormat('HH:mm').format(DateTime.now());
      setState(() {
        _messages.add(
          AiChatMessage(
            role: 'assistant',
            content: 'Xin lỗi, tôi gặp sự cố tạm thời khi kết nối. Bạn vui lòng thử lại nhé!',
            time: errTime,
          ),
        );
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Render Card bản thảo sản phẩm bên trong bong bóng chat (GiGood renderJobDraft style)
  Widget _buildProductDraftCard(ProductAiDraft draft) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED), // orange-50
        border: Border.all(color: const Color(0xFFFED7AA)), // orange-200
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.auto_awesome, size: 14, color: Color(0xFFEA580C)),
                  SizedBox(width: 4),
                  Text(
                    'MẪU BÀI ĐĂNG AI TỰ ĐỘNG TẠO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFEA580C),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  draft.brandHint.isNotEmpty ? draft.brandHint : 'TechGadget',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC2410C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tên sản phẩm
          Text(
            draft.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),

          // Mô tả tóm tắt
          Text(
            draft.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF4B5563),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // Thông số kỹ thuật nhanh
          if (draft.specifications.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: draft.specifications.entries.take(3).map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ${e.key}: ',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        Expanded(
                          child: Text(
                            e.value.toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 10),

          // Giá đề xuất & SKU
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Giá niêm yết:', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  Text(
                    _currencyFormat.format(draft.discountPrice ?? draft.basePrice),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SKU: ${draft.sku}',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nút áp dụng vào bài đăng (GiGood onApplyDraft style)
          InkWell(
            onTap: () {
              widget.onApplyDraft(draft);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Áp dụng vào Đăng sản phẩm ngay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header cố định ở trên
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Flexible(
                            child: Text(
                              'TechGadget AI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDD5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ADMIN ASSISTANT',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _isConfigured
                            ? 'Trợ lý AI trực tuyến'
                            : 'Trợ lý AI sẵn sàng hỗ trợ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: _isConfigured ? Colors.green.shade700 : Colors.grey.shade500,
                          fontWeight: _isConfigured ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close, size: 22, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Message List (cuộn nội bộ)
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final item = _messages[index];
                final isUser = item.role == 'user';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                        ),
                      ],
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.82,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? const Color(0xFFF97316) : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isUser ? 16 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 16),
                            ),
                            border: isUser ? null : Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.content.replaceAll('**', ''),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isUser ? Colors.white : const Color(0xFF1F2937),
                                  height: 1.35,
                                ),
                              ),
                              if (item.productDraft != null) _buildProductDraftCard(item.productDraft!),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  item.time,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isUser ? Colors.orange.shade100 : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Loading Indicator
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                  Text(
                    _isConfigured
                        ? 'Trợ lý AI đang suy nghĩ và soạn bài...'
                        : 'AI đang phân tích và soạn bài...',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

          // Quick Suggestion Chips (cố định trên thanh nhập liệu)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _quickPrompts.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _handleSend(p.replaceFirst(RegExp(r'^[^\w\s]+\s*'), '')),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Text(
                          p,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Input Bar cố định dưới đáy màn hình
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    onSubmitted: (val) => _handleSend(val),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên thiết bị (VD: iPhone 16 Pro Max 256GB)...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFF97316)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _loading ? null : () => _handleSend(),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _loading ? Colors.grey.shade300 : const Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
