import 'package:flutter/foundation.dart';
import 'model_service.dart';
import 'search_service.dart';

abstract class BaseTool {
  final String name;
  Map<String, dynamic>? lastInjectedArgs;

  BaseTool(this.name);

  Future<String> executePromptB(ModelService modelService, String userMessage);
  Future<String> executeNative(String promptBOutput);

  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success')) return 'Done ✓';
    if (executionResult.startsWith('failure')) return 'Something went wrong.';
    return 'Could not complete the request.';
  }

  // Expanded to take searchService so tools can run LoopRunner for UI Automation
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    debugPrint('[Tool:$name] Starting...');
    final promptBResult =
        preExtractedParam ?? await executePromptB(modelService, userMessage);
    debugPrint('[Tool:$name] PromptB → $promptBResult');
    final nativeResult = await executeNative(promptBResult);
    debugPrint('[Tool:$name] Native → $nativeResult');
    return confirmResult(userMessage, nativeResult);
  }
}

class ChainRunner {
  final ModelService _modelService;
  final SearchService _searchService;
  final Map<String, BaseTool> _tools;

  ChainRunner(this._modelService, this._searchService, List<BaseTool> tools)
    : _tools = {for (var t in tools) t.name: t};

  bool hasTool(String toolName) => _tools.containsKey(toolName);

  Future<String> executeTool(
    String toolName,
    String userMessage, {
    String? preExtractedParam,
    Map<String, dynamic>? injectedArgs,
  }) async {
    final tool = _tools[toolName];
    if (tool == null) {
      debugPrint(
        '[ChainRunner] Tool $toolName not found, falling through to chat.',
      );
      return _modelService.generateOneShot(
        'You are a helpful AI assistant.',
        userMessage,
      );
    }

    try {
      tool.lastInjectedArgs = injectedArgs;
      return await tool.execute(
        _modelService,
        _searchService,
        userMessage,
        preExtractedParam: preExtractedParam,
      );
    } catch (e) {
      debugPrint('[ChainRunner] $toolName failed: $e');
      return 'I encountered an issue with that tool. Please try again.';
    }
  }
}
