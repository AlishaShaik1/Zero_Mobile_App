import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

class CalendarTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  CalendarTool() : super('calendar');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    // Two isolated extractions for title and time (better than one compound prompt for small LLM)
    final title = await modelService.extractSingleField(
      fieldName:
          'calendar event title (ONLY if user is creating/setting an event. If checking/viewing calendar, leave empty)',
      toolName: 'open_calendar',
      userMessage: userMessage,
      maxTokens: 25,
    );
    final time = await modelService.extractSingleField(
      fieldName:
          'event date and time (ONLY if creating/setting an event. Otherwise leave empty)',
      toolName: 'open_calendar',
      userMessage: userMessage,
      maxTokens: 25,
    );
    final cleanTitle = title.trim();
    final cleanTime = time.trim().isEmpty ? '' : time.trim();
    return '$cleanTitle||$cleanTime';
  }

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    // Use the router-provided title directly — no secondary LLM call needed.
    // The two-LLM extraction path (executePromptB) is preserved for complex cases
    // but calling it here caused a model re-entrant lock error.
    final title = preExtractedParam?.trim() ?? '';
    final promptBResult =
        '$title||'; // time field left empty — calendar opens to today
    final result = await executeNative(promptBResult);
    return confirmResult(userMessage, result);
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    final parts = promptBOutput.split('||');
    final title = parts.isNotEmpty ? parts[0].trim() : '';
    final time = parts.length > 1 ? parts[1].trim() : '';
    try {
      await _channel.invokeMethod('open_calendar', {
        'title': title,
        'time': time,
      });
      return 'success:$title';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final title = executionResult.substring('success:'.length);
      if (title.isEmpty) {
        return '📅 Opened calendar.';
      }
      return '📅 Opened calendar to create event: "$title".';
    }
    return 'Could not open the calendar.';
  }
}
