import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

class ClipboardTool extends BaseTool {
  ClipboardTool() : super('clipboard');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    const sysPrompt =
        'Extract the text to be copied to the clipboard. Reply ONLY with the text itself, nothing else.';
    return await modelService.generateOneShot(
      sysPrompt,
      'USER MESSAGE: "$userMessage"\nOUTPUT:',
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    try {
      await Clipboard.setData(ClipboardData(text: promptBOutput.trim()));
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
        'You are confirming a clipboard copy action. Output exactly one sentence.';
    String actionTaken;
    if (executionResult == 'success') {
      actionTaken = 'ACTION TAKEN: copied text to clipboard. RESULT: success';
    } else {
      actionTaken = 'ACTION TAKEN: attempted to copy text. RESULT: failure';
    }
    return await modelService.generateOneShot(
      sysPrompt,
      '$actionTaken\n\nOUTPUT (one sentence):',
    );
  }
}
