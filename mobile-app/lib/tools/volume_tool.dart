import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

/// Volume Tool — two-step execution.
/// LLM Call 1 (executePromptB): classify desired level using structured keywords
///   → returns one of: mute | low | medium | high | max | set:<0-15>
/// Native (executeNative): invokes set_volume channel with the resolved level.
/// LLM-free confirmResult for speed.
class VolumeTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  VolumeTool() : super('volume');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    // Fast regex pass first — avoids an LLM call for common patterns
    final lower = userMessage.toLowerCase();

    // Percent
    final pctMatch = RegExp(r'(\d+)\s*%').firstMatch(lower);
    if (pctMatch != null) {
      final pct = int.tryParse(pctMatch.group(1)!) ?? 50;
      return 'set:${(pct * 15 / 100).round().clamp(0, 15)}';
    }
    // Direct 0–15 digit
    final numMatch = RegExp(
      r'\bvolume\s+(?:to\s+)?(\d{1,2})\b',
    ).firstMatch(lower);
    if (numMatch != null) {
      final v = int.tryParse(numMatch.group(1)!) ?? 7;
      if (v <= 15) return 'set:$v';
    }
    if (RegExp(r'\b(mute|silent|silence|0)\b').hasMatch(lower)) return 'set:0';
    if (RegExp(r'\b(max|maximum|full|loud(?:est)?|100)\b').hasMatch(lower)) {
      return 'set:15';
    }
    if (RegExp(r'\b(low|quiet|soft|25)\b').hasMatch(lower)) return 'set:3';
    if (RegExp(r'\b(medium|mid|half|50)\b').hasMatch(lower)) return 'set:7';
    if (RegExp(r'\b(high|loud|75)\b').hasMatch(lower)) return 'set:12';

    // LLM Call 1: only if regex didn't match
    final raw = await modelService.generateOneShot(
      'You control Android volume (scale 0–15). '
          'Reply ONLY with one of: mute, low, medium, high, max, or set:<number 0-15>.\n'
          'Examples: "set volume to 5" → set:5 | "mute" → set:0 | "half volume" → set:7',
      'USER: "$userMessage"\nOUTPUT:',
      maxTokens: 10,
    );

    final clean = raw.trim().toLowerCase();
    if (clean.startsWith('set:')) {
      final lvl = int.tryParse(clean.substring(4));
      if (lvl != null) return 'set:${lvl.clamp(0, 15)}';
    }
    if (clean.contains('mute')) return 'set:0';
    if (clean.contains('low')) return 'set:3';
    if (clean.contains('medium') || clean.contains('mid')) return 'set:7';
    if (clean.contains('high')) return 'set:12';
    if (clean.contains('max') || clean.contains('full')) return 'set:15';
    return 'set:7'; // safe default
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    final clean = promptBOutput.trim().toLowerCase();
    int? level;

    if (clean.startsWith('set:')) {
      level = int.tryParse(clean.substring(4));
    } else if (clean.contains('mute') || clean == '0') {
      level = 0;
    } else if (clean.contains('max')) {
      level = 15;
    } else {
      level = int.tryParse(clean.replaceAll(RegExp(r'[^\d]'), ''));
    }

    if (level != null) {
      try {
        await _channel.invokeMethod('set_volume', {
          'level': level.clamp(0, 15),
        });
        return 'success:$level';
      } catch (e) {
        return 'failure:$e';
      }
    }
    return 'failure:unparseable';
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final levelStr = executionResult.split(':').last;
      final level = int.tryParse(levelStr) ?? 0;
      if (level == 0) return '🔇 Volume muted.';
      if (level <= 3) return '🔉 Volume set to low ($level/15).';
      if (level <= 8) return '🔉 Volume set to $level/15.';
      return '🔊 Volume set to $level/15.';
    }
    return 'Could not change the volume. Please try again.';
  }
}
