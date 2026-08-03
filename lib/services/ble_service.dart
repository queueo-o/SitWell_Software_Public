import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// BLE UART service for the Posture Checker hardware.
///
/// Hardware: Adafruit ESP32-S3 Feather running CircuitPython with Nordic UART
/// Service (NUS).  Device name: "Posture Check BT".
///
/// Protocol:
///   App → device : plain text commands terminated with \r\n
///     c / calibrate  — start calibration
///     s / status     — request current readings
///     r / reset      — clear calibration
///   Device → app  : UTF-8 text lines (LF-terminated after processing)
class BleService {
  static final BleService instance = BleService._();
  BleService._();

  // ── Nordic UART Service UUIDs ─────────────────────────────────────────────
  static const String _deviceName = 'Posture Check BT';
  static const String _uartService = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _rxCharUuid  = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // notify  (device→app)
  static const String _txCharUuid  = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // write   (app→device)

  // iOS: after first connect, paste the peripheral UUID here for reliable reconnection.
  // Check the debug console for: [BLE] iOS peripheral UUID: <UUID>
  static const String _iosPeripheralId = '';

  BluetoothDevice?         _device;
  BluetoothCharacteristic? _txChar;

  StreamSubscription<List<ScanResult>>?         _scanSub;
  StreamSubscription<List<int>>?                _dataSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  final _stateCtrl = StreamController<BleConnectionState>.broadcast();
  final _lineCtrl  = StreamController<String>.broadcast();

  Stream<BleConnectionState> get connectionState => _stateCtrl.stream;

  /// Emits each complete line received from the device (including empty lines).
  Stream<String> get lines => _lineCtrl.stream;

  BleConnectionState _current = BleConnectionState.disconnected;
  BleConnectionState get currentState => _current;

  // Byte-level buffer — decoded only when a complete line is available.
  // This prevents corruption when a BLE notification splits a multi-byte
  // UTF-8 codepoint (e.g. ⚠ U+26A0) across two packets.
  final List<int> _byteBuf = [];

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> startScan() async {
    if (_current == BleConnectionState.scanning ||
        _current == BleConnectionState.connected) {
      return;
    }

    _setState(BleConnectionState.scanning);

    // iOS: direct connect by hardcoded peripheral UUID (most reliable)
    if (Platform.isIOS && _iosPeripheralId.isNotEmpty) {
      await _connect(BluetoothDevice.fromId(_iosPeripheralId));
      return;
    }

    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final byName    = r.device.platformName == _deviceName;
        final byService = r.advertisementData.serviceUuids
            .any((u) => u.str.toLowerCase() == _uartService);
        if (byName || byService) {
            FlutterBluePlus.stopScan();
            _connect(r.device);
            break;
          }
      }
    }, onError: (_) => _setState(BleConnectionState.error));

    await FlutterBluePlus.startScan(
      withNames: [_deviceName],
      timeout: const Duration(seconds: 15),
    );
  }

  Future<void> disconnect() async {
    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _dataSub?.cancel();
    _connSub?.cancel();
    await _device?.disconnect();
    _device = null;
    _txChar = null;
    _setState(BleConnectionState.disconnected);
  }

  /// Send a command string to the device (hardware reads whole lines).
  Future<void> sendCommand(String cmd) async {
    if (_txChar == null) return;
    try {
      await _txChar!.write(utf8.encode('$cmd\r\n'), withoutResponse: false);
    } catch (e) {
      debugPrint('[BLE] write error: $e');
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _setState(BleConnectionState s) {
    _current = s;
    _stateCtrl.add(s);
  }

  Future<void> _connect(BluetoothDevice device) async {
    _setState(BleConnectionState.connecting);
    _device = device;
    try {
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      _connSub?.cancel();
      _connSub = device.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _dataSub?.cancel();
          _txChar = null;
          _setState(BleConnectionState.disconnected);
        }
      });

      await device.requestMtu(512);

      final services = await device.discoverServices();
      final svc = services.firstWhere(
        (s) => s.serviceUuid.str.toLowerCase() == _uartService,
        orElse: () => throw Exception('Nordic UART service not found on device'),
      );

      _txChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid.str.toLowerCase() == _txCharUuid,
        orElse: () => throw Exception('TX characteristic not found'),
      );

      final rxChar = svc.characteristics.firstWhere(
        (c) => c.characteristicUuid.str.toLowerCase() == _rxCharUuid,
        orElse: () => throw Exception('RX characteristic not found'),
      );

      await rxChar.setNotifyValue(true);
      _dataSub?.cancel();
      _dataSub = rxChar.onValueReceived.listen(_onBytes);

      _setState(BleConnectionState.connected);

      if (Platform.isIOS) {
        debugPrint('[BLE] iOS peripheral UUID: ${device.remoteId.str}');
        debugPrint('[BLE] Paste that into BleService._iosPeripheralId for reliable reconnection.');
      }
    } catch (e) {
      debugPrint('[BLE] connect error: $e');
      _setState(BleConnectionState.error);
      await device.disconnect();
    }
  }

  /// Buffer raw bytes and emit a decoded line each time 0x0A (\n) arrives.
  /// Buffering at the byte level avoids corruption when a BLE notification
  /// splits a multi-byte UTF-8 codepoint (e.g. ⚠ 0xE2 0x9A 0xA0) across
  /// two packets.
  void _onBytes(List<int> bytes) {
    for (final byte in bytes) {
      if (byte == 0x0A) {
        // Remove any trailing \r then decode the complete line.
        if (_byteBuf.isNotEmpty && _byteBuf.last == 0x0D) {
          _byteBuf.removeLast();
        }
        _lineCtrl.add(utf8.decode(_byteBuf, allowMalformed: true));
        _byteBuf.clear();
      } else {
        _byteBuf.add(byte);
      }
    }
  }

  void dispose() {
    _scanSub?.cancel();
    _dataSub?.cancel();
    _connSub?.cancel();
    _stateCtrl.close();
    _lineCtrl.close();
  }
}
