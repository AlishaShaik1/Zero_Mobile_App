import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../services/model_service.dart';

/// ── Browser UI Automator (Perception & HTTP Fallback) ────────────────────────
/// Handles parsing the screen state, element selection, vision gating, and HTTP
/// scraping when UI automation fails. Fully expanded to handle real-world edge cases.

class BrowserReader {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      },
    ),
  );

  Future<String> fallbackHttpScrape(
    ModelService model,
    String url,
    String goal,
  ) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      if (response.statusCode != 200) {
        return 'HTTP Error ${response.statusCode} - Could not load page.';
      }

      final rawHtml = response.data.toString();
      final strippedText = _stripHtml(rawHtml);

      // Cap at 8000 chars for LLM extraction to avoid context explosion
      final safeText = strippedText.length > 8000
          ? strippedText.substring(0, 8000)
          : strippedText;

      final summary = await model.generateOneShot(
        'Extract the exact information requested by the goal from this webpage text. If not there, say "Information not found".',
        'GOAL: $goal\nWEBPAGE TEXT: $safeText\n\nOUTPUT:',
        maxTokens: 250,
      );

      return summary;
    } catch (e) {
      debugPrint('[BrowserReader] HTTP scrape failed: $e');
      return 'HTTP scrape failed: $e';
    }
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class ElementCandidate {
  final String id;
  final String description;
  final bool isClickable;

  ElementCandidate({
    required this.id,
    required this.description,
    this.isClickable = true,
  });
}

class BrowserUIAutomator {
  static const List<String> screenArchetypes = [
    'loading',
    'search_results',
    'form_page',
    'content_page',
    'error_page',
    'login_wall',
    'captcha_page',
    'success_page',
    'unknown',
  ];

  Future<String> extractPageText(String compressedTree) async {
    // Quick heuristic to just extract text from tree for READ_PAGE action
    final lines = compressedTree.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      if (line.contains('text="')) {
        final match = RegExp(r'text="([^"]+)"').firstMatch(line);
        if (match != null) {
          buffer.writeln(match.group(1));
        }
      }
    }
    return buffer.toString();
  }

  Future<String> classifyScreen(ModelService model, String tree) async {
    const sys = 'Classify screen into one type. No explanation.';
    final prompt =
        'Types:loading,search_results,form_page,content_page,'
        'error_page,login_wall,captcha_page,success_page,unknown\n'
        'Screen:\n${tree.length > 600 ? tree.substring(0, 600) : tree}\n'
        'Type:';

    const grammar = r'''
root ::= "loading" | "search_results" | "form_page" | "content_page" | "error_page" | "login_wall" | "captcha_page" | "success_page" | "unknown"
''';

    final raw = await model.generateOneShot(
      sys,
      prompt,
      maxTokens: 15,
      temperature: 0.05,
      gbnfGrammar: grammar,
    );

    final type = raw.trim().split(RegExp(r'\s+')).first.toLowerCase();
    return screenArchetypes.contains(type) ? type : 'unknown';
  }

  List<ElementCandidate> parseCandidatesFromTree(String tree) {
    // Extract interactive elements from the tree
    final candidates = <ElementCandidate>[];
    final lines = tree.split('\n');
    for (final line in lines) {
      if (line.contains('resource-id="') ||
          (line.contains('class="') &&
              (line.contains('clickable="true"') ||
                  line.contains('focusable="true"')))) {
        final idMatch = RegExp(r'resource-id="([^"]+)"').firstMatch(line);
        final classMatch = RegExp(r'class="([^"]+)"').firstMatch(line);
        final textMatch = RegExp(r'text="([^"]+)"').firstMatch(line);
        final descMatch = RegExp(r'content-desc="([^"]+)"').firstMatch(line);

        final id = idMatch?.group(1) ?? 'node_${candidates.length}';
        final className = classMatch?.group(1) ?? 'node';
        final text = textMatch?.group(1) ?? '';
        final desc = descMatch?.group(1) ?? '';

        final description =
            '[${className.split('.').last}] ${text.isNotEmpty ? text : desc}';
        if (description.length > 3) {
          // Ignore empty or useless nodes
          candidates.add(ElementCandidate(id: id, description: description));
        }
      }
    }
    return candidates;
  }

  Future<String> selectElementAction(
    ModelService model,
    String goal,
    String tree,
    List<ElementCandidate> candidates,
  ) async {
    if (candidates.isEmpty) return '';

    // Build numbered list of candidates (max 8)
    final limited = candidates.take(8).toList();
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      buffer.writeln(
        '${i + 1}. ${limited[i].description} (id: ${limited[i].id})',
      );
    }

    const sys =
        'Pick the best element number for the goal. Reply with number only.';
    final prompt = 'Goal: $goal\nElements:\n${buffer.toString()}\nBest number:';

    final grammar = 'root ::= [1-${limited.length}]';

    final raw = await model.generateOneShot(
      sys,
      prompt,
      maxTokens: 5,
      temperature: 0.05,
      gbnfGrammar: grammar,
    );

    final number = int.tryParse(raw.trim().split(RegExp(r'\s+')).first) ?? 0;
    if (number >= 1 && number <= limited.length) {
      return limited[number - 1].id;
    }
    // Fallback: pick first clickable
    return limited
        .firstWhere((c) => c.isClickable, orElse: () => limited.first)
        .id;
  }
}

class BrowserVisionGate {
  int _visionCallsUsed = 0;
  static const int maxVisionCalls = 4; // Spec §9.2

  bool canCallVision() => _visionCallsUsed < maxVisionCalls;

  Future<String> callIfBudgetAllows(
    String imagePath,
    String purpose,
    ModelService model,
  ) async {
    if (!canCallVision()) {
      return 'vision_budget_exhausted';
    }
    if (!model.isMmprojReady) {
      return 'vision_not_loaded';
    }

    _visionCallsUsed++;

    final prompts = {
      'captcha': 'Is there a CAPTCHA? yes/no',
      'final_sanity': 'Does the result look complete, not an error? yes/no',
    };

    final prompt = prompts[purpose] ?? prompts['final_sanity']!;

    // We mock the vision call by sending chatWithImage logic, but as a one-shot equivalent.
    // In actual ModelService we might need to add generateVisionOneShot, but we can stream and collect it.
    final result = await _runVisionStream(model, prompt, imagePath);
    return result.trim().toLowerCase();
  }

  Future<String> _runVisionStream(
    ModelService model,
    String prompt,
    String imagePath,
  ) async {
    String out = '';
    await for (final delta in model.chatWithImage(prompt, imagePath)) {
      if (delta is ContentDelta) out += delta.text;
    }
    return out;
  }
}

/// Helper for perceptual diffs
class BrowserHashDiff {
  static bool screensStable(String treeA, String treeB) {
    // Instead of pixel diff, we diff the text of the trees for stability.
    if (treeA == treeB) return true;

    // Compute simple edit distance or length check for quick stability
    final lenA = treeA.length;
    final lenB = treeB.length;
    final diff = (lenA - lenB).abs();

    // If the trees are within 10 characters of each other, they are highly likely stable.
    if (diff < 10) return true;

    return false;
  }
}
