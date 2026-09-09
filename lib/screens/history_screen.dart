import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  String? _error;
  String? _filterRisk;
  int _page = 1;
  int _totalPages = 1;
  bool _isPaging = false;
  int _selectedFilter = 0;

  static const List<String> _filters = ['All', 'HIGH', 'MEDIUM', 'LOW'];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory({int page = 1}) async {
    if (page == 1) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isPaging = true);
    }

    final data = await ApiService.getHistory(
      page: page,
      riskLevel: _filterRisk,
    );

    if (!mounted) return;

    if (data == null) {
      setState(() {
        _error = 'Could not reach server.';
        _isLoading = false;
        _isPaging = false;
      });
      return;
    }

    final incoming = data['items'] as List<dynamic>? ?? [];
    setState(() {
      _items = page == 1 ? incoming : [..._items, ...incoming];
      _page = page;
      _totalPages = data['pages'] as int? ?? 1;
      _isLoading = false;
      _isPaging = false;
    });
  }

  void _setFilter(int idx) {
    setState(() {
      _selectedFilter = idx;
      _filterRisk = idx == 0 ? null : _filters[idx];
    });
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: AppTheme.primaryBlue, size: 20),
            SizedBox(width: 8),
            Text('History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(_filters.length, (i) {
          final isActive = _selectedFilter == i;
          final color = i == 1
              ? AppTheme.dangerRed
              : i == 2
              ? AppTheme.warningAmber
              : i == 3
              ? AppTheme.safeGreen
              : AppTheme.primaryBlue;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _setFilter(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive ? color.withAlpha(40) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? color : AppTheme.divider,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    color: isActive ? color : AppTheme.textSecondary,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: AppTheme.textSecondary, size: 48),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchHistory(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, color: AppTheme.textSecondary, size: 56),
            SizedBox(height: 12),
            Text(
              'No incidents found.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchHistory(),
      color: AppTheme.primaryBlue,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        // +1 for the "load more" button row at the bottom
        itemCount: _items.length + (_page < _totalPages ? 1 : 0),
        // Fixed: single underscore parameter name (no lint warning)
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Center(
              child: _isPaging
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryBlue,
                      ),
                    )
                  : TextButton(
                      onPressed: () => _fetchHistory(page: _page + 1),
                      child: const Text(
                        'Load more',
                        style: TextStyle(color: AppTheme.primaryBlue),
                      ),
                    ),
            );
          }
          return _buildHistoryTile(_items[i] as Map<String, dynamic>);
        },
      ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> item) {
    final risk = item['risk_level'] as String? ?? 'LOW';
    final category = item['category'] as String? ?? '—';
    final url = item['url'] as String? ?? '—';
    final reviewed = (item['reviewed'] as int? ?? 0) == 1;
    final color = _riskColor(risk);
    final ts = _fmtTs(item['timestamp'] as String?);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ts,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  url,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            reviewed ? Icons.check_circle : Icons.circle_outlined,
            color: reviewed ? AppTheme.safeGreen : AppTheme.textSecondary,
            size: 18,
          ),
        ],
      ),
    );
  }

  Color _riskColor(String level) {
    switch (level) {
      case 'HIGH':
        return AppTheme.dangerRed;
      case 'MEDIUM':
        return AppTheme.warningAmber;
      default:
        return AppTheme.safeGreen;
    }
  }

  String _fmtTs(String? ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.length > 16 ? ts.substring(0, 16) : ts;
    }
  }
}
