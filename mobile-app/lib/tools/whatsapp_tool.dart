import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// WhatsApp Tool — sends WhatsApp message with pre-filled text or LLM fallback.
class WhatsappTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  WhatsappTool() : super('whatsapp');

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
    // ── STEP 1: Extract contact name ────────────────────────────────────
    String contact = lastInjectedArgs?['contact_name']?.toString() ??
        lastInjectedArgs?['contact']?.toString() ??
        preExtractedParam ?? '';
    if (contact.trim().isEmpty) {
      contact = await modelService.extractSingleField(
        fieldName:
            'WhatsApp contact name to message — reply with ONLY the name, nothing else',
        toolName: 'send_whatsapp_message',
        userMessage: userMessage,
        maxTokens: 20,
      );
    }

    final cleanContact = contact.trim();

    // Guard: ask if contact is missing
    if (cleanContact.isEmpty ||
        cleanContact.toLowerCase() == 'unknown' ||
        cleanContact.toLowerCase() == 'none') {
      return '💬 Who should I send this WhatsApp message to? Please tell me the contact name.';
    }

    // ── STEP 2: Use message from injectedArgs or fallback to LLM ─────────────
    String? rawMsg = lastInjectedArgs?['message_body']?.toString() ??
        lastInjectedArgs?['message']?.toString();
    final String cleanMessage;
    if (rawMsg != null && rawMsg.trim().isNotEmpty) {
      cleanMessage = rawMsg.trim();
    } else {
      final crafted = await modelService.generateOneShot(
        'You are a WhatsApp messaging assistant. Write a natural, friendly, and professional '
            'WhatsApp message based on the user\'s request.\n'
            'Rules:\n'
            '- Write ONLY the message body text\n'
            '- No "Message:", no "To:", no greeting prefix from you\n'
            '- Keep it concise (1-4 sentences), warm, and to the point\n'
            '- Use appropriate emoji if it fits the tone',
        'User request: "$userMessage"\n'
            'Recipient: "$cleanContact"\n\n'
            'WRITE THE WHATSAPP MESSAGE NOW:',
        maxTokens: 120,
      );
      cleanMessage = crafted.trim().isEmpty ? userMessage : crafted.trim();
    }

    // ── STEP 3: Open WhatsApp with pre-filled message ──────────────────────
    try {
      final openResult = await _channel.invokeMethod<String>(
        'send_whatsapp_message',
        {'contact_name': cleanContact, 'message_body': cleanMessage},
      );

      if (openResult == 'not_installed') {
        return '❌ WhatsApp is not installed on this device.';
      }

      return '💬 WhatsApp opened for $cleanContact!\n\n'
          'Message preview:\n"$cleanMessage"\n\n'
          '→ Just tap Send in WhatsApp!';
    } catch (e) {
      return 'Could not open WhatsApp: $e\n\nMessage draft:\n$cleanMessage';
    }
  }
}
