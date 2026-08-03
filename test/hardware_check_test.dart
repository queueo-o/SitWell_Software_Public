import 'package:flutter_test/flutter_test.dart';
import 'package:poschair_check/models/hardware_check.dart';

void main() {
  group('SensorHardwareCheck', () {
    test('passes when all six sensors report valid ADC readings', () {
      final readings = {
        'fsr1': 0,
        'fsr2': 125,
        'fsr3': 300,
        'fsr4': 512,
        'fsr5': 900,
        'fsr6': 1023,
      };

      expect(SensorHardwareCheck.passes(readings), isTrue);
      expect(SensorHardwareCheck.missingSensors(readings), isEmpty);
      expect(SensorHardwareCheck.invalidSensors(readings), isEmpty);
    });

    test('reports a sensor that did not respond', () {
      final readings = {
        'fsr1': 100,
        'fsr2': 200,
        'fsr3': 300,
        'fsr4': 400,
        'fsr5': 500,
      };

      expect(SensorHardwareCheck.passes(readings), isFalse);
      expect(SensorHardwareCheck.missingSensors(readings), ['fsr6']);
      expect(SensorHardwareCheck.failedSensors(readings), ['fsr6']);
    });

    test('reports every sensor when more than one stops responding', () {
      final readings = {'fsr1': 100, 'fsr3': 300, 'fsr5': 500, 'fsr6': 600};

      expect(SensorHardwareCheck.passes(readings), isFalse);
      expect(SensorHardwareCheck.failedSensors(readings), ['fsr2', 'fsr4']);
    });

    test('rejects readings outside the 10-bit ADC range', () {
      final readings = {
        'fsr1': 100,
        'fsr2': 200,
        'fsr3': 300,
        'fsr4': 400,
        'fsr5': 500,
        'fsr6': 1024,
      };

      expect(SensorHardwareCheck.passes(readings), isFalse);
      expect(SensorHardwareCheck.invalidSensors(readings), ['fsr6']);
    });
  });
}
