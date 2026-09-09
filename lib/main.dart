import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  runApp(SafeGuardApp(isLoggedIn: token != null));
}

class SafeGuardApp extends StatelessWidget {
  final bool isLoggedIn;

  const SafeGuardApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeGuard AI',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
