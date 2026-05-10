/// Optional master output normalization settings.
class NormalizationConfig {
  NormalizationConfig({
    this.enabled = false,
    this.targetDb = -1.0,
  });

  factory NormalizationConfig.fromJson(Map<String, dynamic> json) {
    return NormalizationConfig(
      enabled: json['enabled'] as bool? ?? false,
      targetDb: (json['targetDb'] as num?)?.toDouble() ?? -1.0,
    );
  }

  /// Enables or disables master output normalization.
  bool enabled;

  /// Target peak level in dBFS for normalization.
  double targetDb;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'targetDb': targetDb,
    };
  }
}
