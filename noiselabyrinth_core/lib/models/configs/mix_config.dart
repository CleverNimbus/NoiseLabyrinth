class MixConfig {
  final double mix;

  const MixConfig({this.mix = 1.0});

  factory MixConfig.fromJson(Map<String, dynamic> json) {
    return MixConfig(mix: (json['mix'] as num?)?.toDouble() ?? 1.0);
  }

  Map<String, dynamic> toJson() {
    return {'mix': mix};
  }
}
