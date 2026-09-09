import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _childNameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  // After success, show the pairing code
  String? _pairingCode;

  void _register() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _childNameController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.register(
      _emailController.text.trim(),
      _passwordController.text,
      _childNameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null && result['error'] == null) {
      setState(() => _pairingCode = result['pairing_code']);
    } else {
      setState(() {
        _errorMessage = result?['error'] ?? 'Registration failed. Please try again.';
      });
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: _pairingCode != null
              ? _buildSuccessView()
              : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set Up Your\nParent Account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "You'll get a pairing code to link your child's browser.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 36),

        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.dangerRed.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.dangerRed),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.dangerRed),
              textAlign: TextAlign.center,
            ),
          ),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Your Email',
            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'Password (min. 6 characters)',
            prefixIcon: const Icon(Icons.lock_outlined, color: AppTheme.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textSecondary,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _childNameController,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            labelText: "Child's Name (e.g. Arjun)",
            prefixIcon: Icon(Icons.child_care, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _register,
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'CREATE ACCOUNT',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: AppTheme.safeGreen, size: 72),
        const SizedBox(height: 20),
        const Text(
          'Account Created!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppTheme.safeGreen,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Share this code with the SafeGuard Chrome Extension on your child\'s computer to link the devices.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 32),

        // Pairing code display
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryBlue, width: 2),
          ),
          child: Column(
            children: [
              const Text(
                'PAIRING CODE',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _pairingCode ?? '',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _pairingCode ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Code'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warningAmber.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.warningAmber.withAlpha(80)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warningAmber, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Open the Chrome Extension on your child\'s computer, click "Pair", and enter this code.',
                  style: TextStyle(color: AppTheme.warningAmber, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _goHome,
            child: const Text(
              'GO TO DASHBOARD',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}
