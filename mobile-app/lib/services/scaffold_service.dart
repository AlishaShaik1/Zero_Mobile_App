// package:flutter/services.dart not used in scaffold_service

enum ProjectType { website, game }

class ScaffoldService {
  static ProjectType parseType(String raw) {
    final firstLine = raw.split('\n').first.trim().toLowerCase();
    if (firstLine.contains('game')) return ProjectType.game;
    return ProjectType.website;
  }

  static String stripType(String raw) {
    final lines = raw.split('\n');
    if (lines.isNotEmpty && lines.first.trim().startsWith('TYPE:')) {
      return lines.sublist(1).join('\n').trim();
    }
    return raw.trim();
  }

  static Future<String> assemble({
    required ProjectType type,
    required String aiCode,
    required String title,
    String? supabaseUrl,
    String? supabaseKey,
  }) async {
    final hasSupa = supabaseUrl != null && supabaseKey != null;
    final supaScript = hasSupa
        ? '<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'
        : '';
    final supaInit = hasSupa
        ? '\nconst _SUPA_URL = "$supabaseUrl";\nconst _SUPA_KEY = "$supabaseKey";\n'
        : '';
    final supaClientVar = hasSupa
        ? 'const _db = supabase.createClient(_SUPA_URL, _SUPA_KEY);'
        : 'const _db = null;';
    final supaAuthListen = hasSupa
        ? '''const { data: { session } } = await _db.auth.getSession();
        this.user = session?.user ?? null;
        _db.auth.onAuthStateChange((_,s)=>{ this.user = s?.user ?? null; });'''
        : '';

    final htmlBlock = _extractBlock(aiCode, ['html']);
    final cssBlock = _extractBlock(aiCode, ['css']);
    final jsBlock = _extractBlock(aiCode, ['js', 'javascript']);

    String finalHtml = htmlBlock.isNotEmpty ? htmlBlock : aiCode.trim();

    String headPayload = '';
    if (hasSupa) {
      headPayload += '$supaScript\n';
    }
    if (cssBlock.isNotEmpty) {
      headPayload += '<style>\n$cssBlock\n</style>\n';
    }
    if (headPayload.isNotEmpty) {
      if (finalHtml.toLowerCase().contains('</head>')) {
        finalHtml = finalHtml.replaceFirst(
          RegExp(r'</head>', caseSensitive: false),
          '$headPayload</head>',
        );
      } else {
        finalHtml = headPayload + finalHtml;
      }
    }

    String scriptPayload = '';
    if (hasSupa) {
      scriptPayload +=
          '<script>\n$supaInit$supaClientVar$supaAuthListen\n</script>\n';
    }
    if (jsBlock.isNotEmpty) {
      scriptPayload += '<script>\n$jsBlock\n</script>\n';
    }
    if (scriptPayload.isNotEmpty) {
      if (finalHtml.toLowerCase().contains('</body>')) {
        finalHtml = finalHtml.replaceFirst(
          RegExp(r'</body>', caseSensitive: false),
          '$scriptPayload</body>',
        );
      } else {
        finalHtml = '$finalHtml\n$scriptPayload';
      }
    }

    return finalHtml;
  }

  static String _extractBlock(String src, List<String> langs) {
    for (final lang in langs) {
      final re = RegExp(
        '```$lang[^\\n]*\\n([\\s\\S]*?)(?:\\n```|\$)',
        caseSensitive: false,
      );
      final m = re.firstMatch(src);
      if (m != null) return m.group(1)!.trim();
    }
    return '';
  }

  static String? parseSqlSchema(String raw) {
    final block = _extractBlock(raw, ['sql', 'postgresql', 'postgres']);
    return block.isNotEmpty ? block : null;
  }
}
