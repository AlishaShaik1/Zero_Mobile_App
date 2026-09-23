/// ── Browser Agent Configuration & Action Models ────────────────────────────
/// Shared constants, action types, and parsing logic used across the browser
/// agent subsystem. Centralised here to avoid duplication and ensure consistency.
library browser_config;

/// Every action the LLM can output maps to exactly one of these.
enum BrowserAction {
  tap,
  type,
  scroll,
  back,
  readPage,
  askUserSignin,
  done,
  fail,
  unknown,
}

/// Parsed result of an LLM action string.
class ParsedAction {
  final BrowserAction action;
  final String id; // node id for TAP / TYPE
  final String text; // text payload for TYPE
  final String direction; // up/down for SCROLL

  const ParsedAction({
    required this.action,
    this.id = '',
    this.text = '',
    this.direction = 'down',
  });

  @override
  String toString() =>
      'ParsedAction($action, id=$id, text=$text, dir=$direction)';
}

/// Parse raw LLM output into a structured ParsedAction.
/// Handles noisy outputs gracefully — takes first line, strips quotes, etc.
ParsedAction parseActionString(String raw) {
  // Take only the first non-empty line (LLM sometimes adds explanations)
  final firstLine = raw
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => 'FAIL');

  final clean = firstLine.replaceAll('"', '').replaceAll("'", '').trim();

  // Terminal states
  if (clean == 'DONE') return const ParsedAction(action: BrowserAction.done);
  if (clean == 'FAIL') return const ParsedAction(action: BrowserAction.fail);
  if (clean == 'BACK') return const ParsedAction(action: BrowserAction.back);
  if (clean == 'READ_PAGE') {
    return const ParsedAction(action: BrowserAction.readPage);
  }
  if (clean == 'ASK_USER_SIGNIN') {
    return const ParsedAction(action: BrowserAction.askUserSignin);
  }

  // TAP:<id>
  if (clean.startsWith('TAP:')) {
    final id = clean.substring(4).trim();
    if (id.isNotEmpty) return ParsedAction(action: BrowserAction.tap, id: id);
  }

  // SCROLL:<up/down>
  if (clean.startsWith('SCROLL:')) {
    final dir = clean.substring(7).trim().toLowerCase();
    return ParsedAction(
      action: BrowserAction.scroll,
      direction: dir == 'up' ? 'up' : 'down',
    );
  }

  // TYPE:<id>:<text>  — find the SECOND colon to split id from text
  if (clean.startsWith('TYPE:')) {
    final afterType = clean.substring(5);
    final colonIdx = afterType.indexOf(':');
    if (colonIdx > 0) {
      final id = afterType.substring(0, colonIdx).trim();
      final text = afterType.substring(colonIdx + 1).trim();
      if (id.isNotEmpty && text.isNotEmpty) {
        return ParsedAction(action: BrowserAction.type, id: id, text: text);
      }
    }
  }

  return const ParsedAction(action: BrowserAction.unknown);
}

/// Agent tuning constants.
class BrowserConst {
  BrowserConst._();

  static const int maxSteps = 18;
  static const Duration hardDeadline = Duration(seconds: 150);
  static const int maxEmptyTreeRetries = 3;
  static const int stallThreshold = 3;
  static const int maxTokensAction = 40;
  static const int maxTokensPlan = 120;
  static const int maxTokensExtract = 250;

  // Delays after each action type (let Chrome render)
  static const Duration delayAfterTap = Duration(seconds: 3);
  static const Duration delayAfterType = Duration(seconds: 4);
  static const Duration delayAfterScroll = Duration(seconds: 2);
  static const Duration delayAfterBack = Duration(seconds: 2);
  static const Duration delayAfterLaunch = Duration(seconds: 5);
  static const Duration delayEmptyTreeRetry = Duration(seconds: 2);
}
