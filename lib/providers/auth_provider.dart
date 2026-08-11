import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

class AuthState {
  final bool isLoading;
  final bool isInitializing;
  final Map<String, dynamic>? user;
  final String? error;

  AuthState({this.isLoading = false, this.isInitializing = true, this.user, this.error});

  AuthState copyWith({bool? isLoading, bool? isInitializing, Map<String, dynamic>? user, String? error, bool clearError = false}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => checkSession());
    return AuthState(isInitializing: true);
  }

  Future<void> checkSession() async {
    state = state.copyWith(isLoading: true);
    try {
      // Enforce a minimum 2-second delay for the splash screen animation
      final results = await Future.wait([
        authService.getCurrentUser(),
        Future.delayed(const Duration(seconds: 2)),
      ]);
      final user = results[0] as Map<String, dynamic>?;
      state = state.copyWith(isLoading: false, isInitializing: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, isInitializing: false, error: e.toString());
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await authService.login(email, password);
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await authService.logout();
    state = AuthState(isInitializing: false); // reset to unauthenticated
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
