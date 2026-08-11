import 'package:go_router/go_router.dart';
import '../../screens/placeholder_screens.dart';

final goRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/app-lock',
      builder: (context, state) => const AppLockScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/stock',
      builder: (context, state) => const StockScreen(),
    ),
    GoRoute(
      path: '/entries',
      builder: (context, state) => const EntriesScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/audit-logs',
      builder: (context, state) => const AuditLogsScreen(),
    ),
    GoRoute(
      path: '/users',
      builder: (context, state) => const UserManagementScreen(),
    ),
  ],
);
