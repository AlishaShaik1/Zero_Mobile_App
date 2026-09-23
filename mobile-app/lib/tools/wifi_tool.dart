import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// WiFi Tool — opens Wi-Fi settings for the user to toggle.
class WifiTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  WifiTool() : super('wifi');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    const sysPrompt =
        'The user wants to control Wi-Fi. Reply ONLY with exactly one word: ON or OFF.';
    final raw = await modelService.generateOneShot(
      sysPrompt,
      'MESSAGE: "$userMessage"\nOUTPUT:',
      maxTokens: 5,
    );
    final clean = raw.trim().toUpperCase();
    return clean.contains('OFF') ? 'OFF' : 'ON';
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    final state = promptBOutput.trim().toUpperCase() == 'OFF' ? 'OFF' : 'ON';
    try {
      await _channel.invokeMethod('open_settings', {'setting': 'wifi'});
      return 'success:$state';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    final state =
        (await executePromptB(
              modelService,
              userMessage,
            )).trim().toUpperCase() ==
            'OFF'
        ? 'OFF'
        : 'ON';

    try {
      await _channel.invokeMethod('open_settings', {'setting': 'wifi'});
      return '📶 Opened Wi-Fi settings — please toggle to $state.';
    } catch (e) {
      return 'Could not open Wi-Fi settings: $e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final state = executionResult.split(':').last;
      return '📶 Wi-Fi turned $state.';
    }
    if (executionResult.startsWith('partial:')) {
      final parts = executionResult.split(':');
      return '📶 Opened Wi-Fi settings (${parts.length > 1 ? parts[1] : ''}), please finish manually.';
    }
    return 'Could not open Wi-Fi settings.';
  }
}
