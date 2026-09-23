// datetime_tool.dart — Instant on-device date/time response.
// The LLM emits "datetime=" → chat screen calls getFormatted() → zero extra inference.

import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

class DateTimeTool extends BaseTool {
  DateTimeTool() : super('datetime');

  /// Returns a fully formatted date/time string instantly from the system clock.
  static String getFormatted({bool timeOnly = false, bool dateOnly = false}) {
    final now = DateTime.now();
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final hour12 = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');

    if (timeOnly) return '$hour12:$minute $ampm';
    if (dateOnly) return '$weekday, $month ${now.day}, ${now.year}';
    return '$weekday, $month ${now.day}, ${now.year} — $hour12:$minute $ampm';
  }

  /// Detects what the user is asking for: time, date, or both.
  static String resolve(String query) {
    final q = query.toLowerCase();
    final wantsTime = RegExp(r'\b(time|clock|hour|minute|pm|am)\b').hasMatch(q);
    final wantsDate = RegExp(
      r'\b(date|day|today|tomorrow|week|month|year|calendar)\b',
    ).hasMatch(q);
    if (wantsTime && !wantsDate) return getFormatted(timeOnly: true);
    if (wantsDate && !wantsTime) return getFormatted(dateOnly: true);
    return getFormatted(); // both
  }

  @override
  Future<String> executePromptB(ModelService _, String userMessage) async =>
      resolve(userMessage);

  @override
  Future<String> executeNative(String promptBOutput) async => promptBOutput;

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async => resolve(userMessage);
}
