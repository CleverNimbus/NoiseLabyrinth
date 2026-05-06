/// Optional master output normalization settings.
class NormalizationConfig {
  const NormalizationConfig({
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
  final bool enabled;

  /// Target peak level in dBFS for normalization.
  final double targetDb;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'targetDb': targetDb,
    };
  }
}
