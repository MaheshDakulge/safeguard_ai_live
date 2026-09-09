import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'alerts_screen.dart';
import 'history_screen.dart';
import 'sites_screen.dart';
import 'settings_screen.dart';

// Extension connection status derived from last incident timestamp
enum _ExtStatus { active, idle, disconnected, notPaired }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  String _childName = 'My Child';
  String _pairingCode = 'Loading...';

  // FIX 1: Real unreviewed count for the badge (not just today's HIGH)
  int _unreviewedCount = 0;

  // FIX 5: Extension status fields
  _ExtStatus _extStatus = _ExtStatus.notPaired;
  String _lastActivityLabel = 'No activity recorded';

  // FIX 4: Auto-poll timer — refreshes every 30 seconds in background
  Timer? _pollTimer;

  // so AlertsScreen / HistoryScreen don't lose state or re-fetch on every tap.

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Poll every 5 s so the parent sees new alerts in near-real-time
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchData(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // silent=true skips the full-screen loading spinner (background refresh)
  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    // Run all three fetches in parallel
    final results = await Future.wait([
      ApiService.getStats(),
      ApiService.getUnreviewedCount(),
      ApiService.getLatestActivityTime(),
      ApiService.getChildName(),
      ApiService.getPairingCode(),
    ]);

    if (!mounted) return;

    final statsResult = results[0] as Map<String, dynamic>?;
    final unreviewedCount = results[1] as int;
    final lastActivity = results[2] as DateTime?;
    final childName = results[3] as String;
    final pairingCode = results[4] as String?;

    // Auth expired — send to login
    if (statsResult != null && statsResult['_auth_error'] == true) {
      await ApiService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }

    setState(() {
      _stats = statsResult;
      _childName = childName;
      _pairingCode = pairingCode ?? 'Unavailable';
      _unreviewedCount = unreviewedCount;
      _isLoading = false;

      // Derive extension status from last activity time
      if (pairingCode == null) {
        _extStatus = _ExtStatus.notPaired;
        _lastActivityLabel = 'No pairing code yet';
      } else if (lastActivity == null) {
        _extStatus = _ExtStatus.active;
        _lastActivityLabel = 'Active · No incidents yet';
      } else {
        final ago = DateTime.now().difference(lastActivity);
        if (ago.inMinutes < 10) {
          _extStatus = _ExtStatus.active;
          _lastActivityLabel = 'Active · ${ago.inMinutes}m ago';
        } else if (ago.inHours < 1) {
          _extStatus = _ExtStatus.idle;
          _lastActivityLabel = 'Idle · ${ago.inMinutes}m ago';
        } else if (ago.inHours < 24) {
          _extStatus = _ExtStatus.disconnected;
          _lastActivityLabel = 'Last seen ${ago.inHours}h ago';
        } else {
          _extStatus = _ExtStatus.disconnected;
          _lastActivityLabel = 'Last seen ${ago.inDays}d ago';
        }
      }
    });
  }

  // ── Screens for each tab ─────────────────────────────────────────────────

  Widget _buildCurrentTab() {
    switch (_selectedTab) {
      case 1:  return const AlertsScreen();
      case 2:  return const HistoryScreen();
      case 3:  return const SitesScreen();
      case 4:  return const SettingsScreen();
      default: return _buildHomeTab();
    }
  }

  String get _appBarTitle {
    switch (_selectedTab) {
      case 1:  return 'Alerts';
      case 2:  return 'History';
      case 3:  return 'Sites';
      case 4:  return 'Settings';
      default: return "$_childName's Safety";
    }
  }

  IconData get _appBarIcon {
    switch (_selectedTab) {
      case 1:  return Icons.notifications_active;
      case 2:  return Icons.history;
      case 3:  return Icons.public;
      case 4:  return Icons.settings;
      default: return Icons.security;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_appBarIcon, color: AppTheme.primaryBlue, size: 20),
            const SizedBox(width: 8),
            Text(_appBarTitle),
          ],
        ),
        actions: [
          if (_selectedTab == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchData,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _buildCurrentTab(),
      bottomNavigationBar: _buildBottomNav(_unreviewedCount),
    );
  }

  // ── Bottom nav ───────────────────────────────────────────────────────────

  Widget _buildBottomNav(int alertCount) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        backgroundColor: AppTheme.surface,
        selectedItemColor: AppTheme.primaryBlue,
        unselectedItemColor: AppTheme.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        onTap: (i) => setState(() => _selectedTab = i),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: alertCount > 0
                ? Badge(
                    label: Text('$alertCount'),
                    backgroundColor: AppTheme.dangerRed,
                    child: const Icon(Icons.notifications_none),
                  )
                : const Icon(Icons.notifications_none),
            activeIcon: const Icon(Icons.notifications_active),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.public_outlined),
            activeIcon: Icon(Icons.public),
            label: 'Sites',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ── Home tab content ─────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue));
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: AppTheme.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusBanner(),
          const SizedBox(height: 16),

          // FIX 5: Extension connection status card
          _buildExtensionStatusCard(),
          const SizedBox(height: 16),

          // Pairing code box (collapsed — code is inside status card now)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withAlpha(50)),
            ),
            child: Column(
              children: [
                const Text(
                  'EXTENSION PAIRING CODE',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _pairingCode,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionLabel('DAILY OVERVIEW'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _statCard(
                'Threats Today',
                '${_stats?['blocked_today'] ?? 0}',
                Icons.block_rounded,
                (_stats?['blocked_today'] ?? 0) > 0
                    ? AppTheme.warningAmber
                    : AppTheme.safeGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'High Risk',
                '${_stats?['high_risk_today'] ?? 0}',
                Icons.warning_amber_rounded,
                (_stats?['high_risk_today'] ?? 0) > 0
                    ? AppTheme.dangerRed
                    : AppTheme.safeGreen,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _statCard(
                'Total Blocked',
                '${_stats?['total_all_time'] ?? 0}',
                Icons.shield_outlined,
                AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Safe Rate',
                '${_stats?['safe_rate'] ?? 100}%',
                Icons.verified_user_outlined,
                AppTheme.safeGreen,
              ),
            ),
          ]),

          if (_stats?['most_active_site'] != null) ...[
            const SizedBox(height: 24),
            _sectionLabel('MOST ACTIVE SITE TODAY'),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.web, color: AppTheme.warningAmber),
                title: Text(
                  _stats!['most_active_site']['url'] ?? '—',
                  style: const TextStyle(color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmber.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.warningAmber, width: 1),
                  ),
                  child: Text(
                    '${_stats!['most_active_site']['cnt']} blocks',
                    style: const TextStyle(
                        color: AppTheme.warningAmber, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          _sectionLabel('QUICK ACTIONS'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _quickActionBtn(
                icon: Icons.notifications_active,
                label: 'View Alerts',
                color: AppTheme.dangerRed,
                onTap: () => setState(() => _selectedTab = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionBtn(
                icon: Icons.history,
                label: 'Full History',
                color: AppTheme.primaryBlue,
                onTap: () => setState(() => _selectedTab = 2),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _quickActionBtn(
                icon: Icons.public,
                label: 'Blocked Sites',
                color: AppTheme.warningAmber,
                onTap: () => setState(() => _selectedTab = 3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionBtn(
                icon: Icons.settings,
                label: 'Settings',
                color: AppTheme.textSecondary,
                onTap: () => setState(() => _selectedTab = 4),
              ),
            ),
          ]),

          const SizedBox(height: 24),
          _sectionLabel('RISK DISTRIBUTION'),
          const SizedBox(height: 10),
          ..._buildRiskChips(),
        ],
      ),
    );
  }

  // ── Extension status card (FIX 5) ────────────────────────────────────────

  Widget _buildExtensionStatusCard() {
    final (color, icon, title, pulse) = switch (_extStatus) {
      _ExtStatus.active => (
          AppTheme.safeGreen,
          Icons.extension,
          'Extension Active',
          true,
        ),
      _ExtStatus.idle => (
          AppTheme.warningAmber,
          Icons.extension_off_outlined,
          'Extension Idle',
          false,
        ),
      _ExtStatus.disconnected => (
          AppTheme.dangerRed,
          Icons.extension_off,
          'Extension Disconnected',
          false,
        ),
      _ExtStatus.notPaired => (
          AppTheme.textSecondary,
          Icons.link_off,
          'Extension Not Paired',
          false,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          // Pulsing dot for active state
          if (pulse)
            _PulseDot(color: color)
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 10),
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _lastActivityLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Auto-refresh indicator
          Tooltip(
            message: 'Auto-refreshes every 5s',
            child: Icon(Icons.sync, color: color.withAlpha(120), size: 16),
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildStatusBanner() {
    final highCount = _stats?['high_risk_today'] as int? ?? 0;
    final isAtRisk  = highCount > 0;
    final color     = isAtRisk ? AppTheme.dangerRed : AppTheme.safeGreen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(
            isAtRisk ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 44,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAtRisk ? 'CHILD AT RISK' : 'CHILD IS SAFE',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 2),
                Text(
                  isAtRisk
                      ? '$highCount unreviewed high-risk alert(s) today'
                      : 'No threats detected today',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (isAtRisk)
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _quickActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        fontSize: 11,
      ),
    );
  }

  List<Widget> _buildRiskChips() {
    final byRisk = (_stats?['by_risk_level'] as List<dynamic>?) ?? [];
    if (byRisk.isEmpty) {
      return [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('No incidents recorded yet.',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        )
      ];
    }
    return byRisk.map<Widget>((r) {
      final level = r['risk_level'] as String;
      final count = r['count'] as int;
      final color = level == 'HIGH'
          ? AppTheme.dangerRed
          : level == 'MEDIUM'
              ? AppTheme.warningAmber
              : AppTheme.safeGreen;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            title: Text(level, style: const TextStyle(color: AppTheme.textPrimary)),
            trailing: Text('$count incidents',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }).toList();
  }
}

// ── Animated pulse dot for "Active" status ────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color, blurRadius: 6)],
        ),
      ),
    );
  }
}