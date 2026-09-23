import 'dart:convert';

class JsonCorrector {
  /// Attempts to fix common LLM JSON formatting errors and returns a valid JSON string.
  /// If it still fails to parse, it returns a fallback JSON string.
  static String repair(String rawJson, {String fallback = '[]'}) {
    String cleaned = rawJson.trim();

    // Remove markdown code blocks if the LLM wrapped it
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.length > 2) {
        cleaned = lines.sublist(1, lines.length - 1).join('\n').trim();
        if (cleaned.endsWith('```')) {
          cleaned = cleaned.substring(0, cleaned.length - 3).trim();
        }
      }
    }

    try {
      // First, try to parse it directly
      jsonDecode(cleaned);
      return cleaned;
    } catch (_) {
      // 1. Check for trailing commas before closing braces/brackets
      cleaned = cleaned.replaceAll(RegExp(r',\s*\}'), '}');
      cleaned = cleaned.replaceAll(RegExp(r',\s*\]'), ']');

      // 2. Try to append missing closing brackets if truncated
      int openBraces = '\b{\b'.allMatches(cleaned).length;
      int closeBraces = '\b}\b'.allMatches(cleaned).length;
      int openBrackets = '\b\\[\b'.allMatches(cleaned).length;
      int closeBrackets = '\b\\]\b'.allMatches(cleaned).length;

      while (openBraces > closeBraces) {
        cleaned += '}';
        closeBraces++;
      }
      while (openBrackets > closeBrackets) {
        cleaned += ']';
        closeBrackets++;
      }

      try {
        jsonDecode(cleaned);
        return cleaned;
      } catch (_) {
        // If it still fails, return the fallback
        return fallback;
      }
    }
  }
}
