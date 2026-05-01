class BandConfig {
  final int low;
  final int high;

  const BandConfig({this.low = 20, this.high = 20000});

  factory BandConfig.fromJson(Map<String, dynamic> json) {
    return BandConfig(
      low: json['low'] as int? ?? 20,
      high: json['high'] as int? ?? 20000,
    );
  }

  Map<String, dynamic> toJson() {
    return {'low': low, 'high': high};
  }
}
