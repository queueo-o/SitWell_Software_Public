import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session_record.dart';
import '../providers/posture_provider.dart';
import '../theme/app_colors.dart';

// ── Period selector ──────────────────────────────────────────────────────────

enum _Period { d7, d30, d90 }

extension on _Period {
  String get label => switch (this) {
        _Period.d7  => '7 Days',
        _Period.d30 => '30 Days',
        _Period.d90 => '90 Days',
      };

  int get days => switch (this) {
        _Period.d7  => 7,
        _Period.d30 => 30,
        _Period.d90 => 90,
      };

  int get buckets => switch (this) {
        _Period.d7  => 7,
        _Period.d30 => 6,
        _Period.d90 => 6,
      };
}

// ── Aggregated bucket ────────────────────────────────────────────────────────

class _Bucket {
  final String label;
  final double? avgScore;   // null when no sessions fell in this bucket
  final int     minutes;
  final int     sessions;
  const _Bucket({
    required this.label,
    required this.avgScore,
    required this.minutes,
    required this.sessions,
  });
}

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  _Period _period = _Period.d7;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = context.watch<PostureProvider>();

    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final windowStart =
        today.subtract(Duration(days: _period.days - 1));

    // Sessions that started within the selected window.
    final inWindow = p.sessionHistory.where((s) {
      final d = DateTime(
          s.startedAt.year, s.startedAt.month, s.startedAt.day);
      return !d.isBefore(windowStart);
    }).toList();

    final buckets = _buildBuckets(inWindow, windowStart);

    // Headline aggregates.
    final scored = inWindow.where((s) => s.score > 0).toList();
    final avgScore = scored.isEmpty
        ? 0
        : (scored.fold<int>(0, (a, s) => a + s.score) / scored.length)
            .round();
    final totalMinutes =
        inWindow.fold<int>(0, (a, s) => a + s.duration.inMinutes);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  _PeriodTabs(
                    selected: _period,
                    onChanged: (p) => setState(() => _period = p),
                  ),
                  const SizedBox(height: 20),
                  if (inWindow.isEmpty)
                    const _NoDataState()
                  else ...[
                    _SummaryRow(
                      avgScore: avgScore,
                      totalMinutes: totalMinutes,
                      sessions: inWindow.length,
                    ),
                    const SizedBox(height: 16),
                    _ScoreChartCard(buckets: buckets),
                    const SizedBox(height: 16),
                    _TimeChartCard(buckets: buckets),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Bucket> _buildBuckets(
      List<SessionRecord> inWindow, DateTime windowStart) {
    final n = _period.buckets;
    final daysPerBucket = (_period.days / n).ceil();

    final scoreSum   = List<int>.filled(n, 0);
    final scoreCount = List<int>.filled(n, 0);
    final minutes    = List<int>.filled(n, 0);
    final sessions   = List<int>.filled(n, 0);

    for (final s in inWindow) {
      final d = DateTime(
          s.startedAt.year, s.startedAt.month, s.startedAt.day);
      var idx = d.difference(windowStart).inDays ~/ daysPerBucket;
      if (idx < 0) idx = 0;
      if (idx >= n) idx = n - 1;
      minutes[idx]  += s.duration.inMinutes;
      sessions[idx] += 1;
      if (s.score > 0) {
        scoreSum[idx]   += s.score;
        scoreCount[idx] += 1;
      }
    }

    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return List.generate(n, (i) {
      final bucketStart =
          windowStart.add(Duration(days: i * daysPerBucket));
      final label = _period == _Period.d7
          ? weekdayLabels[(bucketStart.weekday - 1) % 7]
          : '${bucketStart.month}/${bucketStart.day}';
      return _Bucket(
        label: label,
        avgScore: scoreCount[i] > 0 ? scoreSum[i] / scoreCount[i] : null,
        minutes: minutes[i],
        sessions: sessions[i],
      );
    });
  }
}

