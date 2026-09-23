import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// Recording Tool — start or stop audio recording via native channel.
class RecordingTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  RecordingTool() : super('recording');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    // Fast regex — no LLM call needed for start/stop classification
    final lower = userMessage.toLowerCase();
    final isStop = RegExp(
      r'\b(stop|end|finish|done|pause|halt)\b',
    ).hasMatch(lower);
    return isStop ? 'STOP' : 'START';
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    final action = promptBOutput.trim().toUpperCase() == 'STOP'
        ? 'stop_recording'
        : 'start_recording';
    try {
      final result = await _channel.invokeMethod<String>(action);
      return 'success:${promptBOutput.trim().toUpperCase()}:${result ?? ''}';
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
    final String action;
    if (preExtractedParam != null && preExtractedParam.isNotEmpty) {
      action = preExtractedParam;
    } else {
      action = await executePromptB(modelService, userMessage);
    }
    final result = await executeNative(action);
    return confirmResult(userMessage, result);
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:STOP')) {
      final parts = executionResult.split(':');
      final path = parts.length > 2 ? parts.sublist(2).join(':') : '';
      return path.isNotEmpty
          ? '🎙️ Recording saved to: $path'
          : '🎙️ Recording stopped and saved.';
    }
    if (executionResult.startsWith('success:START')) {
      return '🎙️ Recording started.';
    }
    return 'Could not start/stop recording. Please check microphone permission.';
  }
}
