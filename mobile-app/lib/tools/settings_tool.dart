import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

class SettingsTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  SettingsTool() : super('settings');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    const sysPrompt =
        'Extract the settings category the user wants to open. Reply ONLY with the category name (e.g. wifi, bluetooth, display, sound), nothing else.';
    return await modelService.generateOneShot(
      sysPrompt,
      'USER MESSAGE: "$userMessage"\nOUTPUT:',
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    try {
      await _channel.invokeMethod('open_settings', {
        'setting': promptBOutput.trim(),
      });
      return 'success';
    } catch (e) {
      return 'failure';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult == 'success') {
      return '⚙️ Settings page opened.';
    }
    return 'Could not open settings.';
  }
}
