import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

class ContactsTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  ContactsTool() : super('contacts');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    return 'open'; // Fixed vocabulary, no prompt needed for simple open
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    try {
      await _channel.invokeMethod('open_contacts');
      return 'success';
    } catch (e) {
      return 'failure';
    }
  }

  Future<String> executePromptC(
    ModelService modelService,
    String userMessage,
    String executionResult,
  ) async {
    const sysPrompt =
        'You are confirming a contacts action. Output exactly one sentence.';
    String actionTaken;
    if (executionResult == 'success') {
      actionTaken = 'ACTION TAKEN: opened the contacts app. RESULT: success';
    } else {
      actionTaken = 'ACTION TAKEN: attempted to open contacts. RESULT: failure';
    }
    return await modelService.generateOneShot(
      sysPrompt,
      '$actionTaken\n\nOUTPUT (one sentence):',
    );
  }
}
