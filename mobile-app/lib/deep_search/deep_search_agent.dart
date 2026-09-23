import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/url_extractor_service.dart';
import '../utils/json_corrector.dart';
import 'deep_search_events.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CancelToken — lets callers abort mid-pipeline.
// ─────────────────────────────────────────────────────────────────────────────
class DeepSearchCancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

// ─────────────────────────────────────────────────────────────────────────────

class DeepSearchAgent {
  final ModelService _modelService;
  final SearchService _searchService;

  DeepSearchAgent(this._modelService, this._searchService);

  Stream<DeepSearchEvent> execute(
    String query, {
    DeepSearchCancelToken? cancel,
  }) async* {
    cancel ??= DeepSearchCancelToken();

    yield SearchPlanningEvent(query);

    // ── Phase 1A: Broad contextual search (First LLM Call) ───────────────────
    const contextSysPrompt =
        'You are a research agent. The user wants to know about this topic. '
        'Generate a single broad, exploratory search query to gather initial context. '
        'Output ONLY the query, no quotes or XML.';

    String broadQuery = query;
    try {
      final q = await _modelService.generateOneShot(
        contextSysPrompt,
        'USER TOPIC: "$query"\nEXPLORATORY QUERY:',
        maxTokens: 50,
        temperature: 0.2,
      );
      if (q.trim().isNotEmpty) broadQuery = q.trim();
    } catch (_) {}

    if (cancel.isCancelled) {
      yield SearchErrorEvent('Search cancelled by user.');
      return;
    }

    // Perform initial contextual search
    final initialResults = await _searchService.searchRaw(broadQuery);
    final contextString = initialResults.isEmpty
        ? "No initial context found."
        : initialResults
              .take(3)
              .map((r) => '${r.title}: ${r.snippet}')
              .join('\n');

    // ── Phase 1B: Generate dynamic N-step plan (Second LLM Call) ─────────────
    const planSysPrompt =
        'You are an expert deep research planner. Based on the User Query and Initial Context, '
        'break down the topic into a detailed sequence of search queries to thoroughly investigate it. '
        'Generate between 1 to 15 steps depending strictly on the complexity of the task. '
        'Output ONLY a valid JSON array of strings representing the search queries.\n'
        'Example: ["query 1", "query 2"]';

    final planPromptArgs =
        'USER QUERY: "$query"\nINITIAL CONTEXT: $contextString\nJSON ARRAY:';

    List<String> subQueries = [];
    String? breakdownRaw;
    try {
      breakdownRaw = await _modelService.generateOneShot(
        planSysPrompt,
        planPromptArgs,
        maxTokens: 300,
        temperature: 0.1,
      );

      final startIndex = breakdownRaw.indexOf('[');
      final endIndex = breakdownRaw.lastIndexOf(']');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        final rawSlice = breakdownRaw.substring(startIndex, endIndex + 1);
        final jsonStr = JsonCorrector.repair(rawSlice);
        final list = jsonDecode(jsonStr) as List;
        subQueries = list
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        // Fallback: If no brackets exist, extract quoted strings manually using Regex
        final matches = RegExp(r'"([^"]+)"').allMatches(breakdownRaw);
        if (matches.isNotEmpty) {
          subQueries = matches
              .map((m) => m.group(1)!.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      // If exact parse completely fails, fallback to regex
      final fallbackMatches = RegExp(
        r'"([^"]+)"',
      ).allMatches(breakdownRaw ?? '');
      subQueries = fallbackMatches
          .map((m) => m.group(1)!.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (subQueries.isEmpty) subQueries = [query];
    if (subQueries.length > 15) subQueries = subQueries.sublist(0, 15);

    yield SearchPlanReadyEvent(subQueries);

    // ── Phase 2: Dynamic Execution Loop (Search & Extract) ───────────────
    final buffer = StringBuffer();
    buffer.writeln('# Deep Search Report: "$query"');
    buffer.writeln('Date: ${DateTime.now().toLocal()}\n');

    for (int i = 0; i < subQueries.length; i++) {
      if (cancel.isCancelled) {
        yield SearchErrorEvent('Search cancelled by user.');
        return;
      }

      final currentQ = subQueries[i];
      yield StepStartedEvent(i + 1, subQueries.length, currentQ);

      try {
        final rawResults = await _searchService.searchRaw(currentQ);

        if (cancel.isCancelled) {
          yield SearchErrorEvent('Search cancelled by user.');
          return;
        }

        String fetchedDoc = '';
        String? topUrl;
        String? topTitle;

        if (rawResults.isNotEmpty) {
          final topHit = rawResults.first;
          topUrl = topHit.url;
          topTitle = topHit.title;

          if (topUrl.isNotEmpty) {
            final rawMd = await UrlExtractorService.instance.extractText(
              topUrl,
            );
            fetchedDoc = rawMd.length > 2000
                ? '${rawMd.substring(0, 2000)}...'
                : rawMd;
          }
        }

        final String searchDataStr;
        if (rawResults.isEmpty) {
          searchDataStr = 'No results found.';
        } else {
          final secondarySnippets = rawResults
              .skip(1)
              .take(4)
              .toList()
              .asMap()
              .entries
              .map(
                (e) =>
                    'Snippet [${e.key + 2}]: ${e.value.title}\n${e.value.snippet}',
              )
              .join('\n\n');

          if (fetchedDoc.trim().length < 50) {
            fetchedDoc =
                'Extract bypassed. Primary Snippet: ${rawResults.first.snippet}';
          }

          searchDataStr =
              'Source [1]: $topTitle\nContent:\n$fetchedDoc\n\nSecondary Results:\n$secondarySnippets';
        }

        final summarySys =
            'You are a precise research assistant. Summarize the following extracted website text '
            'and snippets for the query: "$currentQ". Be factual, concise, and highlight key insights.\n'
            'CRITICAL: You MUST use inline citations naturally in your sentences to attribute facts to their sources.';

        final summarized = await _modelService.generateOneShot(
          summarySys,
          searchDataStr,
          maxTokens: 350,
          temperature: 0.3,
        );

        if (cancel.isCancelled) {
          yield SearchErrorEvent('Search cancelled by user.');
          return;
        }

        final finalSummary = summarized.trim().isEmpty
            ? 'Analyzed the source, but no specific parsed summary was generated.'
            : summarized.trim();

        buffer.writeln('## ${i + 1}. $currentQ');
        buffer.writeln(finalSummary);
        if (rawResults.isNotEmpty) {
          buffer.writeln('\n**Sources:**');
          for (
            int srcIdx = 0;
            srcIdx < rawResults.length && srcIdx < 5;
            srcIdx++
          ) {
            final src = rawResults[srcIdx];
            if (src.url.isNotEmpty) {
              final domain =
                  Uri.tryParse(src.url)?.host.replaceFirst('www.', '') ??
                  src.url;
              buffer.writeln('- [[${srcIdx + 1}] $domain](${src.url})');
            }
          }
        }
        buffer.writeln('\n---\n');

        yield StepSuccessEvent(
          i + 1,
          finalSummary,
          url: topUrl,
          title: topTitle,
        );
      } catch (e) {
        buffer.writeln('## ${i + 1}. $currentQ');
        buffer.writeln('_Research step failed: ${e}_');
        buffer.writeln('\n---\n');
        yield StepFailedEvent(i + 1, e.toString());
      }
    }

    if (cancel.isCancelled) {
      yield SearchErrorEvent('Search cancelled by user.');
      return;
    }

    yield FinalizingReportEvent();

    // ── Phase 4: Save file ───────────────────────────────────────────────────
    try {
      const channel = MethodChannel('com.example.zero_air/tools');

      final sanitized = query
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .replaceAll(RegExp(r'_{2,}'), '_')
          .toLowerCase();
      final shortName = sanitized.length > 20
          ? sanitized.substring(0, 20)
          : sanitized;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'deep_search_${shortName}_$timestamp.md';

      final savedPath = await channel.invokeMethod<String>('save_document', {
        'filename': filename,
        'content': buffer.toString(),
      });

      if (savedPath != null && savedPath.isNotEmpty) {
        yield SearchCompleteEvent(savedPath);
      } else {
        yield SearchErrorEvent('Could not save file natively.');
      }
    } catch (e) {
      yield SearchErrorEvent('Error saving report: $e');
    }
  }
}
