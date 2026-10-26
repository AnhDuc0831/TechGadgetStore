import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final currentProfile = authProvider.userProfile;

    final nameController = TextEditingController(text: currentProfile?.fullName ?? '');
    final phoneController = TextEditingController(text: currentProfile?.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 20,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cập nhật hồ sơ',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(bottomSheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Họ tên không được để trống' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final success = await authProvider.updateProfile(
                      fullName: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                    );

                    if (bottomSheetContext.mounted) {
                      Navigator.pop(bottomSheetContext);
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Cập nhật thông tin thành công!'
                                : (authProvider.errorMessage ?? 'Cập nhật thất bại'),
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final authProvider = context.read<AuthProvider>();
              Navigator.pop(dialogContext);
              // Quay về trang chủ sau khi đăng xuất (khách vẫn xem được sản phẩm)
              Navigator.of(context).popUntil((route) => route.isFirst);
              authProvider.signOut();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final profile = authProvider.userProfile;
    final theme = Theme.of(context);

    final avatarUrl = profile?.avatarUrl ??
        user?.userMetadata?['avatar_url'] as String? ??
        user?.userMetadata?['picture'] as String?;

    final displayName = profile?.fullName ??
        user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String? ??
        'Khách hàng';

    final email = user?.email ?? 'Chưa cập nhật email';
    final phone = profile?.phone ?? user?.phone ?? 'Chưa cập nhật số điện thoại';
    final role = profile?.role ?? 'customer';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh),
            onPressed: () => authProvider.fetchProfile(),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: authProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => authProvider.fetchProfile(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Avatar Card
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 54,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null
                                ? Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.colorScheme.primary,
                              child: IconButton(
                                iconSize: 18,
                                color: Colors.white,
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditProfileDialog(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name & Role Badge
                    Text(
                      displayName,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: role == 'admin'
                            ? Colors.red.shade100
                            : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: role == 'admin'
                              ? Colors.red.shade900
                              : theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Information Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.email_outlined),
                              title: const Text('Email'),
                              subtitle: Text(email),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.phone_outlined),
                              title: const Text('Số điện thoại'),
                              subtitle: Text(phone),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.badge_outlined),
                              title: const Text('Mã người dùng (ID)'),
                              subtitle: Text(
                                user?.id ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Chỉnh sửa thông tin'),
                        onPressed: () => _showEditProfileDialog(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          backgroundColor: Colors.red.shade50,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text('Đăng xuất'),
                        onPressed: () => _confirmSignOut(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
