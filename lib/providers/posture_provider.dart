import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sensor_config.dart';
import '../services/ble_service.dart';

class PostureProvider extends ChangeNotifier {
  final BleService _ble = BleService.instance;

  StreamSubscription<BleConnectionState>? _connSub;
  StreamSubscription<String>?             _lineSub;
  Timer? _alertClearTimer;

  // ── Connection ───────────────────────────────────────────────────────────
  BleConnectionState _connState = BleConnectionState.disconnected;
  bool _demoMode = false;

  BleConnectionState get connectionState =>
      _demoMode ? BleConnectionState.connected : _connState;
  bool get isConnected =>
      _demoMode || _connState == BleConnectionState.connected;
  bool get isDemoMode => _demoMode;

  // ── Device info (stubbed: hardware does not report these) ────────────────
  String get deviceName      => 'Posture Pad Pro';
  String get firmwareVersion => isConnected ? 'v2.4.1' : '—';
  int    get batteryPercent  => isConnected ? 82 : 0;

  DateTime? _lastLineAt;
  String get lastSyncLabel {
    if (!isConnected || _lastLineAt == null) return '—';
    final diff = DateTime.now().difference(_lastLineAt!);
    if (diff.inSeconds < 30) return 'Just now';
    if (diff.inMinutes < 1)  return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    final h = _lastLineAt!.hour % 12 == 0 ? 12 : _lastLineAt!.hour % 12;
    final m = _lastLineAt!.minute.toString().padLeft(2, '0');
    final period = _lastLineAt!.hour < 12 ? 'AM' : 'PM';
    return 'Today, $h:$m $period';
  }

  // ── Sensor config ────────────────────────────────────────────────────────
  final List<SensorConfig> _sensors = SensorConfig.defaults();
  List<SensorConfig> get sensors => List.unmodifiable(_sensors);

  // ── Calibration ──────────────────────────────────────────────────────────
  bool   _isCalibrated        = false;
  bool   _isCalibrating       = false;
  double _calibrationProgress = 0.0;
  final List<String>    _calibrationLog = [];
  final Map<String, double> _baselines  = {};

  bool   get isCalibrated        => _isCalibrated;
  bool   get isCalibrating       => _isCalibrating;
  double get calibrationProgress => _calibrationProgress;
  List<String>       get calibrationLog => List.unmodifiable(_calibrationLog);
  Map<String, double> get baselines     => Map.unmodifiable(_baselines);

  // ── Posture ──────────────────────────────────────────────────────────────
  bool         _postureGood = true;
  List<String> _alerts      = [];
  final Map<String, int> _readings   = {};
  final Map<String, int> _sessionMin = {};
  final Map<String, int> _sessionMax = {};

  bool         get postureGood => _postureGood;
  List<String> get alerts      => List.unmodifiable(_alerts);
  Map<String, int> get readings   => Map.unmodifiable(_readings);
  Map<String, int> get sessionMin => Map.unmodifiable(_sessionMin);
  Map<String, int> get sessionMax => Map.unmodifiable(_sessionMax);

  // ── Session ──────────────────────────────────────────────────────────────
  DateTime? _sessionStart;
  int       _slouchCount = 0;
  int       _sessionGoalMinutes = 60;
  bool      _isPaused = false;
  Duration  _pausedAt = Duration.zero;

  Duration get sessionDuration {
    if (_isPaused) return _pausedAt;
    if (_sessionStart == null) return Duration.zero;
    return DateTime.now().difference(_sessionStart!);
  }
  int  get slouchCount        => _slouchCount;
  int  get sessionGoalMinutes => _sessionGoalMinutes;
  bool get isPaused           => _isPaused;

  Duration get goalTimeLeft {
    if (_sessionStart == null) return Duration(minutes: _sessionGoalMinutes);
    final left = Duration(minutes: _sessionGoalMinutes) - sessionDuration;
    return left.isNegative ? Duration.zero : left;
  }

