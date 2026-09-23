import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

class ShareTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  ShareTool() : super('share');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    const sysPrompt =
        'Extract the text to be shared. Reply ONLY with the text itself, nothing else.';
    return await modelService.generateOneShot(
      sysPrompt,
      'USER MESSAGE: "$userMessage"\nOUTPUT:',
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    try {
      await _channel.invokeMethod('share_text', {'text': promptBOutput.trim()});
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
        'You are confirming a share action. Output exactly one sentence.';
    String actionTaken;
    if (executionResult == 'success') {
      actionTaken =
          'ACTION TAKEN: opened the Android share sheet. RESULT: success';
    } else {
      actionTaken = 'ACTION TAKEN: attempted to share text. RESULT: failure';
    }
    return await modelService.generateOneShot(
      sysPrompt,
      '$actionTaken\n\nOUTPUT (one sentence):',
    );
  }
}
