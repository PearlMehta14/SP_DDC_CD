import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/users_screen.dart';
import 'screens/main_scaffold.dart';
import 'screens/stock_screen.dart';
import 'screens/stock_detail_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rejections_screen.dart';
import 'screens/logs_screen.dart';
import 'providers/auth_provider.dart';

import 'screens/unlock_screen.dart';
import 'screens/security_settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (BuildContext context, GoRouterState state) {
      final isInitializing = authState.isInitializing;
      final isAuth = authState.user != null;
      final isLocked = authState.isLocked;
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final isUnlocking = state.matchedLocation == '/unlock';

      if (isInitializing) return '/splash';

      if (!isAuth && !isLoggingIn) return '/login';
      
      if (isAuth && isLocked && !isUnlocking) return '/unlock';
      
      if (isAuth && !isLocked && (isLoggingIn || isSplash || isUnlocking)) return '/';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/unlock',
        builder: (context, state) => const UnlockScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/stock',
            builder: (context, state) => const StockScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return StockDetailScreen(stockId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/rejections',
            builder: (context, state) => const RejectionsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/security',
            builder: (context, state) => const SecuritySettingsScreen(),
          ),
          GoRoute(
            path: '/users',
            redirect: (context, state) {
              if (authState.user?['role'] != 'ADMIN') return '/';
              return null;
            },
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/logs',
            builder: (context, state) => const LogsScreen(),
          ),
        ],
      ),
    ],
  );
});
