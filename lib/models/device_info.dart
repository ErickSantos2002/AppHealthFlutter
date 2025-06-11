class DeviceInfo {
  final int? battery;
  final int? usageCounter;
  final String? lastCalibrationDate;
  final double? testResult;
  final String? firmware;
  final int? temperature;

  DeviceInfo({
    this.battery,
    this.usageCounter,
    this.lastCalibrationDate,
    this.testResult,
    this.firmware,
    this.temperature,
  });

  DeviceInfo copyWith({
    int? battery,
    int? usageCounter,
    String? lastCalibrationDate,
    double? testResult,
    String? firmware,
    int? temperature,
  }) {
    return DeviceInfo(
      battery: battery ?? this.battery,
      usageCounter: usageCounter ?? this.usageCounter,
      lastCalibrationDate: lastCalibrationDate ?? this.lastCalibrationDate,
      testResult: testResult ?? this.testResult,
      firmware: firmware ?? this.firmware,
      temperature: temperature ?? this.temperature,
    );
  }
}