  int get postureScore {
    if (!_isCalibrated) return 0;
    final active = _sensors.where((s) => s.isActive).toList();
    if (active.isEmpty) return 100;
    double totalDev = 0;
    int count = 0;
    for (final s in active) {
      final r = _readings[s.key];
      final b = _baselines[s.key];
      if (r != null && b != null && b > 0) {
        totalDev += ((r - b) / b * 100).abs();
        count++;
      }
    }
    if (count == 0) return 100;
    return (100 - (totalDev / count).clamp(0.0, 100.0)).round();
  }

  String get postureLabel {
    if (!_isCalibrated) return 'Not calibrated';
    final s = postureScore;
    if (s >= 90) return 'Excellent alignment';
    if (s >= 70) return 'Good posture';
    if (s >= 50) return 'Fair posture';
    return 'Poor posture';
  }

  // ── App state ────────────────────────────────────────────────────────────
  bool _prefsLoaded      = false;
  bool _privacyAccepted  = false;

  bool get prefsLoaded     => _prefsLoaded;
  bool get privacyAccepted => _privacyAccepted;

  Future<void> acceptPrivacy() async {
    _privacyAccepted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_accepted', true);
    notifyListeners();
  }

  // ── Notification preferences ─────────────────────────────────────────────
  bool _postureReminders  = true;
  bool _sessionSummaries  = true;
  bool _streakNudges      = false;

  bool get postureReminders => _postureReminders;
  bool get sessionSummaries => _sessionSummaries;
  bool get streakNudges     => _streakNudges;

  // ── Parse state ──────────────────────────────────────────────────────────
  bool         _inAlertBlock    = false;
  bool         _inReadingsBlock = false;
  List<String> _pendingAlerts   = [];

  // ── Bad-posture tracking (drives notifications) ──────────────────────────
  DateTime? _postureBadSince;
  bool      _recalibrateSuggested = false;
  static const Duration _kSlouchSuggestThreshold = Duration(seconds: 60);

  // ── Notification stream ──────────────────────────────────────────────────
  final StreamController<PostureNotification> _notificationCtrl =
      StreamController<PostureNotification>.broadcast();
  Stream<PostureNotification> get notifications => _notificationCtrl.stream;

  // ── Demo simulation state ────────────────────────────────────────────────
  Timer? _demoLoopTimer;
  bool   _demoInSlouch         = false;
  int    _demoSlouchTicksLeft  = 0;

  PostureProvider() {
    _connSub = _ble.connectionState.listen(_onConnState);
    _lineSub = _ble.lines.listen(_onLine);
    _loadPrefs();
  }

  // ── Public actions ───────────────────────────────────────────────────────

