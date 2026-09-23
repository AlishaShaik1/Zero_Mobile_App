import 'model_service.dart';
import 'search_service.dart';
import 'memory_store.dart';
import '../tools/memory_tool.dart';

enum RouteKind { search, memorySave, memoryRecall, datetime, chat }

class RouteResult {
  final RouteKind kind;

  /// Ephemeral block to prepend to the user's message before the visible
  /// chat generation call, e.g. "[SEARCH RESULT: ...]\n\n". Null for chat.
  final String? promptContext;

  /// For memorySave, a ready-made confirmation the caller MAY show
  /// immediately without waiting on the model (optional fast path).
  final String? fastPathReply;

  const RouteResult({
    required this.kind,
    this.promptContext,
    this.fastPathReply,
  });
}

class ChatToolRouterService {
  final ModelService modelService;
  final SearchService searchService;
  final MemoryTool _memoryTool = MemoryTool();

  ChatToolRouterService({
    required this.modelService,
    required this.searchService,
  });

  static final RegExp _timePattern = RegExp(
    r"what(?:'s| is)?\s+(?:the\s+)?(?:current\s+)?time\b|what time (?:is it|do you have)",
    caseSensitive: false,
  );
  static final RegExp _datePattern = RegExp(
    r"what(?:'s| is)?\s+(?:the\s+)?(?:current\s+)?date\b|what day is it|today'?s date|what is today",
    caseSensitive: false,
  );

  /// Cheap, fast, allowed to be wrong. Never trusted on its own — see
  /// `route()`. Its only job is to give the classifier a head start.
  String? _regexHint(String userMessage) {
    if (MemoryStore.isMemoryRequest(userMessage)) return 'MEMORY_SAVE';
    if (_timePattern.hasMatch(userMessage) &&
        _datePattern.hasMatch(userMessage)) {
      return 'DATETIME=both';
    }
    if (_timePattern.hasMatch(userMessage)) return 'DATETIME=time';
    if (_datePattern.hasMatch(userMessage)) return 'DATETIME=date';
    return null;
  }

  String _formatDateTime(String mode) {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
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
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    switch (mode) {
      case 'time':
        return '[TIME: $hour:$minute $ampm]\n\n';
      case 'date':
        return '[DATE: $weekday, $month ${now.day}, ${now.year}]\n\n';
      default:
        return '[TIME: $weekday, $month ${now.day}, ${now.year} \u2013 $hour:$minute $ampm]\n\n';
    }
  }

  /// Regex hint feeds INTO the classifier call as extra context — it never
  /// bypasses it. If the hint is wrong, the model still sees the raw
  /// message and can pick something else; you just paid for one call
  /// either way, so there's no accuracy trade-off for doing it this way.
  Future<RouteResult?> route(String userMessage) async {
    final hint = _regexHint(userMessage);
    if (hint == null) return null;

    if (hint == 'MEMORY_SAVE') {
      final confirmation = await _memoryTool.execute(
        modelService,
        searchService,
        userMessage,
      );
      return RouteResult(
        kind: RouteKind.memorySave,
        promptContext: '[MEMORY SAVED: $confirmation]\n\n',
        fastPathReply: confirmation,
      );
    }

    if (hint == 'MEMORY_RECALL') {
      final block = MemoryStore.instance.buildMemoryBlock();
      if (block.trim().isEmpty) {
        return const RouteResult(
          kind: RouteKind.memoryRecall,
          promptContext: '[MEMORY: nothing relevant is saved yet]\n\n',
        );
      }
      return RouteResult(
        kind: RouteKind.memoryRecall,
        promptContext: '[MEMORY:$block]\n\n',
      );
    }

    if (hint.startsWith('DATETIME=')) {
      final value = hint.split('=')[1];
      return RouteResult(
        kind: RouteKind.datetime,
        promptContext: _formatDateTime(value),
      );
    }

    return null;
  }
}
