import '../../services/model_service.dart';

/// -- Browser Intent & Router --------------------------------------------------
/// Handles extracting the URL and goal from a free-text message, and includes
/// the deterministic WebsiteAppRouter gate as specified in §12.

class BrowserIntent {
  final String url;
  final String goal;
  const BrowserIntent({required this.url, required this.goal});
}

class InfoCheck {
  final bool enough;
  final List<String> missing;
  const InfoCheck({required this.enough, required this.missing});
}

class WebsiteAppRouter {
  static bool isCreateSiteOrAppIntent(String msg) {
    final m = msg.toLowerCase();
    return RegExp(r'\b(create|build|make|generate)\b').hasMatch(m) &&
        RegExp(
          r'\b(website|web ?app|app|landing page|site|webapp)\b',
        ).hasMatch(m);
  }

  static InfoCheck checkEnoughInfo(String msg) {
    final m = msg.toLowerCase();
    final hasPurpose =
        RegExp(r'\b(for my|portfolio|store|shop|blog|app for)\b').hasMatch(m) ||
        m.split(' ').length > 8;
    final hasStyleOrPlatform = RegExp(
      r'\b(v0|bolt|react|next|backend|database|login|auth)\b',
    ).hasMatch(m);

    return InfoCheck(
      enough: hasPurpose && hasStyleOrPlatform,
      missing: [
        if (!hasPurpose) 'purpose',
        if (!hasStyleOrPlatform) 'style_or_platform',
      ],
    );
  }
}

class BrowserIntentExtractor {
  Future<BrowserIntent> extract(ModelService model, String msg) async {
    const sys = 'Extract URL and goal. Format: URL:...|GOAL:...';
    const tpl = 'MSG:"MSG_HERE"|URL:|GOAL:';

    // GBNF grammar to enforce pipe-delimited output
    const grammar = r'''
root ::= "URL:" url "|GOAL:" goal
url  ::= [^|\n]*
goal ::= [^\n]*
''';

    final raw = await model.generateOneShot(
      sys,
      tpl.replaceAll('MSG_HERE', msg.replaceAll('|', ' ')),
      maxTokens: 40,
      temperature: 0.05,
      gbnfGrammar: grammar,
    );

    final urlMatch = RegExp(r'URL:([^|]+)').firstMatch(raw);
    final goalMatch = RegExp(r'GOAL:([^|]+)').firstMatch(raw);

    String url = urlMatch?.group(1)?.trim() ?? '';
    String goal = goalMatch?.group(1)?.trim() ?? msg;

    if (url.isEmpty) {
      url = _inferUrlFromGoal(goal);
    }

    if (!url.startsWith('http')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://';
      } else {
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }

    return BrowserIntent(url: url, goal: goal);
  }

  String _inferUrlFromGoal(String goal) {
    final lower = goal.toLowerCase();
    if (lower.contains('amazon')) return 'https://www.amazon.com';
    if (lower.contains('youtube')) return 'https://www.youtube.com';
    if (lower.contains('reddit')) return 'https://www.reddit.com';
    if (lower.contains('twitter') || lower.contains(' x ')) {
      return 'https://twitter.com';
    }
    if (lower.contains('github')) return 'https://github.com';
    if (lower.contains('news')) {
      return 'https://news.google.com';
    }
    return '';
  }
}
