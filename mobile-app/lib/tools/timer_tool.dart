import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

class TimerTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  TimerTool() : super('timer');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    const sysPrompt =
        'Extract the timer duration from the user message.\n'
        'Reply ONLY in format: <number> <unit> where unit is one of: seconds, minutes, hours.\n'
        'Examples: "5 minutes", "30 seconds", "2 hours"';
    return await modelService.generateOneShot(
      sysPrompt,
      'MESSAGE: "$userMessage"\nOUTPUT:',
      maxTokens: 15,
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    final raw = promptBOutput.trim().toLowerCase();
    int totalSeconds = 60; // default 1 minute

    final match = RegExp(
      r'(\d+)\s*(second|minute|hour|sec|min|hr)',
    ).firstMatch(raw);
    if (match != null) {
      final val = int.tryParse(match.group(1)!) ?? 1;
      final unit = match.group(2)!;
      if (unit.startsWith('sec')) {
        totalSeconds = val;
      } else if (unit.startsWith('min')) {
        totalSeconds = val * 60;
      } else if (unit.startsWith('hour') || unit == 'hr') {
        totalSeconds = val * 3600;
      }
    } else {
      final bare = RegExp(r'(\d+)').firstMatch(raw);
      if (bare != null) totalSeconds = (int.tryParse(bare.group(1)!) ?? 1) * 60;
    }

    try {
      final durationMinutes = (totalSeconds / 60).ceil().clamp(1, 999);
      // Pass both fields: Kotlin can use seconds for precision or minutes for the Clock app
      await _channel.invokeMethod('set_timer', {
        'duration_seconds': totalSeconds,
        'duration_minutes': durationMinutes,
      });
      return 'success:$totalSeconds';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final secs = int.tryParse(executionResult.split(':').last) ?? 0;
      String label;
      if (secs >= 3600) {
        final h = secs ~/ 3600;
        final m = (secs % 3600) ~/ 60;
        label = m > 0 ? '$h hr $m min' : '$h hour${h > 1 ? 's' : ''}';
      } else if (secs >= 60) {
        final m = secs ~/ 60;
        final s = secs % 60;
        label = s > 0 ? '$m min $s sec' : '$m minute${m > 1 ? 's' : ''}';
      } else {
        label = '$secs second${secs != 1 ? 's' : ''}';
      }
      return '⏱️ Timer set for $label.';
    }
    return 'Could not set the timer. Try: "Set a timer for 5 minutes".';
  }
}
