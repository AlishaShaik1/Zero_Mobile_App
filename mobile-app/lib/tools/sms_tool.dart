import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// SMS Tool — two LLM calls, no UI automation.
/// LLM Call 1a: extract recipient name.
/// LLM Call 1b: write a concise professional SMS body.
/// Native: send_sms channel (SmsManager) — returns true if sent silently.
/// LLM Call 2 (confirmResult): confirmation sentence.
class SmsTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  SmsTool() : super('sms');

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
    // LLM Call 1a: extract recipient
    String contact = preExtractedParam ?? '';
    if (contact.trim().isEmpty) {
      contact = await modelService.extractSingleField(
        fieldName:
            'recipient name or phone number (reply ONLY with the name/number)',
        toolName: 'send_sms',
        userMessage: userMessage,
        maxTokens: 20,
      );
    }

    final cleanContact = contact.trim().isEmpty ? 'unknown' : contact.trim();

    // LLM Call 1b: write professional short SMS body
    final body = await modelService.generateOneShot(
      'You are a concise SMS assistant. Write ONLY the SMS message body — '
          'no greeting prefix, no "Message:", just the text. '
          'Keep it under 160 characters. Be natural and friendly.',
      'Write an SMS message based on: "$userMessage"\nSMS:',
      maxTokens: 60,
    );

    final cleanBody = body.trim().isEmpty ? userMessage : body.trim();

    // Native: send via SmsManager
    try {
      final sentSilently = await _channel.invokeMethod<bool>('send_sms', {
        'contact': cleanContact,
        'message': cleanBody,
      });

      if (sentSilently == true) {
        return '💬 SMS sent to $cleanContact.';
      }
      // Composer opened — user taps Send
      return '💬 SMS composer opened for $cleanContact. Please tap Send.';
    } catch (e) {
      return 'Could not send SMS: $e';
    }
  }
}
