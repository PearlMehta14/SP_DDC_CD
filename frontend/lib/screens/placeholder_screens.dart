import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'Login', '/dashboard');
}

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'App Lock', '/dashboard');
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('AVAILABLE STOCK', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/stock'),
              child: const Text('Go to Stock'),
            ),
          ],
        ),
      ),
    );
  }
}

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'Stock', '/dashboard');
}

class EntriesScreen extends StatelessWidget {
  const EntriesScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'Entries', '/dashboard');
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'History', '/dashboard');
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'Reports', '/dashboard');
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'Settings', '/dashboard');
}

class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'Audit Logs', '/dashboard');
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});
  @override
  Widget build(BuildContext context) => _buildPlaceholder(context, 'User Management', '/dashboard');
}

Widget _buildPlaceholder(BuildContext context, String title, String nextRoute) {
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: ElevatedButton(
        onPressed: () => context.go(nextRoute),
        child: Text('Go to $nextRoute'),
      ),
    ),
  );
}
