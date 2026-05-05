import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final bool isLoggedIn;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isLoggedIn = false,
    this.error,
  });

  AuthState copyWith({User? user, bool? isLoading, bool? isLoggedIn, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();
  final ApiClient _client = ApiClient();

  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    await _client.init();
    if (_client.token != null) {
      state = state.copyWith(isLoggedIn: true);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _authService.login(username, password);
      if (data['access_token'] != null) {
        final user = data['user'] != null ? User.fromJson(data['user']) : null;
        state = state.copyWith(user: user, isLoggedIn: true, isLoading: false);
        return true;
      }
      state = state.copyWith(
          isLoading: false, error: data['detail'] ?? '登录失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _authService.register(username, password);
      if (data['access_token'] != null) {
        final user = data['user'] != null ? User.fromJson(data['user']) : null;
        state = state.copyWith(user: user, isLoggedIn: true, isLoading: false);
        return true;
      }
      state = state.copyWith(
          isLoading: false, error: data['detail'] ?? '注册失败');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> fetchCurrentUser() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authService.fetchCurrentUser();
      state = state.copyWith(user: user, isLoggedIn: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
