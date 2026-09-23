import 'package:flutter/foundation.dart';
import 'dart:convert';

void main() {
  const summary = "Here is a summary.\n\nIt contains \"quotes\" and newlines.";
  const url = "https://techcrunch.com";
  const title = "TechCrunch";

  String response = "> **Sources:**\n> - https://techcrunch.com\n\n";

  final payload = jsonEncode({'url': url, 'title': title, 'summary': summary});

  response += '<deep-search-card>$payload</deep-search-card>\n';

  // Simulate _buildParsedText
  String currentText = response;

  final cardMatch = RegExp(
    r'<deep-search-card>(.*?)</deep-search-card>',
    dotAll: true,
  ).firstMatch(currentText);
  if (cardMatch != null) {
    debugPrint('Regex matched!');
    final extracted = cardMatch.group(1)!;
    debugPrint('Payload: $extracted');
    try {
      final data = jsonDecode(extracted);
      debugPrint('Successfully decoded JSON!');
      debugPrint('URL: ${data['url']}');
    } catch (e) {
      debugPrint('JSON Decode failed: $e');
    }
  } else {
    debugPrint('Regex FAILED to match!');
  }
}
