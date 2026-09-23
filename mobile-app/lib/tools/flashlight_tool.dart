import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

class FlashlightTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  FlashlightTool() : super('flashlight');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    const sysPrompt =
        'The user wants to control the flashlight/torch. Reply ONLY with "ON" or "OFF".';
    return await modelService.generateOneShot(
      sysPrompt,
      'MESSAGE: "$userMessage"\nOUTPUT:',
      maxTokens: 5,
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    final state = promptBOutput.trim().toUpperCase().contains('OFF')
        ? 'off'
        : 'on';
    try {
      await _channel.invokeMethod('toggle_torch', {'state': state == 'on'});
      return 'success:$state';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final state = executionResult.split(':').last;
      return state == 'on'
          ? '🔦 Flashlight turned ON.'
          : '🔦 Flashlight turned OFF.';
    }
    return 'Could not toggle the flashlight.';
  }
}
