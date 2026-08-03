import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hardware_check.dart';
import '../providers/posture_provider.dart';
import '../services/ble_service.dart';
import '../theme/app_colors.dart';
import 'history_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

// ── App shell ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  StreamSubscription<PostureNotification>? _notifSub;

  late final List<Widget> _tabs = const [
    _DashboardPage(),
    SetupScreen(),
    InsightsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifSub = context.read<PostureProvider>().notifications.listen(
        _showPostureNotification,
      );
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _showPostureNotification(PostureNotification n) {
    if (!mounted) return;
    final c = AppColors.of(context);
    final isSuggestion = n.level == PostureNotificationLevel.suggestion;
    final accent = isSuggestion ? c.accent : c.amber;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: c.surface,
        behavior: SnackBarBehavior.floating,
        // Sit just above the bottom nav bar, full-width feel.
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: 0.6)),
        ),
        duration: Duration(seconds: isSuggestion ? 6 : 3),
        dismissDirection: DismissDirection.down,
        content: GestureDetector(
          // Tap anywhere on the notification to dismiss it immediately.
          onTap: () => messenger.hideCurrentSnackBar(),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(
                isSuggestion
                    ? Icons.lightbulb_outline_rounded
                    : Icons.warning_amber_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n.message,
                  style: TextStyle(color: c.textPri, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        action: isSuggestion
            ? SnackBarAction(
                label: 'Re-calibrate',
                textColor: c.accent,
                onPressed: () {
                  setState(() => _tabIndex = 0);
                  context.read<PostureProvider>().calibrate();
                },
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: IndexedStack(index: _tabIndex, children: _tabs),
      bottomNavigationBar: _BottomNav(
        index: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

// ── Bottom nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: index == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.tune_rounded,
                label: 'Sensor',
                selected: index == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'Insights',
                selected: index == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'History',
                selected: index == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: index == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = selected ? c.accent : c.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard page ───────────────────────────────────────────────────────────

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostureProvider>();
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              title: 'SitWell',
              connected: p.isConnected,
              connectionState: p.connectionState,
            ),
            Expanded(
              child: p.isConnected
                  ? _ConnectedBody(p: p)
                  : _DisconnectedBody(p: p),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared top bar ───────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String title;
  final bool connected;
  final BleConnectionState connectionState;
  const _TopBar({
    required this.title,
    required this.connected,
    required this.connectionState,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: c.textPri,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const Spacer(),
          _AppLogoBadge(active: connected),
        ],
      ),
    );
  }
}

class _AppLogoBadge extends StatelessWidget {
  final bool active;
  const _AppLogoBadge({this.active = true});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.surface,
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/logo.png',
        fit: BoxFit.cover,
        color: active ? null : c.textMuted.withValues(alpha: 0.6),
        colorBlendMode: active ? null : BlendMode.modulate,
        errorBuilder: (context, error, stack) => Icon(
          Icons.bluetooth,
          color: active ? c.accent : c.textMuted,
          size: 18,
        ),
      ),
    );
  }
}

// ── Connected body ───────────────────────────────────────────────────────────

class _ConnectedBody extends StatefulWidget {
  final PostureProvider p;
  const _ConnectedBody({required this.p});

  @override
  State<_ConnectedBody> createState() => _ConnectedBodyState();
}

