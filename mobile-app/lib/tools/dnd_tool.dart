import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

class DndTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  DndTool() : super('dnd');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async => '';

  @override
  Future<String> executeNative(String promptBOutput) async => '';

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    const sysPrompt =
        'The user wants to change Do Not Disturb. Reply with ONLY one of: ON | OFF | PRIORITY | ALARMS_ONLY';
    final output = await modelService.generateOneShot(
      sysPrompt,
      'MESSAGE: "$userMessage"\nOUTPUT:',
      maxTokens: 10,
    );
    final clean = output.trim().toUpperCase();

    try {
      await _channel.invokeMethod('set_dnd', {'mode': clean.toLowerCase()});
      return '🔕 Do Not Disturb set to $clean.';
    } catch (e) {
      try {
        await _channel.invokeMethod('open_dnd_settings');
        return '🔕 Opened Do Not Disturb settings — please toggle to $clean manually.';
      } catch (err) {
        return 'Could not manage Do Not Disturb: $err';
      }
    }
  }
}
