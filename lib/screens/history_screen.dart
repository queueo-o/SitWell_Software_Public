import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session_record.dart';
import '../providers/posture_provider.dart';
import '../theme/app_colors.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _groupLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}';
}

// ── Screen ───────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filterIndex = 0;
  final _searchController = TextEditingController();

  static const _filters = ['This Week', 'Last Month', 'Score > 90'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SessionRecord> _filtered(List<SessionRecord> all) {
    var list = all;
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) => s.name.toLowerCase().contains(q)).toList();
    }
    if (_filterIndex == 2) {
      list = list.where((s) => s.score > 90).toList();
    }
    return list;
  }

  Map<String, List<SessionRecord>> _grouped(List<SessionRecord> all) {
    final result = <String, List<SessionRecord>>{};
    for (final s in _filtered(all)) {
      final label = _groupLabel(s.startedAt);
      result.putIfAbsent(label, () => []).add(s);
    }
    for (final group in result.values) {
      group.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = context.watch<PostureProvider>();
    final grouped = _grouped(p.sessionHistory);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _topBar(c),
            Expanded(
              child: grouped.isEmpty
                  ? _emptyState(c)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _searchBar(c),
                          const SizedBox(height: 14),
                          _filterChips(c),
                          const SizedBox(height: 24),
                          for (final entry in grouped.entries) ...[
                            _sectionHeader(c, entry.key),
                            const SizedBox(height: 10),
                            for (final s in entry.value) _sessionCard(c, p, s),
                            const SizedBox(height: 20),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Text(
            'SESSION HISTORY',
            style: TextStyle(
              color: c.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          Container(
            width: 38,
            height: 38,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              border: Border.all(color: c.border),
            ),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  Icon(Icons.bluetooth, color: c.accent, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.border),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: c.textPri, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search sessions...',
          hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
          prefixIcon:
              Icon(Icons.search_rounded, color: c.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _filterChips(AppColors c) {
    return Row(
      children: List.generate(_filters.length, (i) {
        final selected = _filterIndex == i;
        return Padding(
          padding: EdgeInsets.only(right: i < _filters.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? c.accent.withValues(alpha: 0.12) : c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? c.accent : c.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  color: selected ? c.accent : c.textMuted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _sectionHeader(AppColors c, String label) {
    return Text(
      label,
      style: TextStyle(
        color: c.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }

  Widget _emptyState(AppColors c) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 52, color: c.textMuted),
          const SizedBox(height: 16),
          Text(
            'No sessions yet',
            style: TextStyle(
                color: c.textPri, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Sessions will appear here after you end one.',
            style: TextStyle(color: c.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(AppColors c, PostureProvider p, SessionRecord s) {
    final scoreColor = switch (s.trend) {
      SessionTrend.improved => c.accent,
      SessionTrend.declined => c.pink,
      SessionTrend.stable   => c.green,
    };
    final (trendIcon, trendLabel) = switch (s.trend) {
      SessionTrend.improved => (Icons.trending_up_rounded,   'IMPROVED'),
      SessionTrend.declined => (Icons.trending_down_rounded, 'DECLINED'),
      SessionTrend.stable   => (Icons.trending_flat_rounded, 'STABLE'),
    };

    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(c),
      onDismissed: (_) {
        p.removeSession(s.id);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: c.surface,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: c.border),
            ),
            content: Text(
              '"${s.name}" deleted',
              style: TextStyle(color: c.textPri),
            ),
            action: SnackBarAction(
              label: 'Undo',
              textColor: c.accent,
              onPressed: () => p.restoreSession(s),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scoreColor.withValues(alpha: 0.6), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: scoreColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: TextStyle(
                                      color: c.textPri,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    s.timeLabel,
                                    style: TextStyle(
                                        color: c.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${s.score}',
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(trendIcon,
                                        size: 12, color: scoreColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      trendLabel,
                                      style: TextStyle(
                                        color: scoreColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: c.border),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                                Icons.airline_seat_recline_extra_rounded,
                                size: 14,
                                color: c.textMuted),
                            const SizedBox(width: 5),
                            Text('${s.slouches} Slouches',
                                style: TextStyle(
                                    color: c.textMuted, fontSize: 12)),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              width: 1,
                              height: 12,
                              color: c.border,
                            ),
                            Icon(Icons.timer_outlined,
                                size: 14, color: c.textMuted),
                            const SizedBox(width: 5),
                            Text(s.activeLabel,
                                style: TextStyle(
                                    color: c.textMuted, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _deleteBackground(AppColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.pink.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Icon(Icons.delete_outline_rounded, color: c.pink, size: 24),
    );
  }
}
