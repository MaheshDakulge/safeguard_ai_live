import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BlocklistScreen extends StatefulWidget {
  const BlocklistScreen({super.key});
  @override
  State<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<BlocklistScreen> {
  Map<String, dynamic>? _stats;
  List<dynamic> _domains = [];
  bool _loading = true;
  bool _adding  = false;
  final _domainCtrl = TextEditingController();
  String _selectedCategory = 'objectionable';

  static const _categories = [
    ('objectionable', 'Objectionable'),
    ('pornography',   'Explicit Content'),
    ('gambling',      'Gambling'),
    ('violence',      'Violence'),
    ('drugs',         'Drugs'),
    ('hate',          'Hate / Racism'),
    ('weapons',       'Weapons'),
  ];

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _domainCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats   = await ApiService.getBlocklistStats();
    final blocked = await ApiService.getBlockedUrls();  
    if (!mounted) return;
    setState(() {
      _stats   = stats;
      _domains = blocked?['domains'] as List<dynamic>? ?? [];
      _loading = false;
    });
  }

  Future<void> _add() async {
    final domain = _domainCtrl.text.trim().toLowerCase();
    if (domain.isEmpty) return;
    setState(() => _adding = true);
    final ok = await ApiService.addBlockedUrl(domain, _selectedCategory);
    if (!mounted) return;
    setState(() => _adding = false);
    if (ok) {
      _domainCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.shield_outlined, color: AppTheme.emerald, size: 18),
          const SizedBox(width: 8),
          Text('$domain blocked successfully',
            style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        ])));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed — domain may already be blocked.',
          style: GoogleFonts.inter(color: AppTheme.textPrimary))));
    }
  }

  Future<void> _remove(String domain) async {
    final ok = await ApiService.removeBlockedUrl(domain);
    if (!mounted) return;
    if (ok) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cannot remove built-in dataset blocks.',
          style: GoogleFonts.inter(color: AppTheme.textPrimary))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryViolet));
    }

    final total   = _stats?['total_blocked_domains'] ?? 0;
    final builtin = _stats?['builtin_count'] ?? 0;
    final custom  = _stats?['custom_count'] ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Stats row
        Row(children: [
          Expanded(child: _statTile('$total', 'Total', AppTheme.primaryViolet)),
          const SizedBox(width: 10),
          Expanded(child: _statTile('$builtin', 'Built-In', AppTheme.neonCyan)),
          const SizedBox(width: 10),
          Expanded(child: _statTile('$custom', 'Custom', AppTheme.emerald)),
        ]),
        const SizedBox(height: 24),

        // Add form
        Text('ADD CUSTOM BLOCK', style: GoogleFonts.inter(
          color: AppTheme.textMuted, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryViolet.withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: _domainCtrl,
              style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 14),
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'e.g. badsite.com'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: AppTheme.surfaceCard,
              style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              items: _categories.map((c) => DropdownMenuItem(
                value: c.$1,
                child: Text(c.$2))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.violetGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton.icon(
                  onPressed: _adding ? null : _add,
                  icon: _adding
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.shield_rounded, size: 18),
                  label: Text('Block Domain', style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // Domain list
        Text('ALL BLOCKED DOMAINS', style: GoogleFonts.inter(
          color: AppTheme.textMuted, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 10),

        if (_domains.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider)),
            child: Text('No domains loaded yet.',
              style: GoogleFonts.inter(color: AppTheme.textMuted)),
          )
        else
          ..._domains.map((d) => _domainRow(d)),
      ],
    );
  }

  Widget _statTile(String value, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      Text(value, style: GoogleFonts.outfit(
        color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.inter(
        color: AppTheme.textMuted, fontSize: 10)),
    ]),
  );

  Widget _domainRow(Map<String, dynamic> d) {
    final isCustom = d['source'] == 'parent';
    final catColor = AppTheme.categoryColor(d['category'] as String? ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d['domain'] as String? ?? '',
              style: GoogleFonts.inter(color: AppTheme.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                child: Text((d['display_category'] ?? d['category']) as String? ?? '',
                  style: GoogleFonts.inter(color: catColor, fontSize: 9)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCustom
                    ? AppTheme.primaryViolet.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4)),
                child: Text(isCustom ? 'Custom' : 'Dataset',
                  style: GoogleFonts.inter(
                    color: isCustom ? AppTheme.primaryLight : AppTheme.textMuted,
                    fontSize: 9)),
              ),
            ]),
          ]),
        ),
        if (isCustom)
          GestureDetector(
            onTap: () => _remove(d['domain'] as String),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.danger, size: 16),
            ),
          )
        else
          const Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted, size: 16),
      ]),
    );
  }
}
