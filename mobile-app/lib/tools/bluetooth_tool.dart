import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// Bluetooth Tool — direct native toggle, settings fallback.
class BluetoothTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  BluetoothTool() : super('bluetooth');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    const sysPrompt =
        'The user wants to control Bluetooth. Reply ONLY with exactly one word: ON or OFF.';
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
    final state = promptBOutput.trim().toUpperCase() == 'OFF' ? 'off' : 'on';
    try {
      await _channel.invokeMethod('set_bluetooth', {'state': state});
      return 'success:${state.toUpperCase()}';
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
    final raw = await executePromptB(modelService, userMessage);
    final state = raw.trim().toUpperCase() == 'OFF' ? 'OFF' : 'ON';

    // Try direct native toggle first
    try {
      await _channel.invokeMethod('set_bluetooth', {
        'state': state.toLowerCase(),
      });
      return '🔵 Bluetooth turned $state.';
    } catch (_) {}

    // Fallback: open settings
    try {
      await _channel.invokeMethod('open_settings', {'setting': 'bluetooth'});
      return '🔵 Opened Bluetooth settings — please toggle to $state.';
    } catch (e) {
      return 'Could not manage Bluetooth: $e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final state = executionResult.split(':').last;
      return '🔵 Bluetooth turned $state.';
    }
    return 'Could not toggle Bluetooth.';
  }
}