class _ConnectedBodyState extends State<_ConnectedBody> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final c = AppColors.of(context);

    // Connected but no session yet → show "ready to start" screen.
    if (!p.isSessionActive) return _IdleBody(p: p);

    final score = p.postureScore;
    final scoreColor = _scoreColor(c, score);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 4),
          _StatusRow(
            state: p.connectionState,
            batteryPercent: p.batteryPercent,
            lastSyncLabel: p.lastSyncLabel,
          ),
          const SizedBox(height: 12),
          _HardwareCheckBanner(p: p),
          const Spacer(flex: 2),

          // Circular score gauge
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(200, 200),
                  painter: _ScoreGaugePainter(
                    score: score / 100.0,
                    fillColor: scoreColor,
                    trackColor: c.surfaceDeep,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SCORE',
                      style: TextStyle(
                        color: c.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.isCalibrated ? '$score' : '--',
                      style: TextStyle(
                        color: c.textPri,
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.postureLabel,
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(flex: 2),

          // Session timer
          Text(
            'CURRENT SESSION',
            style: TextStyle(
              color: c.textMuted,
              fontSize: 10,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _fmtDuration(p.sessionDuration),
            style: TextStyle(
              color: c.textPri,
              fontSize: 34,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
            ),
          ),

          const Spacer(flex: 2),

          // Calibrate / Re-calibrate button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: p.isCalibrating || !p.canCalibrate
                  ? null
                  : p.calibrate,
              style: OutlinedButton.styleFrom(
                backgroundColor: c.accent.withValues(alpha: 0.12),
                side: BorderSide(color: c.accent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                foregroundColor: c.accent,
                disabledForegroundColor: c.accent.withValues(alpha: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.isCalibrating
                        ? Icons.hourglass_top_rounded
                        : (p.isCalibrated
                              ? Icons.refresh_rounded
                              : Icons.tune_rounded),
                    size: 16,
                    color: c.accent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    p.isCalibrating
                        ? 'CALIBRATING… ${(p.calibrationProgress * 100).toInt()}%'
                        : (!p.canCalibrate
                              ? 'SENSOR CHECK REQUIRED'
                              : (p.isCalibrated
                                    ? 'RE-CALIBRATE'
                                    : 'START CALIBRATION')),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Pause / Resume button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: p.isCalibrating
                  ? null
                  : (p.isPaused ? p.resumeSession : p.pauseSession),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: p.isPaused ? c.amber : c.accent,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                foregroundColor: p.isPaused ? c.amber : c.accent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 18,
                    color: p.isPaused ? c.amber : c.accent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    p.isPaused ? 'RESUME SESSION' : 'PAUSE SESSION',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // End session button — saves the session to History/Insights and
          // returns to the idle "ready to start" state (does NOT disconnect).
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: p.endSession,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.accent, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                foregroundColor: c.accent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent,
                      boxShadow: [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.55),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'END SESSION',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(flex: 2),

          // Slouches stat
          _StatCell(value: '${p.slouchCount}', label: 'SLOUCHES'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static Color _scoreColor(AppColors c, int score) {
    if (score >= 90) return c.accent;
    if (score >= 70) return c.green;
    if (score >= 50) return c.amber;
    return c.pink;
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// ── Idle body (connected, no active session) ────────────────────────────────

class _IdleBody extends StatelessWidget {
  final PostureProvider p;
  const _IdleBody({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final calibrated = p.isCalibrated;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 4),
          _StatusRow(
            state: p.connectionState,
            batteryPercent: p.batteryPercent,
            lastSyncLabel: p.lastSyncLabel,
          ),
          const Spacer(flex: 3),

          // Centerpiece: animated device-ready badge
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.accent.withValues(alpha: 0.08),
              border: Border.all(color: c.accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.35),
                  blurRadius: 22,
                ),
              ],
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: c.accent,
              size: 64,
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Ready to start',
            style: TextStyle(
              color: c.textPri,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap START SESSION, then calibrate your baseline from the '
            'live dashboard once you\'re seated.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 13, height: 1.4),
          ),

          const Spacer(flex: 3),

          // Primary action — Start Session (calibration happens afterward)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: p.startSession,
              style: OutlinedButton.styleFrom(
                backgroundColor: c.accent.withValues(alpha: 0.15),
                side: BorderSide(color: c.accent, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                foregroundColor: c.accent,
                disabledForegroundColor: c.accent.withValues(alpha: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'START SESSION',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Secondary hint — already calibrated from a previous session
          if (calibrated) ...[
            const SizedBox(height: 12),
            Text(
              'Baseline calibrated — you can re-calibrate any time '
              'during the session.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.green, fontSize: 12, height: 1.3),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _HardwareCheckBanner extends StatelessWidget {
  final PostureProvider p;
  const _HardwareCheckBanner({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final state = p.hardwareCheckState;
    final (icon, color) = switch (state) {
      HardwareCheckState.notRun => (Icons.sensors_rounded, c.textMuted),
      HardwareCheckState.checking => (Icons.sync_rounded, c.amber),
      HardwareCheckState.passed => (Icons.check_circle_rounded, c.green),
      HardwareCheckState.failed => (Icons.error_rounded, c.pink),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.hardwareCheckMessage,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state == HardwareCheckState.failed)
            TextButton(
              onPressed: p.runHardwareCheck,
              child: const Text('RETRY'),
            ),
        ],
      ),
    );
  }
}

// ── Status row ───────────────────────────────────────────────────────────────

class _StatusRow extends StatelessWidget {
  final BleConnectionState state;
  final int batteryPercent;
  final String lastSyncLabel;
  const _StatusRow({
    required this.state,
    required this.batteryPercent,
    required this.lastSyncLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, dotColor) = switch (state) {
      BleConnectionState.connected => ('Connected', c.green),
      BleConnectionState.scanning => ('Scanning…', c.amber),
      BleConnectionState.connecting => ('Connecting…', c.amber),
      BleConnectionState.error => ('Error', c.pink),
      BleConnectionState.disconnected => ('Offline', c.textMuted),
    };

    return Row(
      children: [
        _Chip(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: c.textPri, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Chip(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.battery_full_rounded, size: 13, color: c.green),
              const SizedBox(width: 5),
              Text(
                state == BleConnectionState.connected
                    ? '$batteryPercent%'
                    : '—',
                style: TextStyle(color: c.textPri, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Chip(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sync_rounded, size: 13, color: c.textMuted),
              const SizedBox(width: 5),
              Text(
                lastSyncLabel == '—' ? 'Just now' : lastSyncLabel,
                style: TextStyle(color: c.textPri, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final Widget child;
  const _Chip({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

// ── Stat cell ────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: c.textPri,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: c.textMuted,
            fontSize: 10,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── Score gauge painter ──────────────────────────────────────────────────────

class _ScoreGaugePainter extends CustomPainter {
  final double score;
  final Color fillColor;
  final Color trackColor;

  static const double _startAngle = 150 * pi / 180;
  static const double _totalSweep = 240 * pi / 180;

  const _ScoreGaugePainter({
    required this.score,
    required this.fillColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const stroke = 14.0;

    canvas.drawArc(
      rect,
      _startAngle,
      _totalSweep,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    if (score <= 0) return;
    final sweep = _totalSweep * score.clamp(0.0, 1.0);

    canvas.drawArc(
      rect,
      _startAngle,
      sweep,
      false,
      Paint()
        ..color = fillColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    canvas.drawArc(
      rect,
      _startAngle,
      sweep,
      false,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    final tipAngle = _startAngle + sweep;
    final tipX = center.dx + radius * cos(tipAngle);
    final tipY = center.dy + radius * sin(tipAngle);
    canvas.drawCircle(
      Offset(tipX, tipY),
      8,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(Offset(tipX, tipY), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ScoreGaugePainter old) =>
      old.score != score ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

// ── Disconnected body ────────────────────────────────────────────────────────

class _DisconnectedBody extends StatelessWidget {
  final PostureProvider p;
  const _DisconnectedBody({required this.p});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final busy =
        p.connectionState == BleConnectionState.scanning ||
        p.connectionState == BleConnectionState.connecting;
    final errored = p.connectionState == BleConnectionState.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surface,
                border: Border.all(color: c.border, width: 1.5),
              ),
              child: Icon(
                Icons.bluetooth_disabled,
                size: 44,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Device Found',
              style: TextStyle(
                color: c.textPri,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Turn on "Posture Check BT" and keep it nearby.',
              style: TextStyle(color: c.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            if (busy) ...[
              CircularProgressIndicator(color: c.accent),
              const SizedBox(height: 20),
              TextButton(
                onPressed: p.disconnect,
                child: Text('Cancel', style: TextStyle(color: c.textMuted)),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: p.connect,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.accent, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: c.accent,
                  ),
                  child: const Text(
                    'Connect to Device',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (errored) ...[
              const SizedBox(height: 16),
              Text(
                'Could not find device. Make sure it is advertising.',
                style: TextStyle(color: c.pink, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
