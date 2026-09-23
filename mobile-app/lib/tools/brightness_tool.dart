import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

class BrightnessTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  BrightnessTool() : super('brightness');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    // Few-shot prompt that works reliably on tiny models
    const sysPrompt =
        'Extract screen brightness level as 0-255 integer.\n'
        'Rules: 0%=0, 25%=64, 50%=128, 75%=192, 100%=255.\n'
        'Keywords: "off" or "dark"=0, "dim" or "low"=64, "half" or "medium"=128, "high" or "bright"=192, "max", "full", or "100%"=255.\n'
        'Reply ONLY with an integer from 0 to 255, nothing else.\n'
        'Examples:\n'
        '  "50%" -> 128\n'
        '  "set brightness to max" -> 255\n'
        '  "full brightness" -> 255\n'
        '  "dim the screen" -> 64\n'
        '  "75% brightness" -> 192';
    return await modelService.generateOneShot(
      sysPrompt,
      'MESSAGE: "$userMessage"\nINTEGER:',
      maxTokens: 6,
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    // Parse a clean integer from the LLM output
    final match = RegExp(r'\b(\d{1,3})\b').firstMatch(promptBOutput.trim());
    if (match == null) return 'failure:unparseable';
    final level = (int.tryParse(match.group(1)!) ?? 128).clamp(0, 255);
    try {
      await _channel.invokeMethod('set_brightness', {'level': level});
      return 'success:$level';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final level = int.tryParse(executionResult.split(':').last) ?? 128;
      final pct = (level / 255 * 100).round();
      return '☀️ Brightness set to $pct%.';
    }
    if (executionResult == 'failure:unparseable') {
      return 'Could not figure out the brightness level. Try: "Set brightness to 70%" or "Dim the screen".';
    }
    return 'Could not change brightness. Make sure the app has the WRITE_SETTINGS permission.';
  }
}
