import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _pairingCode;
  String _childName = 'My Child';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final code = await ApiService.getPairingCode();
    final name = await ApiService.getChildName();
    if (mounted) {
      setState(() {
        _pairingCode = code;
        _childName = name;
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Pairing Code Card
                _sectionTitle('DEVICE PAIRING'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primaryBlue.withAlpha(100)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Pairing Code',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _pairingCode ?? '––––––',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                          letterSpacing: 5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _pairingCode == null
                            ? null
                            : () {
                                Clipboard.setData(
                                    ClipboardData(text: _pairingCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pairing code copied!'),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy Code'),
                      ),
                      const Divider(color: AppTheme.divider),
                      const SizedBox(height: 4),
                      const Text(
                        'Enter this code in the SafeGuard Chrome Extension on your child\'s computer to link the devices.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Child Profile Card
                _sectionTitle('CHILD PROFILE'),
                const SizedBox(height: 12),
                _settingsTile(
                  icon: Icons.child_care,
                  title: 'Child\'s Name',
                  trailing: Text(
                    _childName,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),

                const SizedBox(height: 28),

                // Account Card
                _sectionTitle('ACCOUNT'),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.info_outline,
                            color: AppTheme.textSecondary),
                        title: const Text('App Version',
                            style: TextStyle(color: AppTheme.textPrimary)),
                        trailing: const Text('2.0.0',
                            style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      const Divider(
                          color: AppTheme.divider, height: 1, indent: 16),
                      ListTile(
                        leading: const Icon(Icons.logout,
                            color: AppTheme.dangerRed),
                        title: const Text('Log Out',
                            style: TextStyle(color: AppTheme.dangerRed)),
                        onTap: _logout,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.textSecondary),
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