// ── Summary stat row ─────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final int avgScore;
  final int totalMinutes;
  final int sessions;
  const _SummaryRow({
    required this.avgScore,
    required this.totalMinutes,
    required this.sessions,
  });

  String get _timeLabel {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: '$avgScore',
            label: 'AVG SCORE',
            icon: Icons.speed_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            value: _timeLabel,
            label: 'TOTAL TIME',
            icon: Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            value: '$sessions',
            label: sessions == 1 ? 'SESSION' : 'SESSIONS',
            icon: Icons.event_note_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: c.accent, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                color: c.textPri,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score line chart card ────────────────────────────────────────────────────

class _ScoreChartCard extends StatelessWidget {
  final List<_Bucket> buckets;
  const _ScoreChartCard({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _ChartCard(
      title: 'Average Posture Score',
      child: SizedBox(
        height: 150,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LineChartPainter(
            buckets: buckets,
            line: c.accent,
            fill: c.accent.withValues(alpha: 0.14),
            grid: c.border,
            labelColor: c.textMuted,
          ),
        ),
      ),
    );
  }
}

// ── Session-time bar chart card ──────────────────────────────────────────────

class _TimeChartCard extends StatelessWidget {
  final List<_Bucket> buckets;
  const _TimeChartCard({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _ChartCard(
      title: 'Total Session Time',
      child: SizedBox(
        height: 150,
        child: CustomPaint(
          size: Size.infinite,
          painter: _BarChartPainter(
            buckets: buckets,
            bar: c.green,
            grid: c.border,
            labelColor: c.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPri,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Line chart painter ───────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<_Bucket> buckets;
  final Color line;
  final Color fill;
  final Color grid;
  final Color labelColor;

  _LineChartPainter({
    required this.buckets,
    required this.line,
    required this.fill,
    required this.grid,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    const leftPad = 30.0; // room for y-axis value labels
    final chartH = size.height - labelH;
    final chartW = size.width - leftPad;

    // Horizontal grid lines + y-axis labels at 0 / 50 / 100 (score scale).
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final v in [0.0, 0.5, 1.0]) {
      final y = chartH * (1 - v);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      _drawYLabel(canvas, '${(v * 100).toInt()}', leftPad - 5, y, labelColor);
    }

    if (buckets.isEmpty) return;

    final n = buckets.length;
    double xFor(int i) =>
        leftPad + (n == 1 ? chartW / 2 : chartW * i / (n - 1));
    double yFor(double score) => chartH * (1 - (score / 100).clamp(0, 1));

    // Build point list (only buckets that have a score).
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final s = buckets[i].avgScore;
      if (s != null) pts.add(Offset(xFor(i), yFor(s)));
    }

    if (pts.isNotEmpty) {
      // Fill under the line.
      final fillPath = Path()..moveTo(pts.first.dx, chartH);
      for (final pt in pts) {
        fillPath.lineTo(pt.dx, pt.dy);
      }
      fillPath.lineTo(pts.last.dx, chartH);
      fillPath.close();
      canvas.drawPath(fillPath, Paint()..color = fill);

      // Line.
      final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        linePath.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Dots.
      for (final pt in pts) {
        canvas.drawCircle(pt, 3.5, Paint()..color = line);
      }
    }

    // X-axis labels.
    for (var i = 0; i < n; i++) {
      _drawLabel(canvas, buckets[i].label, xFor(i), chartH + 4, labelColor);
    }
  }

  void _drawLabel(
      Canvas canvas, String text, double cx, double top, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, top));
  }

  // Right-aligned label ending at [rightX], vertically centered on [cy].
  void _drawYLabel(
      Canvas canvas, String text, double rightX, double cy, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rightX - tp.width, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.buckets != buckets;
}

// ── Bar chart painter ────────────────────────────────────────────────────────

class _BarChartPainter extends CustomPainter {
  final List<_Bucket> buckets;
  final Color bar;
  final Color grid;
  final Color labelColor;

  _BarChartPainter({
    required this.buckets,
    required this.bar,
    required this.grid,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 18.0;
    const leftPad = 36.0; // room for y-axis minute labels
    final chartH = size.height - labelH;
    final chartW = size.width - leftPad;

    final maxMin = buckets.isEmpty
        ? 0
        : buckets.map((b) => b.minutes).fold<int>(0, (a, b) => a > b ? a : b);

    // Horizontal grid lines + y-axis labels at 0, mid, max (minutes).
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;

    String fmtMin(int m) => m >= 60
        ? '${m ~/ 60}h${m % 60 == 0 ? '' : '${m % 60}m'}'
        : '${m}m';

    final yTicks = [0, maxMin ~/ 2, maxMin];
    for (final tick in yTicks) {
      final frac = maxMin > 0 ? tick / maxMin : 0.0;
      final y = chartH * (1 - frac);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      _drawYLabel(canvas, fmtMin(tick), leftPad - 4, y, labelColor);
    }

    if (buckets.isEmpty) return;

    final n = buckets.length;
    final slot = chartW / n;
    final barW = slot * 0.5;

    for (var i = 0; i < n; i++) {
      final m = buckets[i].minutes;
      final cx = leftPad + slot * i + slot / 2;
      if (maxMin > 0 && m > 0) {
        final h = chartH * (m / maxMin);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, chartH - h, barW, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        );
        canvas.drawRRect(rect, Paint()..color = bar);
      }
      _drawLabel(canvas, buckets[i].label, cx, chartH + 4, labelColor);
    }
  }

  void _drawLabel(
      Canvas canvas, String text, double cx, double top, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, top));
  }

  // Right-aligned label ending at [rightX], vertically centered on [cy].
  void _drawYLabel(
      Canvas canvas, String text, double rightX, double cy, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(rightX - tp.width, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.buckets != buckets;
}

// ── No-data placeholder ──────────────────────────────────────────────────────

class _NoDataState extends StatelessWidget {
  const _NoDataState();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_rounded, size: 48, color: c.textMuted),
          const SizedBox(height: 16),
          Text(
            'No data yet',
            style: TextStyle(
              color: c.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete sessions to see your posture insights.',
            style: TextStyle(color: c.textMuted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Text(
            'INSIGHTS',
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
}

// ── Period tabs ──────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final _Period selected;
  final ValueChanged<_Period> onChanged;

  const _PeriodTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: _Period.values.map((p) {
          final isSel = p == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? c.accent.withValues(alpha: 0.15) : null,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? c.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  p.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSel ? c.accent : c.textMuted,
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
