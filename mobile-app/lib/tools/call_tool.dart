import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// Call Tool — extracts contact name → native channel searches device contacts and opens dialer.
class CallTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  CallTool() : super('call');

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
    String cleanContact = preExtractedParam?.trim() ?? '';

    // Fast regex extraction if not pre-extracted
    if (cleanContact.isEmpty) {
      final match = RegExp(
        r'\bcall\s+(.+)',
        caseSensitive: false,
      ).firstMatch(userMessage);
      if (match != null && match.group(1) != null) {
        cleanContact = match
            .group(1)!
            .replaceAll(RegExp(r'[.!?]+$'), '')
            .trim();
      }
    }

    // LLM fallback if regex result is empty or ambiguous
    if (cleanContact.isEmpty || cleanContact.split(' ').length > 4) {
      final extracted = await modelService.extractSingleField(
        fieldName:
            'exact contact name to call (reply ONLY with the name — no phone numbers)',
        toolName: 'make_call',
        userMessage: userMessage,
        maxTokens: 20,
      );
      cleanContact = extracted.trim().isEmpty ? userMessage : extracted.trim();
    }

    try {
      // Native side searches device contacts by name, then initiates the call / dials
      await _channel.invokeMethod('make_call', {'contact': cleanContact});
      return '📞 Calling $cleanContact…';
    } catch (e) {
      return 'Could not place call: $e';
    }
  }
}
