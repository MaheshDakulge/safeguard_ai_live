import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  bool _isLoading = true;
  List<dynamic> _sites = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSites();
  }

  Future<void> _fetchSites() async {
    setState(() { _isLoading = true; _error = null; });
    final data = await ApiService.getSites();
    if (!mounted) return;
    if (data == null) {
      setState(() { _error = 'Could not reach server.'; _isLoading = false; });
      return;
    }
    setState(() {
      _sites = data['sites'] as List<dynamic>? ?? [];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, color: AppTheme.primaryBlue, size: 20),
            SizedBox(width: 8),
            Text('Blocked Sites'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchSites),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchSites, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_sites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_off, color: AppTheme.textSecondary, size: 56),
            SizedBox(height: 12),
            Text('No sites flagged yet.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchSites,
      color: AppTheme.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryRow(),
          const SizedBox(height: 16),
          ...List.generate(
            _sites.length,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSiteCard(_sites[i], i + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final totalSites     = _sites.length;
    final totalHigh      = _sites.fold<int>(0, (s, x) => s + (x['high_count'] as int? ?? 0));
    final totalIncidents = _sites.fold<int>(0, (s, x) => s + (x['incident_count'] as int? ?? 0));

    return Row(
      children: [
        _summaryChip(Icons.web, '$totalSites', 'Sites', AppTheme.primaryBlue),
        const SizedBox(width: 10),
        _summaryChip(Icons.warning_amber, '$totalHigh', 'High Risk', AppTheme.dangerRed),
        const SizedBox(width: 10),
        _summaryChip(Icons.block, '$totalIncidents', 'Incidents', AppTheme.warningAmber),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteCard(Map<String, dynamic> site, int rank) {
    final url        = site['url'] as String? ?? '—';
    final incidents  = site['incident_count'] as int? ?? 0;
    final high       = site['high_count'] as int? ?? 0;
    final medium     = site['medium_count'] as int? ?? 0;
    final maxScore   = (site['max_risk_score'] as num? ?? 0).toDouble();
    final lastSeen   = _fmtTs(site['last_seen'] as String?);
    final overallRisk = high > 0 ? 'HIGH' : medium > 0 ? 'MEDIUM' : 'LOW';
    final riskColor  = _riskColor(overallRisk);
    final scorePct   = (maxScore * 100).toInt().clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: riskColor.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: riskColor.withAlpha(30), shape: BoxShape.circle),
              child: Center(child: Text('#$rank',
                  style: TextStyle(color: riskColor, fontSize: 11, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(url,
                  style: const TextStyle(color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            _riskBadge(overallRisk, riskColor),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Risk Score', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxScore.clamp(0.0, 1.0),
                  backgroundColor: AppTheme.divider,
                  color: riskColor, minHeight: 6),
              ),
            ),
            const SizedBox(width: 8),
            Text('$scorePct%',
                style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 10),
          Row(children: [
            _statPill(Icons.block, '$incidents total', AppTheme.textSecondary),
            const SizedBox(width: 8),
            if (high > 0) _statPill(Icons.error_outline, '$high high', AppTheme.dangerRed),
            if (medium > 0) ...[
              const SizedBox(width: 8),
              _statPill(Icons.warning_amber_outlined, '$medium med', AppTheme.warningAmber),
            ],
            const Spacer(),
            Text('Last: $lastSeen',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
          ]),
        ],
      ),
    );
  }

  Widget _riskBadge(String risk, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(30), borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color)),
    child: Text(risk, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
  );

  Widget _statPill(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, color: color, size: 13), const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11))],
  );

  Color _riskColor(String level) {
    switch (level) {
      case 'HIGH':   return AppTheme.dangerRed;
      case 'MEDIUM': return AppTheme.warningAmber;
      default:       return AppTheme.safeGreen;
    }
  }

  String _fmtTs(String? ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month}';
    } catch (_) { return '—'; }
  }
}
