/// Frequency band limits used for band-limited noise generation.
class BandConfig {
  BandConfig({this.low = 20, this.high = 20000});

  factory BandConfig.fromJson(Map<String, dynamic> json) {
    return BandConfig(
      low: json['low'] as int? ?? 20,
      high: json['high'] as int? ?? 20000,
    );
  }

  /// Lower frequency bound in Hz.
  int low;

  /// Upper frequency bound in Hz.
  int high;

  Map<String, dynamic> toJson() {
    return {'low': low, 'high': high};
  }
}
