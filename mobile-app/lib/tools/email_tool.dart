import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// Email Tool — full LLM-closed-loop: extracts recipient + subject,
/// LLM writes professional body, opens native email composer.
class EmailTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  EmailTool() : super('email');

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
    // ── STEP 1: Extract recipient ────────────────────────────────────────────
    String to = preExtractedParam ?? '';
    if (to.trim().isEmpty) {
      to = await modelService.extractSingleField(
        fieldName:
            'recipient\'s name or email address — reply with ONLY the name or email, nothing else',
        toolName: 'send_email',
        userMessage: userMessage,
        maxTokens: 25,
      );
    }

    final cleanTo = to.trim();

    // Guard: if no recipient found, ask the user
    if (cleanTo.isEmpty ||
        cleanTo.toLowerCase() == 'unknown' ||
        cleanTo.toLowerCase() == 'none') {
      return '✉️ Who should I send this email to? Please tell me the recipient\'s name or email address.';
    }

    // ── STEP 2: Extract subject ──────────────────────────────────────────────
    final subject = await modelService.extractSingleField(
      fieldName: 'email subject line — one short phrase or sentence',
      toolName: 'send_email',
      userMessage: userMessage,
      maxTokens: 30,
    );

    // ── STEP 3: LLM writes the full professional email body ──────────────────
    final body = await modelService.generateOneShot(
      'You are a professional email writer. Write ONLY the email body text in this exact format:\n'
          'Dear [Name],\n\n'
          '[2-3 sentences of professional, polite, clear content based on the user request]\n\n'
          'Best regards,\n'
          '[Sender]\n\n'
          'Rules: No subject line. No "To:". No placeholder brackets in the final output.',
      'User request: "$userMessage"\n'
          'Recipient: "$cleanTo"\n\n'
          'WRITE THE PROFESSIONAL EMAIL BODY NOW:',
      maxTokens: 220,
    );

    final cleanSubject = subject.trim().isEmpty
        ? 'Message from Zero AI'
        : subject.trim();
    final cleanBody = body.trim().isEmpty ? userMessage : body.trim();

    // ── STEP 4: Open native email composer ──────────────────────────────────
    try {
      await _channel.invokeMethod('send_email', {
        'to': cleanTo,
        'subject': cleanSubject,
        'body': cleanBody,
      });
      return '✉️ Email ready for $cleanTo!\n'
          'Subject: "$cleanSubject"\n\n'
          'Body preview:\n$cleanBody\n\n'
          '→ Review in your email app and tap Send.';
    } catch (e) {
      return 'Could not open email app: $e\n\nDraft body:\n$cleanBody';
    }
  }
}
