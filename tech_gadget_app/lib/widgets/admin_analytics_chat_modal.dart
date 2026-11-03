import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../screens/admin_dashboard_screen.dart';
import '../screens/admin_orders_screen.dart';
import '../screens/admin_products_screen.dart';
import '../services/gemini_service.dart';

/// Tin nhắn trong hộp thoại Trợ lý Phân tích CSDL cho Admin
class AdminAnalyticsChatMessage {
  final String role; // 'user' hoặc 'assistant'
  final String content;
  final DashboardSnapshot? snapshot;
  final ProductAiDraft? productDraft;
  final String time;

  AdminAnalyticsChatMessage({
    required this.role,
    required this.content,
    this.snapshot,
    this.productDraft,
    required this.time,
  });
}

/// Modal Chatbox AI Đọc CSDL & Phân tích Thống kê dành cho Quản trị viên (Admin)
/// Giao diện chống tràn tuyệt đối, không hiển thị lõi kỹ thuật
class AdminAnalyticsChatModal extends StatefulWidget {
  final String? initialPrompt;

  const AdminAnalyticsChatModal({super.key, this.initialPrompt});

  /// Mở hộp thoại AI Cố vấn Thống kê CSDL cho Admin
  static Future<void> show({
    required BuildContext context,
    String? initialPrompt,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminAnalyticsChatModal(initialPrompt: initialPrompt),
    );
  }

  @override
  State<AdminAnalyticsChatModal> createState() => _AdminAnalyticsChatModalState();
}

class _AdminAnalyticsChatModalState extends State<AdminAnalyticsChatModal> {
  final _messages = <AdminAnalyticsChatMessage>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  bool _loading = false;

  final _quickPrompts = const [
    '📊 Báo cáo tổng quan kinh doanh hôm nay',
    '💰 Thống kê doanh thu & lợi nhuận 30 ngày',
    '📦 Đơn hàng đang chờ duyệt xử lý',
    '🔥 Top sản phẩm bán chạy nhất trong CSDL',
    '⚠️ Cảnh báo mặt hàng sắp hết kho',
    '📈 Phân tích tỷ suất lợi nhuận & gợi ý',
    '🪄 Viết bài: iPhone 16 Pro Max 256GB',
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
    _messages.add(
      AdminAnalyticsChatMessage(
        role: 'assistant',
        content:
            'Xin chào Quản trị viên! Tôi là **Trợ lý AI Cố vấn Quản trị & Phân tích Dữ liệu CSDL**.\n\n'
            'Tôi được kết nối trực tiếp với **Cơ sở Dữ liệu TechGadget Store** để cung cấp cho bạn thông tin theo thời gian thực:\n'
            '• **Thống kê Doanh thu & Lợi nhuận gộp** theo kỳ (Hôm nay, 7 ngày, 30 ngày, tháng này)\n'
            '• **Kiểm soát Đơn hàng** (Đơn chờ duyệt, đã giao, thanh toán PayOS/COD, tỷ lệ hủy đơn)\n'
            '• **Quản lý Kho & Tồn hàng** (Top sản phẩm bán chạy, cảnh báo mặt hàng sắp hết kho)\n'
            '• **Hỗ trợ tạo bài đăng sản phẩm mới** tự động điền cấu hình kỹ thuật\n\n'
            'Bạn cần kiểm tra hoặc phân tích chỉ số kinh doanh nào hôm nay?',
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
      _messages.add(AdminAnalyticsChatMessage(role: 'user', content: text, time: now));
      if (textToSend == null) _inputCtrl.clear();
      _loading = true;
    });
    _scrollToBottom();

    final history = _messages
        .take(_messages.length - 1)
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    try {
      final res = await GeminiService.sendAdminAnalyticsChat(
        message: text,
        history: history,
      );

      final replyTime = DateFormat('HH:mm').format(DateTime.now());
      if (mounted) {
        setState(() {
          _messages.add(
            AdminAnalyticsChatMessage(
              role: 'assistant',
              content: res.reply,
              snapshot: res.dashboardSnapshot,
              productDraft: res.productDraft,
              time: replyTime,
            ),
          );
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      final replyTime = DateFormat('HH:mm').format(DateTime.now());
      if (mounted) {
        setState(() {
          _messages.add(
            AdminAnalyticsChatMessage(
              role: 'assistant',
              content:
                  'Dạ xin lỗi Quản trị viên, không thể truy vấn CSDL lúc này ($e). Vui lòng thử lại hoặc mở Dashboard trực tiếp.',
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
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
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
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF4338CA)],
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
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF312E81),
                child: Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
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
                          'AI Cố Vấn Quản Trị CSDL',
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
                      _AdminBadge(),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Truy vấn số liệu & phân tích kinh doanh',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 11, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
              tooltip: 'Làm mới',
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E1B4B)),
            ),
            backgroundColor: const Color(0xFFEEF2FF),
            side: const BorderSide(color: Color(0xFFC7D2FE)),
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

  Widget _buildMessageItem(AdminAnalyticsChatMessage msg, bool isUser) {
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
                backgroundColor: Color(0xFF4338CA),
                child: Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF4338CA) : Colors.white,
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
                      const SizedBox(height: 6),
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

                // Thẻ Snapshot KPI thực tế từ CSDL
                if (!isUser && msg.snapshot != null) ...[
                  const SizedBox(height: 8),
                  _buildSnapshotCard(msg.snapshot!),
                ],

                // Điều hướng nhanh cho Quản trị viên
                if (!isUser) ...[
                  const SizedBox(height: 6),
                  _buildQuickActionShortcuts(),
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

  Widget _buildSnapshotCard(DashboardSnapshot snapshot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7D2FE)),
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
          Row(
            children: [
              const Icon(Icons.query_stats_rounded, color: Color(0xFF4338CA), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Số liệu CSDL (${snapshot.period})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Doanh thu',
                  _currencyFormat.format(snapshot.totalRevenue),
                  Colors.green.shade700,
                  Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  'Lợi nhuận',
                  _currencyFormat.format(snapshot.totalProfit),
                  Colors.blue.shade700,
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  'Đơn hàng (Chờ/Giao)',
                  '${snapshot.pendingOrders} / ${snapshot.deliveredOrders}',
                  Colors.amber.shade800,
                  Icons.shopping_bag_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  'Cảnh báo tồn kho',
                  '${snapshot.lowStockProductsCount} mặt hàng',
                  snapshot.lowStockProductsCount > 0 ? Colors.red.shade700 : Colors.teal.shade700,
                  Icons.warning_amber_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionShortcuts() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.analytics_outlined, size: 14, color: Color(0xFF4338CA)),
            label: const Text('Mở Dashboard', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFC7D2FE)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.receipt_long, size: 14, color: Colors.indigo),
            label: const Text('Xử lý Đơn hàng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.indigo.shade200),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminOrdersScreen()),
              );
            },
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.teal),
            label: const Text('Quản lý Kho hàng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.teal.shade200),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminProductsScreen()),
              );
            },
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
            backgroundColor: Color(0xFF4338CA),
            child: Icon(Icons.analytics_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4338CA)),
                ),
                SizedBox(width: 8),
                Text(
                  'Đang phân tích số liệu CSDL...',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
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
                  hintText: 'Hỏi CSDL: Doanh thu, đơn hàng, tồn kho, top bán chạy...',
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
                  colors: [Color(0xFF4338CA), Color(0xFF312E81)],
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

class _AdminBadge extends StatelessWidget {
  const _AdminBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD8B4FE), width: 0.8),
      ),
      child: const Text(
        'ADMIN',
        style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
