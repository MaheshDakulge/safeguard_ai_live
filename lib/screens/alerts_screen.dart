import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _isLoading = true;
  List<dynamic> _alerts = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final data = await ApiService.getAlerts();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _error = 'Could not load alerts. Is the backend running?';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _alerts = (data['items'] as List<dynamic>?) ?? [];
      _isLoading = false;
    });
  }

  Future<void> _markReviewed(int id) async {
    final ok = await ApiService.markReviewed(id);
    if (!mounted) return;
    if (ok) {
      setState(() => _alerts.removeWhere((a) => a['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Alert marked as reviewed'),
          backgroundColor: AppTheme.safeGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update. Try again.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  // FIX 3: Run all markReviewed calls in parallel with Future.wait
  // instead of a sequential for-loop (was N round-trips, now 1 concurrent batch).
  Future<void> _markAllReviewed() async {
    final ids = _alerts.map<int>((a) => a['id'] as int).toList();
    await Future.wait(ids.map((id) => ApiService.markReviewed(id)));
    if (!mounted) return;
    setState(() => _alerts.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${ids.length} alerts cleared'),
        backgroundColor: AppTheme.safeGreen,
      ),
    );
  }

  Color _riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
        return AppTheme.dangerRed;
      case 'MEDIUM':
        return AppTheme.warningAmber;
      default:
        return AppTheme.safeGreen;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'grooming':
        return Icons.warning_amber_rounded;
      case 'violence':
        return Icons.dangerous_outlined;
      case 'porn':
      case 'adult':
      case 'unsafe_adult':
        return Icons.block_rounded;
      case 'gun':
      case 'knife':
      case 'weapons':
      case 'unsafe_weapon':
        return Icons.gpp_maybe_outlined;
      case 'self_harm':
        return Icons.heart_broken_outlined;
      case 'bullying_hate':
        return Icons.sentiment_very_dissatisfied_outlined;
      default:
        return Icons.report_outlined;
    }
  }

  String _formatTime(String? ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.substring(0, 16).replaceAll('T', ' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppTheme.dangerRed, size: 20),
            const SizedBox(width: 8),
            const Text('Alerts'),
            if (_alerts.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_alerts.length}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_alerts.isNotEmpty)
            TextButton.icon(
              onPressed: _markAllReviewed,
              icon: const Icon(Icons.done_all, size: 18, color: AppTheme.safeGreen),
              label: const Text('Clear All',
                  style: TextStyle(color: AppTheme.safeGreen, fontSize: 13)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAlerts,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchAlerts, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_alerts.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Icon(Icons.check_circle_outline, color: AppTheme.safeGreen, size: 72),
          SizedBox(height: 16),
          Text(
            'No unreviewed alerts!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your child is safe. Pull down to refresh.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildAlertCard(_alerts[i]),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final level = (alert['risk_level'] as String? ?? 'MEDIUM');
    final color = _riskColor(level);
    final category = alert['category'] as String? ?? 'unknown';
    final url = alert['url'] as String? ?? '—';
    final preview = alert['content_preview'] as String? ?? '';
    final ts = alert['timestamp'] as String?;
    final id = alert['id'] as int;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(120), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_categoryIcon(category), color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        level,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(ts),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                const Icon(Icons.link, color: AppTheme.textSecondary, size: 13),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    url,
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  preview.length > 150 ? '${preview.substring(0, 150)}…' : preview,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _markReviewed(id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.safeGreen,
                  side: const BorderSide(color: AppTheme.safeGreen),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Mark as Reviewed',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}