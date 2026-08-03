enum HardwareCheckState { notRun, checking, passed, failed }

class SensorHardwareCheck {
  static const List<String> sensorKeys = [
    'fsr1',
    'fsr2',
    'fsr3',
    'fsr4',
    'fsr5',
    'fsr6',
  ];

  static List<String> missingSensors(Map<String, int> readings) {
    return sensorKeys.where((key) => !readings.containsKey(key)).toList();
  }

  static List<String> invalidSensors(Map<String, int> readings) {
    return sensorKeys.where((key) {
      final value = readings[key];
      return value != null && (value < 0 || value > 1023);
    }).toList();
  }

  static List<String> failedSensors(Map<String, int> readings) {
    final failed = <String>{
      ...missingSensors(readings),
      ...invalidSensors(readings),
    };
    return sensorKeys.where(failed.contains).toList();
  }

  static bool passes(Map<String, int> readings) {
    return failedSensors(readings).isEmpty;
  }
}
