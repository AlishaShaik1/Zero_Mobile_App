import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// Airplane Mode Tool — two-step execution via native channel.
class AirplaneModeTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  AirplaneModeTool() : super('airplane_mode');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    const sysPrompt =
        'The user wants to control Airplane Mode. Reply ONLY with exactly one word: ON or OFF.';
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
    return 'pending:${promptBOutput.trim().toUpperCase()}';
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

    try {
      await _channel.invokeMethod('open_settings', {'setting': 'airplane'});
      return '✈️ Opened Airplane Mode settings — please toggle to $state.';
    } catch (e) {
      return 'Could not open Airplane Mode settings: $e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final state = executionResult.split(':').last;
      return '✈️ Airplane Mode turned $state.';
    }
    return 'Could not toggle Airplane Mode.';
  }
}
