import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      appBar: AppBar(
        title: const Text(
          'MORE',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE5E5E5),
            height: 1.0,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildListTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: user?['name'] ?? 'User',
            onTap: () {},
          ),
          const Divider(height: 1, color: Color(0xFFE5E5E5)),
          if (user?['role'] == 'ADMIN') ...[
            _buildListTile(
              icon: Icons.people_outline,
              title: 'Users',
              subtitle: 'Manage application users',
              onTap: () => context.push('/users'),
            ),
            const Divider(height: 1, color: Color(0xFFE5E5E5)),
          ],
          _buildListTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {},
          ),
          const Divider(height: 1, color: Color(0xFFE5E5E5)),
          _buildListTile(
            icon: Icons.logout,
            title: 'Logout',
            iconColor: const Color(0xFFD4AF37),
            textColor: const Color(0xFFD4AF37),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
          const Divider(height: 1, color: Color(0xFFE5E5E5)),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Icon(icon, color: iconColor ?? const Color(0xFF6B6B6B), size: 28),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: textColor ?? const Color(0xFF1A1A1A),
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(color: Color(0xFF6B6B6B)))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFE5E5E5)),
      onTap: onTap,
    );
  }
}
