// memory_tool.dart — Save and retrieve facts from MemoryStore
// Save:    LLM returns  memory=<note>
// Retrieve: LLM returns memory?=<query>
// This file is used by ToolExecutorService and PipelineService.

import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/memory_store.dart';
import '../services/chain_runner.dart';

class MemoryTool extends BaseTool {
  MemoryTool() : super('memory');

  // Step B: Summarise if long, otherwise clean the note
  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    if (userMessage.length <= 120) return userMessage.trim();
    // Long message → summarise to one concise fact
    return await modelService.generateOneShot(
      'Extract and summarize the key fact to save in one short sentence. Output ONLY the fact.',
      userMessage,
      maxTokens: 60,
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    if (promptBOutput.trim().isEmpty) return 'Nothing to save.';
    await MemoryStore.instance.storeNote(promptBOutput.trim());
    return '✓ Saved: "${promptBOutput.trim()}"';
  }

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    final String note;
    if (preExtractedParam != null && preExtractedParam.isNotEmpty) {
      note = preExtractedParam;
    } else {
      note = await executePromptB(modelService, userMessage);
    }
    return await executeNative(note);
  }
}
