import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthState {
  final bool isLoading;
  final bool isInitializing;
  final Map<String, dynamic>? user;
  final String? error;
  
  // Security fields
  final bool isLocked;
  final bool hasPin;

  AuthState({
    this.isLoading = false,
    this.isInitializing = true,
    this.user,
    this.error,
    this.isLocked = false,
    this.hasPin = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isInitializing,
    Map<String, dynamic>? user,
    String? error,
    bool clearError = false,
    bool? isLocked,
    bool? hasPin,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
      isLocked: isLocked ?? this.isLocked,
      hasPin: hasPin ?? this.hasPin,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  final _storage = const FlutterSecureStorage();

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
      
      // Check security settings
      final pin = await _storage.read(key: 'app_pin');
      final hasPin = pin != null && pin.isNotEmpty;
      
      // If user is logged in and PIN is set, lock the app
      final isLocked = (user != null && hasPin);
      
      state = state.copyWith(
        isLoading: false,
        isInitializing: false,
        user: user,
        hasPin: hasPin,
        isLocked: isLocked,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, isInitializing: false, error: e.toString());
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await authService.login(email, password);
      
      final pin = await _storage.read(key: 'app_pin');
      final hasPin = pin != null && pin.isNotEmpty;
      final isLocked = hasPin;
      
      state = state.copyWith(
        isLoading: false, 
        user: user,
        hasPin: hasPin,
        isLocked: isLocked,
      );
      return true;
    } catch (e) {
      final errorMessage = ApiService.extractErrorMessage(e);
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState(isInitializing: false);
    try {
      await authService.logout();
    } catch (_) {}
  }
  
  // Security Methods
  
  void lockApp() {
    if (state.user != null && state.hasPin) {
      state = state.copyWith(isLocked: true);
    }
  }
  
  Future<bool> unlock(String enteredPin) async {
    final pin = await _storage.read(key: 'app_pin');
    if (pin == enteredPin) {
      state = state.copyWith(isLocked: false);
      return true;
    }
    return false;
  }
  
  Future<void> setPin(String newPin) async {
    await _storage.write(key: 'app_pin', value: newPin);
    state = state.copyWith(hasPin: true);
  }
  
  Future<bool> changePin(String currentPin, String newPin) async {
    final pin = await _storage.read(key: 'app_pin');
    if (pin == currentPin) {
      await _storage.write(key: 'app_pin', value: newPin);
      return true;
    }
    return false;
  }
  
  Future<bool> removePin(String currentPin) async {
    final pin = await _storage.read(key: 'app_pin');
    if (pin == currentPin) {
      await _storage.delete(key: 'app_pin');
      await _storage.delete(key: 'use_biometrics');
      state = state.copyWith(hasPin: false, isLocked: false);
      return true;
    }
    return false;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
