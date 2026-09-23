class GenerationResult {
  final String code;
  final String finishReason;
  final dynamic usage;
  final bool truncated;
  final bool cached;

  GenerationResult({
    required this.code,
    required this.finishReason,
    this.usage,
    required this.truncated,
    this.cached = false,
  });

  factory GenerationResult.fromJson(Map<String, dynamic> json) {
    return GenerationResult(
      code: json['code'] ?? '',
      finishReason: json['finish_reason'] ?? 'unknown',
      usage: json['usage'],
      truncated: json['truncated'] ?? false,
      cached: json['cached'] ?? false,
    );
  }
}
