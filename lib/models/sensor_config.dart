class SensorConfig {
  final String key;
  final String hardwareType;
  String displayName;
  bool isActive;

  SensorConfig({
    required this.key,
    required this.hardwareType,
    required this.displayName,
    this.isActive = true,
  });

  static List<SensorConfig> defaults() => [
        // Backrest: 2 circle FSRs (L/R shoulders) + 1 velostat (center, larger)
        SensorConfig(key: 'fsr1', hardwareType: 'circle',   displayName: 'S1_UPPER'),
        SensorConfig(key: 'fsr2', hardwareType: 'circle',   displayName: 'S2_UPPER'),
        SensorConfig(key: 'fsr3', hardwareType: 'velostat', displayName: 'S3_UPPER'),
        // Seat: 2 circle FSRs (L/R) + 1 velostat (front-center, larger)
        SensorConfig(key: 'fsr4', hardwareType: 'circle',   displayName: 'S1_LOWER'),
        SensorConfig(key: 'fsr5', hardwareType: 'circle',   displayName: 'S2_LOWER'),
        SensorConfig(key: 'fsr6', hardwareType: 'velostat', displayName: 'S3_LOWER'),
      ];

  // Deviation threshold from hardware code (code.py DEVIATION map)
  double get deviationThreshold => switch (hardwareType) {
        'circle'   => 0.50,
        'square'   => 0.60,
        'velostat' => 0.10,
        _          => 0.25,
      };

  // Pressure labels from hardware code (code.py *_THRESHOLDS)
  String pressureLabel(int reading) => switch (hardwareType) {
        'circle'   => _circleLabel(reading),
        'square'   => _squareLabel(reading),
        'velostat' => _velostatLabel(reading),
        _          => '—',
      };

  // Normalize reading to 0.0–1.0 for bar visualization (10-bit ADC range)
  double pressureNorm(int reading) => (reading / 1023.0).clamp(0.0, 1.0);

  static String _circleLabel(int r) {
    if (r < 15)  return 'No contact';
    if (r < 50)  return 'Very light';
    if (r < 150) return 'Light';
    if (r < 250) return 'Moderate';
    if (r < 350) return 'Firm';
    return 'Heavy';
  }

  static String _squareLabel(int r) {
    if (r < 350) return 'No contact';
    if (r < 450) return 'Light';
    if (r < 700) return 'Moderate';
    if (r < 800) return 'Firm';
    if (r < 900) return 'High';
    return 'Max load';
  }

  static String _velostatLabel(int r) {
    if (r < 650) return 'No pressure';
    if (r < 750) return 'Below normal';
    if (r < 850) return 'Normal posture';
    return 'Excess pressure';
  }
}
