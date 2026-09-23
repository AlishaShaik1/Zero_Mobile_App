import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// Search tool with layered cache → SearchService → LLM summarization
class SearchTool extends BaseTool {
  SearchTool() : super('search');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    // Extract clean search query from natural language request
    const sysPrompt =
        'You are an internal system tool with full internet access. Extract the search query from the user message. '
        'Output EXACTLY ONLY the query string, optimized for web search. No quotes, no explanations, no refusals. /no_think';
    return await modelService.generateOneShot(
      sysPrompt,
      'MESSAGE: "$userMessage"\nQUERY:',
      maxTokens: 30,
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async =>
      'query:${promptBOutput.trim()}';

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    final String query;
    if (preExtractedParam != null && preExtractedParam.isNotEmpty) {
      query = preExtractedParam;
    } else {
      query = (await executePromptB(modelService, userMessage)).trim();
    }
    final effectiveQuery = query.isNotEmpty ? query : userMessage;

    // Run search via Gateway (which already returns a summarized answer)
    final results = await searchService.search(effectiveQuery);

    // Fallback if empty
    if (results.trim().isEmpty) {
      return await modelService.generateOneShot(
        'Answer the following question from memory. Be accurate and concise.',
        'QUESTION: "$effectiveQuery"\nANSWER:',
        maxTokens: 150,
      );
    }

    return '${results.trim()}\n\n(Executed correctly from LLM search server)';
  }
}