  Future<void> connect() async {
    // Web has no native BLE — drop straight into demo mode so the UI is usable.
    if (kIsWeb) {
      enableDemoMode();
      return;
    }
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }
    await _ble.startScan();
  }

  Future<void> disconnect() async {
    _stopDemoLoop();
    if (_demoMode) {
      _demoMode = false;
      _isCalibrated = false;
      _isPaused = false;
      _pausedAt = Duration.zero;
      _baselines.clear();
      _readings.clear();
      _sessionMin.clear();
      _sessionMax.clear();
      _sessionStart = null;
      _slouchCount = 0;
      _postureBadSince = null;
      _recalibrateSuggested = false;
      notifyListeners();
      return;
    }
    await _ble.disconnect();
  }

  void pauseSession() {
    if (_isPaused) return;
    if (_sessionStart != null) {
      _pausedAt = DateTime.now().difference(_sessionStart!);
    }
    _isPaused = true;
    // Freeze posture-bad streak so the 60 s recalibrate prompt doesn't fire
    // while paused; we'll reset it on resume so the user gets a clean slate.
    _postureBadSince = null;
    _recalibrateSuggested = false;
    if (_demoMode) _stopDemoLoop();
    notifyListeners();
  }

  void resumeSession() {
    if (!_isPaused) return;
    _sessionStart = DateTime.now().subtract(_pausedAt);
    _isPaused = false;
    if (_demoMode && _isCalibrated) _startDemoLoop();
    notifyListeners();
  }

  /// Populate the provider with realistic stub data so the dashboard renders
  /// without a physical device. Used on web and as a manual fallback.
  void enableDemoMode() {
    _demoMode      = true;
    _isCalibrated  = false; // user must manually calibrate in the Sensor tab
    _isCalibrating = false;
    _isPaused      = false;
    _pausedAt      = Duration.zero;
    _postureGood   = true;
    _slouchCount   = 0;
    _sessionStart  = DateTime.now();
    _lastLineAt    = DateTime.now();

    _baselines.clear();
    _readings.clear();
    _sessionMin.clear();
    _sessionMax.clear();

    notifyListeners();
  }

  /// Generate a fresh set of demo baselines/readings. Called by [calibrate]
  /// while in demo mode so each tap produces new (random) calibrated values.
  ///
  /// Baseline ranges per hardware type:
  ///   FSR (circle):  300–500
  ///   Velostat:      550–750
  /// Deviation ±15% keeps circle sensors mostly green (50% threshold) while
  /// velostats (10% threshold) can flip yellow/red on the chair map.
  void _populateDemoCalibration() {
    final rand = math.Random();
    _baselines.clear();
    _readings.clear();
    _sessionMin.clear();
    _sessionMax.clear();

    // The post-calibration "current reading" sits essentially on the baseline
    // (tiny ±1% noise to look alive) — readings only diverge afterward when
    // the user moves / slouches.
    for (final s in _sensors) {
      final isVelostat = s.hardwareType == 'velostat';
      final b = isVelostat
          ? 550 + rand.nextInt(200) // 550–749
          : 300 + rand.nextInt(200); // 300–499
      final r = (b * (1 + (-1 + rand.nextDouble() * 2) / 100)).round();
      _baselines[s.key]  = b.toDouble();
      _readings[s.key]   = r;
      _sessionMin[s.key] = r;
      _sessionMax[s.key] = r;
    }
  }

  Future<void> calibrate() async {
    if (_demoMode) {
      // ~3 second sampling animation, then fresh baselines with readings
      // essentially at the baseline (good posture immediately after).
      _stopDemoLoop();
      // Calibrating implies the session is live again.
      if (_isPaused) {
        _isPaused = false;
        _sessionStart = DateTime.now().subtract(_pausedAt);
      }
      _isCalibrating       = true;
      _calibrationProgress = 0.0;
      _isCalibrated        = false;
      _postureGood         = true;
      _postureBadSince     = null;
      _recalibrateSuggested = false;
      _slouchCount         = 0;
      _baselines.clear();
      _readings.clear();
      _sessionMin.clear();
      _sessionMax.clear();
      notifyListeners();

      for (var pct = 20; pct <= 100; pct += 20) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        _calibrationProgress = pct / 100.0;
        notifyListeners();
      }

      _populateDemoCalibration();
      _isCalibrating = false;
      _isCalibrated  = true;
      notifyListeners();

      _startDemoLoop();
      return;
    }
    return _ble.sendCommand('c');
  }

  Future<void> requestStatus() async {
    if (_demoMode) return;
    return _ble.sendCommand('s');
  }

  Future<void> resetCalibration() async {
    if (_demoMode) {
      _stopDemoLoop();
      _isCalibrated = false;
      _baselines.clear();
      _readings.clear();
      _sessionMin.clear();
      _sessionMax.clear();
      _postureBadSince = null;
      _recalibrateSuggested = false;
      notifyListeners();
      return;
    }
    return _ble.sendCommand('r');
  }

  // ── Demo posture simulation ──────────────────────────────────────────────

  void _startDemoLoop() {
    _stopDemoLoop();
    // One tick = 2 s. Most ticks just jitter a few percent around baseline;
    // some ticks start a multi-tick "slouch" that pushes velostat readings
    // past their alert threshold so the chair map + notifications light up.
    _demoLoopTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _jitterDemoReadings();
      _evaluateDemoPosture();
      notifyListeners();
    });
  }

  void _stopDemoLoop() {
    _demoLoopTimer?.cancel();
    _demoLoopTimer = null;
    _demoInSlouch = false;
    _demoSlouchTicksLeft = 0;
  }

  void _jitterDemoReadings() {
    final rand = math.Random();

    // Manage multi-tick slouch state so bad posture persists realistically.
    // Slouch episodes last 5–40 ticks (10–80 s), so some episodes exceed the
    // 60 s "consider re-calibrating" threshold.
    if (_demoInSlouch) {
      _demoSlouchTicksLeft--;
      if (_demoSlouchTicksLeft <= 0) _demoInSlouch = false;
    } else {
      if (rand.nextDouble() < 0.25) {
        _demoInSlouch = true;
        _demoSlouchTicksLeft = 5 + rand.nextInt(36);
      }
    }

    for (final s in _sensors) {
      final baseline = _baselines[s.key];
      if (baseline == null) continue;

      double devPct;
      if (_demoInSlouch) {
        final sign = rand.nextBool() ? 1 : -1;
        if (s.hardwareType == 'velostat') {
          // Velostat threshold is 10%. Mix of amber (6–9%) and red (12–25%).
          devPct = sign *
              (rand.nextDouble() < 0.7
                  ? 12 + rand.nextDouble() * 13
                  : 6 + rand.nextDouble() * 3);
        } else {
          // Circle FSR threshold is 50%. Mix of amber (30–48%) and red (55–80%).
          devPct = sign *
              (rand.nextDouble() < 0.7
                  ? 55 + rand.nextDouble() * 25
                  : 30 + rand.nextDouble() * 18);
        }
      } else {
        // Calm posture — small natural jitter that keeps everything green.
        devPct = -2 + rand.nextDouble() * 4;
      }
      final r = (baseline * (1 + devPct / 100)).round();
      _readings[s.key] = r;
      _sessionMin[s.key] = math.min(_sessionMin[s.key] ?? r, r);
      _sessionMax[s.key] = math.max(_sessionMax[s.key] ?? r, r);
    }
  }

  /// Recompute [_postureGood] from current demo readings vs baselines and
  /// fire notifications on transitions / sustained bad posture.
  void _evaluateDemoPosture() {
    var anyBad = false;
    for (final s in _sensors.where((s) => s.isActive)) {
      final r = _readings[s.key];
      final b = _baselines[s.key];
      if (r == null || b == null || b <= 0) continue;
      final dev = ((r - b) / b).abs();
      if (dev >= s.deviationThreshold) {
        anyBad = true;
        break;
      }
    }
    _applyPostureState(badNow: anyBad);
  }

  /// Shared by demo + BLE paths. Tracks transitions and fires notifications.
  void _applyPostureState({required bool badNow}) {
    if (_isPaused) return; // paused: no slouch counting, no notifications
    final wasBad = !_postureGood;
    _postureGood = !badNow;

    if (badNow && !wasBad) {
      // Fresh slouch event
      _slouchCount++;
      _postureBadSince = DateTime.now();
      _recalibrateSuggested = false;
      _notificationCtrl.add(const PostureNotification(
        'Bad posture detected — adjust your sitting position.',
        PostureNotificationLevel.warning,
      ));
    } else if (!badNow && wasBad) {
      _postureBadSince = null;
      _recalibrateSuggested = false;
    } else if (badNow) {
      _postureBadSince ??= DateTime.now();
      if (!_recalibrateSuggested &&
          DateTime.now().difference(_postureBadSince!) >=
              _kSlouchSuggestThreshold) {
        _recalibrateSuggested = true;
        _notificationCtrl.add(const PostureNotification(
          'Still slouching? Your original calibration may be off — try re-calibrating.',
          PostureNotificationLevel.suggestion,
        ));
      }
    }
  }

  Future<void> saveSensorName(String key, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sensor_name_$key', name);
    _sensors.firstWhere((s) => s.key == key).displayName = name;
    notifyListeners();
  }

  Future<void> saveSensorActive(String key, bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sensor_active_$key', active);
    _sensors.firstWhere((s) => s.key == key).isActive = active;
    notifyListeners();
  }

  Future<void> saveSessionGoal(int minutes) async {
    _sessionGoalMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_goal_minutes', minutes);
    notifyListeners();
  }

  Future<void> savePostureReminders(bool v) async {
    _postureReminders = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_posture_reminders', v);
    notifyListeners();
  }

  Future<void> saveSessionSummaries(bool v) async {
    _sessionSummaries = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_session_summaries', v);
    notifyListeners();
  }

  Future<void> saveStreakNudges(bool v) async {
    _streakNudges = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_streak_nudges', v);
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _stopDemoLoop();
    await _ble.disconnect();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_goal_minutes');
    await prefs.remove('notif_posture_reminders');
    await prefs.remove('notif_session_summaries');
    await prefs.remove('notif_streak_nudges');
    for (final s in _sensors) {
      await prefs.remove('sensor_name_${s.key}');
      await prefs.remove('sensor_active_${s.key}');
    }

    // Reset sensors to factory defaults
    final defaults = SensorConfig.defaults();
    for (var i = 0; i < _sensors.length && i < defaults.length; i++) {
      _sensors[i].displayName = defaults[i].displayName;
      _sensors[i].isActive    = defaults[i].isActive;
    }

    _demoMode             = false;
    _connState            = BleConnectionState.disconnected;
    _isCalibrated         = false;
    _isCalibrating        = false;
    _calibrationProgress  = 0.0;
    _calibrationLog.clear();
    _baselines.clear();
    _readings.clear();
    _sessionMin.clear();
    _sessionMax.clear();
    _postureGood          = true;
    _alerts               = [];
    _sessionStart         = null;
    _slouchCount          = 0;
    _isPaused             = false;
    _pausedAt             = Duration.zero;
    _sessionGoalMinutes   = 60;
    _postureReminders     = true;
    _sessionSummaries     = true;
    _streakNudges         = false;
    _postureBadSince      = null;
    _recalibrateSuggested = false;
    _lastLineAt           = null;

    notifyListeners();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    for (final s in _sensors) {
      final savedName = prefs.getString('sensor_name_${s.key}');
      if (savedName != null) s.displayName = savedName;
      final savedActive = prefs.getBool('sensor_active_${s.key}');
      if (savedActive != null) s.isActive = savedActive;
    }
    final goalMins = prefs.getInt('session_goal_minutes');
    if (goalMins != null) _sessionGoalMinutes = goalMins;

    _postureReminders = prefs.getBool('notif_posture_reminders') ?? true;
    _sessionSummaries = prefs.getBool('notif_session_summaries') ?? true;
    _streakNudges     = prefs.getBool('notif_streak_nudges')     ?? false;
    _privacyAccepted  = prefs.getBool('privacy_accepted')        ?? false;
    _prefsLoaded      = true;

    notifyListeners();
  }

  void _onConnState(BleConnectionState state) {
    _connState = state;
    if (state == BleConnectionState.connected) {
      _sessionStart = DateTime.now();
      _slouchCount  = 0;
      _sessionMin.clear();
      _sessionMax.clear();
    }
    if (state == BleConnectionState.disconnected) {
      _isCalibrating    = false;
      _inAlertBlock     = false;
      _inReadingsBlock  = false;
      _sessionStart     = null;
      _slouchCount      = 0;
      _lastLineAt       = null;
    }
    notifyListeners();
  }

  void _trackMinMax(String key, int reading) {
    _sessionMin[key] = math.min(_sessionMin[key] ?? reading, reading);
    _sessionMax[key] = math.max(_sessionMax[key] ?? reading, reading);
  }

  /// Parse a single line from the hardware UART stream.
  void _onLine(String raw) {
    _lastLineAt = DateTime.now();
    final line = raw.trim();

    // ── Calibration flow ───────────────────────────────────────────────────
    if (line.contains('CALIBRATION STARTED')) {
      _isCalibrating       = true;
      _calibrationProgress = 0.0;
      _isCalibrated        = false;
      _calibrationLog.clear();
      _baselines.clear();
      notifyListeners();
      return;
    }

    final pMatch = RegExp(r'\[([#.]+)\]\s+(\d+)%').firstMatch(line);
    if (pMatch != null && _isCalibrating) {
      _calibrationProgress = int.parse(pMatch.group(2)!) / 100.0;
      _calibrationLog.add(line);
      notifyListeners();
      return;
    }

    if (line.contains('CALIBRATION COMPLETE')) {
      _isCalibrating       = false;
      _isCalibrated        = true;
      _calibrationProgress = 1.0;
      notifyListeners();
      return;
    }

    final bMatch = RegExp(r'(FSR\d+).*baseline\s*:\s*([\d.]+)').firstMatch(line);
    if (bMatch != null) {
      _baselines[bMatch.group(1)!.toLowerCase()] =
          double.parse(bMatch.group(2)!);
      notifyListeners();
      return;
    }

    if (line.contains('Calibration reset')) {
      _isCalibrated = false;
      _baselines.clear();
      _readings.clear();
      notifyListeners();
      return;
    }

    if (line.contains('POSTURE OK')) {
      _alerts      = [];
      _inAlertBlock = false;
      _alertClearTimer?.cancel();
      _applyPostureState(badNow: false);
      notifyListeners();
      return;
    }

    if (line.contains('POSTURE ALERT')) {
      _applyPostureState(badNow: true);
      _inAlertBlock    = true;
      _inReadingsBlock = false;
      _pendingAlerts   = [];
      return;
    }

    if (_inAlertBlock) {
      if (line.contains('⚠')) {
        final keyMatch = RegExp(r'(FSR\d+)', caseSensitive: false).firstMatch(line);
        if (keyMatch != null) {
          final key = keyMatch.group(1)!.toLowerCase();
          final sensor = _sensors.where((s) => s.key == key).firstOrNull;
          if (sensor != null && !sensor.isActive) return;
          if (sensor != null) {
            final detail = RegExp(r'pressure\s+(increased|decreased)\s+by\s+(\d+)%')
                .firstMatch(line);
            final formatted = detail != null
                ? '${sensor.displayName}: pressure ${detail.group(1)} by ${detail.group(2)}%'
                : '${sensor.displayName}: ${line.trim()}';
            _pendingAlerts.add(formatted);
          } else {
            _pendingAlerts.add(line.trim());
          }
        } else {
          _pendingAlerts.add(line.trim());
        }
        _alerts      = List.of(_pendingAlerts);
        _resetAlertTimer();
        notifyListeners();
        return;
      }
      if (line.isNotEmpty) _inAlertBlock = false;
    }

    if (line.contains('Current Readings')) {
      _inReadingsBlock = true;
      return;
    }

    if (_inReadingsBlock) {
      final rMatch = RegExp(r'(FSR\d+)\s*\([^)]+\):\s*(\d+)').firstMatch(line);
      if (rMatch != null) {
        final key = rMatch.group(1)!.toLowerCase();
        final value = int.parse(rMatch.group(2)!);
        _readings[key] = value;
        _trackMinMax(key, value);
        notifyListeners();
        return;
      }
      if (line.isNotEmpty && !line.startsWith(' ')) _inReadingsBlock = false;
    }

    if (_isCalibrating && line.isNotEmpty) {
      _calibrationLog.add(line);
      notifyListeners();
    }
  }

  void _resetAlertTimer() {
    _alertClearTimer?.cancel();
    _alertClearTimer = Timer(const Duration(seconds: 5), () {
      _alerts = [];
      _applyPostureState(badNow: false);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _alertClearTimer?.cancel();
    _demoLoopTimer?.cancel();
    _connSub?.cancel();
    _lineSub?.cancel();
    _notificationCtrl.close();
    super.dispose();
  }
}

// ── Notification model (consumed by HomeScreen SnackBar listener) ───────────

enum PostureNotificationLevel { warning, suggestion }

class PostureNotification {
  final String message;
  final PostureNotificationLevel level;
  const PostureNotification(this.message, this.level);
}
