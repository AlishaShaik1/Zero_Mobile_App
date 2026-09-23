import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// Alarm Tool — two-step automated execution with relative date handling.
/// Step 1 (executePromptB): Grabs today's date/time, passes it to the LLM
///   which resolves relative expressions ("tomorrow", "in 30 mins") into
///   an absolute HH:MM|LABEL string.
/// Step 2 (executeNative): Parses the resolved time and sets the alarm
///   via the native channel.
class AlarmTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  AlarmTool() : super('alarm');

  static const List<String> _weekdays = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    // Step 1: capture today's real date/time to resolve relative expressions correctly
    final now = DateTime.now();
    final todayLabel = _weekdays[now.weekday];
    final currentH = now.hour.toString().padLeft(2, '0');
    final currentM = now.minute.toString().padLeft(2, '0');

    // Pre-calculate "+30 min" and "+1 hour" examples anchored to actual now
    final plus30 = now.add(const Duration(minutes: 30));
    final plus30H = plus30.hour.toString().padLeft(2, '0');
    final plus30M = plus30.minute.toString().padLeft(2, '0');

    final sysPrompt =
        'You extract the target absolute alarm time and label. Reply ONLY in format: HH:MM|LABEL (24-hour time).\n'
        'Current time: $currentH:$currentM on $todayLabel ${now.day}/${now.month}/${now.year}.\n'
        'Rules:\n'
        '- Use 24-hour format (e.g., 6:30 PM → 18:30).\n'
        '- "in X minutes/hours" → add to current time.\n'
        '- "tomorrow" means the next calendar day — just give the correct HH:MM (the system handles the day).\n'
        '- If no label given, use "Alarm".\n'
        'Examples:\n'
        '  "alarm at 7am"       → 07:00|Alarm\n'
        '  "wake me in 30 mins" → $plus30H:$plus30M|Wake up\n'
        '  "remind me at 9pm"   → 21:00|Reminder\n'
        '  "tomorrow 8am"       → 08:00|Alarm';

    return await modelService.generateOneShot(
      sysPrompt,
      'MESSAGE: "$userMessage"\nOUTPUT:',
      maxTokens: 25,
    );
  }

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    // First try to use the time from the router's JSON arg (e.g. "07:00")
    // Only bypass this if the param looks too sparse (no colon = not a time).
    String promptInput = preExtractedParam ?? '';

    // If the router gave us a bare HH:MM, build a fake message so executeNative can parse it.
    // If the user said something relative like "in 30 mins" or "tomorrow", the param will
    // be that text — we can pass it directly to executeNative's natural-language parser.
    // In any other case, fall back to the full user message.
    if (promptInput.trim().isEmpty) {
      promptInput = userMessage;
    }

    // Try the structured HH:MM|LABEL path first (fast, no LLM call)
    final structured = RegExp(
      r'^(\d{1,2}):(\d{2})',
    ).firstMatch(promptInput.trim());
    if (structured != null) {
      // Router gave us a valid HH:MM — use it directly
      final result = await executeNative(promptInput.trim());
      return confirmResult(userMessage, result);
    }

    // Try in-place fast regex on the user message before hitting the LLM
    final lower = userMessage.toLowerCase();
    final relMatch = RegExp(r'in\s+(\d+)\s*(min|hour|hr)').firstMatch(lower);
    final absMatch = RegExp(
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|a|p)\b',
    ).firstMatch(lower);
    if (relMatch != null || absMatch != null) {
      final result = await executeNative(lower);
      return confirmResult(userMessage, result);
    }

    // Only make a second LLM call as a last resort (e.g. "tomorrow at noon")
    final promptBResult = await executePromptB(modelService, userMessage);
    final result = await executeNative(promptBResult);
    return confirmResult(userMessage, result);
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    final clean = promptBOutput.trim().toLowerCase();
    int hour = 8;
    int minute = 0;
    String label = 'Alarm';

    // 1. Check if it's the structured format HH:MM|LABEL (from executePromptB)
    final structured = RegExp(
      r'^(\d{1,2}):(\d{2})\|?(.*)',
    ).firstMatch(promptBOutput.trim());
    if (structured != null) {
      hour = int.tryParse(structured.group(1)!) ?? 8;
      minute = int.tryParse(structured.group(2)!) ?? 0;
      label = structured.group(3)?.trim().isNotEmpty == true
          ? structured.group(3)!.trim()
          : 'Alarm';
    } else {
      // 2. Natural language parser fallback (for one-shot from agent_screen)
      // E.g. "tomorrow 7pm", "9:30 AM", "in 30 mins"

      final relMatch = RegExp(r'in\s+(\d+)\s*(min|hour|hr)').firstMatch(clean);
      if (relMatch != null) {
        final val = int.parse(relMatch.group(1)!);
        final isHour = relMatch.group(2)!.startsWith('h');
        final now = DateTime.now().add(
          Duration(minutes: isHour ? val * 60 : val),
        );
        hour = now.hour;
        minute = now.minute;
      } else {
        final timeMatch = RegExp(
          r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|a|p)?',
        ).firstMatch(clean);
        if (timeMatch != null) {
          int h = int.parse(timeMatch.group(1)!);
          final m = timeMatch.group(2) != null
              ? int.parse(timeMatch.group(2)!)
              : 0;
          final ampm = timeMatch.group(3);

          if (ampm != null) {
            if (ampm.startsWith('p') && h < 12) h += 12;
            if (ampm.startsWith('a') && h == 12) h = 0;
          }
          hour = h;
          minute = m;
        } else {
          return 'unparseable';
        }
      }
    }

    try {
      await _channel.invokeMethod('set_alarm', {
        'title': label,
        'hour': hour.clamp(0, 23),
        'minute': minute.clamp(0, 59),
      });
      return 'success:$hour:$minute:$label';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final parts = executionResult.split(':');
      final h = parts.length > 1 ? parts[1] : '?';
      final m = parts.length > 2 ? parts[2].padLeft(2, '0') : '00';
      final label = parts.length > 3 ? parts.skip(3).join(':') : 'Alarm';
      final hour = int.tryParse(h) ?? 0;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      final displayH = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '⏰ Alarm set for $displayH:$m $ampm — "$label"';
    }
    if (executionResult == 'unparseable') {
      return 'Could not figure out the time. Try: "Set alarm for 7 AM" or "Alarm at 6:30 PM".';
    }
    return 'Could not set the alarm. Please try again.';
  }
}
