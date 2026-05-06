import 'package:noiselabyrinth_core/models/enums.dart';

/// Optional master-stage dithering settings.
class DitherConfig {
  const DitherConfig({
    this.enabled = false,
    this.type = DitherType.tpdf,
    this.bitDepth = 16,
    this.amount = 1.0,
  });

  factory DitherConfig.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'tpdf';
    final type = DitherType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => DitherType.tpdf,
    );

    return DitherConfig(
      enabled: json['enabled'] as bool? ?? false,
      type: type,
      bitDepth: json['bitDepth'] as int? ?? 16,
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Enables or disables master dithering.
  final bool enabled;

  /// Dither algorithm selection.
  final DitherType type;

  /// Target quantization bit depth used to derive dither amplitude.
  final int bitDepth;

  /// Linear dither amount multiplier, where 1.0 equals 1 LSB TPDF.
  final double amount;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'type': type.name,
      'bitDepth': bitDepth,
      'amount': amount,
    };
  }
}
