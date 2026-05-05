import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth/server_config_screen.dart';
import 'theme.dart';

class EchoApp extends StatelessWidget {
  const EchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Echo - 治愈系智能日记',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorSchemeSeed: AppTheme.accent,
        scaffoldBackgroundColor: AppTheme.bg,
        appBarTheme: AppTheme.appBarTheme,
        inputDecorationTheme: AppTheme.inputTheme,
        elevatedButtonTheme: AppTheme.elevatedButtonTheme,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/server-config': (context) => const ServerConfigScreen(),
      },
    );
  }
}
