import 'search_service.dart';
import 'memory_store.dart';

enum ToolType { agent, time, memoryRead, memoryWrite, search, none }

class ParsedTool {
  final ToolType type;
  final String arg;
  ParsedTool(this.type, this.arg);
}

class ToolDispatcher {
  /// Parses the raw direct output which contains XML-like tags, e.g. <tool name="search">query</tool>
  /// Parses ONLY explicit <tool name="...">arg</tool> XML from LLM output.
  /// No keyword fallbacks — those cause false positives on casual text.
  static ParsedTool parseDirectTool(String rawResponse, String userMessage) {
    final regex = RegExp(
      r'<tool\s+name="([^"]+)">([^<]*)</tool>',
      caseSensitive: false,
    );
    final match = regex.firstMatch(rawResponse);

    if (match == null) return ParsedTool(ToolType.none, '');

    final toolName = match.group(1)?.toLowerCase().trim() ?? '';
    final innerText = match.group(2)?.trim() ?? '';
    final arg = innerText.isNotEmpty ? innerText : userMessage;

    final type = switch (toolName) {
      'search' => ToolType.search,
      'memory_read' => ToolType.memoryRead,
      'memory_write' => ToolType.memoryWrite,
      'time' => ToolType.time,
      'agent' => ToolType.agent,
      _ => ToolType.none,
    };

    return ParsedTool(type, type == ToolType.none ? '' : arg);
  }

  static Future<String> execute(
    ParsedTool tool,
    SearchService searchService,
  ) async {
    try {
      switch (tool.type) {
        case ToolType.time:
          return RealTools.currentTime();
        case ToolType.memoryRead:
          return await RealTools.memoryRead(tool.arg);
        case ToolType.memoryWrite:
          return await RealTools.memoryWrite(tool.arg);
        case ToolType.search:
          return await RealTools.search(tool.arg, searchService);
        case ToolType.agent:
          return await RealTools.deviceAction(tool.arg);
        case ToolType.none:
          return tool.arg;
      }
    } catch (e) {
      return 'TOOL_FAILED: ${e.toString()}';
    }
  }
}

class RealTools {
  static String currentTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month]} ${now.year} — $h:$min ${now.timeZoneName}';
  }

  static Future<String> memoryRead(String key) async {
    final store = MemoryStore.instance;
    final val = store.buildMemoryBlock();
    if (val.trim().isEmpty) {
      return "I don't have any saved memories yet.";
    }
    return val;
  }

  static Future<String> memoryWrite(String kv) async {
    MemoryStore.instance.storeNote(kv);
    return 'Got it — saved to memory.';
  }

  static Future<String> search(
    String query,
    SearchService searchService,
  ) async {
    try {
      final resp = await searchService.search(query);
      return resp.toString();
    } catch (e) {
      return 'TOOL_FAILED: search error $e';
    }
  }

  static Future<String> deviceAction(String task) async {
    // Routed to agent pipeline — returning trigger signal for now
    return 'AGENT_TRIGGERED: $task';
  }
}
