import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await ApiClient().init();
    } catch (_) {
      // 无法初始化，跳到服务器配置
      if (mounted) Navigator.of(context).pushReplacementNamed('/server-config');
      return;
    }
    if (!mounted) return;
    final token = ApiClient().token;
    if (token != null) {
      // 5秒超时，防止网络不通时永远卡住
      try {
        await Future.any([
          ref.read(authProvider.notifier).fetchCurrentUser(),
          Future.delayed(const Duration(seconds: 5)),
        ]);
      } catch (_) {
        // token无效，清除并跳登录
        await ApiClient().setToken(null);
      }
    }
    if (!mounted) return;
    final isLoggedIn = ref.read(authProvider).isLoggedIn;
    if (isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐰', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Echo',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800])),
            const SizedBox(height: 8),
            Text('治愈系智能日记',
                style: TextStyle(fontSize: 14, color: Colors.grey[400])),
            const SizedBox(height: 32),
            const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
