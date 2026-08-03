import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sensor_config.dart';
import '../providers/posture_provider.dart';
import '../theme/app_colors.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostureProvider>();
    final c = AppColors.of(context);

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
                  if (p.isCalibrating) ...[
                    _ProgressStrip(progress: p.calibrationProgress),
                    const SizedBox(height: 18),
                  ],
                  _ChairSensorMap(p: p),
                  const SizedBox(height: 18),
                  _SensorMatrixCard(p: p),
                ],
              ),
            ),
          ],
        ),
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
            'SENSOR DATA',
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

// ── Progress strip ───────────────────────────────────────────────────────────

class _ProgressStrip extends StatelessWidget {
  final double progress;
  const _ProgressStrip({required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: c.surfaceDeep,
                valueColor: AlwaysStoppedAnimation<Color>(c.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              color: c.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sensor matrix card ───────────────────────────────────────────────────────

class _SensorMatrixCard extends StatelessWidget {
  final PostureProvider p;
  const _SensorMatrixCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Raw Sensor Matrix',
            style: TextStyle(
              color: c.textPri,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...p.sensors.map((s) => _SensorRow(
                sensor: s,
                // Only show live reading during an active session; otherwise
                // show '—' so the matrix stays clean between sessions.
                reading: p.isSessionActive ? p.readings[s.key] : null,
                baseline: p.baselines[s.key],
                minObs: p.sessionMin[s.key],
                maxObs: p.sessionMax[s.key],
              )),
        ],
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  final SensorConfig sensor;
  final int? reading;
  final double? baseline;
  final int? minObs;
  final int? maxObs;

  const _SensorRow({
    required this.sensor,
    this.reading,
    this.baseline,
    this.minObs,
    this.maxObs,
  });

  Color _statusColor(AppColors c) {
    if (reading == null || baseline == null || baseline! <= 0) {
      return c.textMuted;
    }
    final devFraction = ((reading! - baseline!) / baseline!).abs();
    final threshold = sensor.deviationThreshold;
    if (devFraction >= threshold)       return c.pink;
    if (devFraction >= threshold * 0.5) return c.amber;
    return c.green;
  }

  String _calibratedValue() {
    if (baseline == null) return '—';
    return baseline!.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final statusColor = _statusColor(c);
    final rawText = reading?.toString() ?? '—';
    final calibratedText = _calibratedValue();
    final minText = minObs?.toString() ?? '—';
    final maxText = maxObs?.toString() ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: c.surfaceDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                sensor.displayName,
                style: TextStyle(
                  color: c.accent,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.55),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _valueBlock(label: 'RAW', value: rawText, color: c.textPri),
              Container(
                width: 1,
                height: 28,
                color: c.border,
                margin: const EdgeInsets.symmetric(horizontal: 14),
              ),
              _valueBlock(
                label: 'CALIBRATED',
                value: calibratedText,
                color: c.accent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Min: $minText  |  Max: $maxText',
            style: TextStyle(
              color: c.textMuted,
              fontSize: 10.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueBlock({
    required String label,
    required String value,
    required Color color,
  }) {
    return Builder(builder: (context) {
      final c = AppColors.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 9,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    });
  }
}

// ── Chair sensor map ─────────────────────────────────────────────────────────

class _ChairSensorMap extends StatelessWidget {
  final PostureProvider p;
  const _ChairSensorMap({required this.p});

  Color _dotColor(AppColors c, String key) {
    // Gray when there is no active session — only colorize live during a session.
    if (!p.isSessionActive) return c.textMuted;
    final reading  = p.readings[key];
    final baseline = p.baselines[key];
    if (reading == null || baseline == null || baseline <= 0) {
      return c.textMuted;
    }
    final sensor = p.sensors.firstWhere((s) => s.key == key);
    final dev    = ((reading - baseline) / baseline).abs();
    final t      = sensor.deviationThreshold;
    if (dev >= t)       return c.pink;
    if (dev >= t * 0.5) return c.amber;
    return c.green;
  }

  bool _isCalibrated(String key) {
    final reading  = p.readings[key];
    final baseline = p.baselines[key];
    return reading != null && baseline != null && baseline > 0;
  }

  String _shortLabel(String key) {
    final n = p.sensors.firstWhere((s) => s.key == key).displayName;
    return n.split('_').first;
  }

  double _sizeFor(String key) {
    final hw = p.sensors.firstWhere((s) => s.key == key).hardwareType;
    return hw == 'velostat' ? 32 : 20;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Live Sensor Map',
                style: TextStyle(
                  color: c.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _legendDot(c.green,  c.textMuted, 'Good'),
              const SizedBox(width: 8),
              _legendDot(c.amber, c.textMuted, 'Off'),
              const SizedBox(width: 8),
              _legendDot(c.pink,  c.textMuted, 'Bad'),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 0.95,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChairOutlinePainter(
                      fill:   c.surfaceDeep,
                      stroke: c.border,
                      accent: c.accent,
                    ),
                  ),
                ),
                _placedDot(c, const Alignment(-0.40, -0.74), 'fsr1'),
                _placedDot(c, const Alignment( 0.40, -0.74), 'fsr2'),
                _placedDot(c, const Alignment( 0.00, -0.36), 'fsr3'),
                _placedDot(c, const Alignment(-0.34,  0.18), 'fsr4'),
                _placedDot(c, const Alignment( 0.34,  0.18), 'fsr5'),
                _placedDot(c, const Alignment( 0.00,  0.78), 'fsr6'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placedDot(AppColors c, Alignment alignment, String key) {
    return Align(
      alignment: alignment,
      child: _SensorDot(
        size:       _sizeFor(key),
        color:      _dotColor(c, key),
        label:      _shortLabel(key),
        calibrated: _isCalibrated(key),
      ),
    );
  }

  Widget _legendDot(Color color, Color textColor, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: textColor, fontSize: 10)),
      ],
    );
  }
}

class _ChairOutlinePainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  final Color accent;
  _ChairOutlinePainter({
    required this.fill,
    required this.stroke,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = fill;
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final w = size.width;
    final h = size.height;

    final backRect = Rect.fromLTRB(w * 0.20, h * 0.02, w * 0.80, h * 0.44);
    final backRRect = RRect.fromRectAndCorners(
      backRect,
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(backRRect, fillPaint);
    canvas.drawRRect(backRRect, strokePaint);

    final headrest = Rect.fromLTRB(w * 0.36, h * 0.05, w * 0.64, h * 0.10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(headrest, const Radius.circular(6)),
      Paint()..color = stroke.withValues(alpha: 0.4),
    );

    final seatPath = Path()
      ..moveTo(w * 0.24, h * 0.50)
      ..lineTo(w * 0.76, h * 0.50)
      ..lineTo(w * 0.94, h * 0.96)
      ..lineTo(w * 0.06, h * 0.96)
      ..close();
    canvas.drawPath(seatPath, fillPaint);
    canvas.drawPath(seatPath, strokePaint);

    canvas.drawLine(
      Offset(w * 0.10, h * 0.95),
      Offset(w * 0.90, h * 0.95),
      Paint()
        ..color = accent.withValues(alpha: 0.25)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    final foldPaint = Paint()
      ..color = stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(w * 0.20, h * 0.44),
      Offset(w * 0.24, h * 0.50),
      foldPaint,
    );
    canvas.drawLine(
      Offset(w * 0.80, h * 0.44),
      Offset(w * 0.76, h * 0.50),
      foldPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChairOutlinePainter old) =>
      old.fill != fill || old.stroke != stroke || old.accent != accent;
}

class _SensorDot extends StatelessWidget {
  final double size;
  final Color color;
  final String label;
  final bool calibrated;

  const _SensorDot({
    required this.size,
    required this.color,
    required this.label,
    required this.calibrated,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.85),
            border: Border.all(color: color, width: 1.5),
            boxShadow: calibrated
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: calibrated ? c.textPri : c.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
