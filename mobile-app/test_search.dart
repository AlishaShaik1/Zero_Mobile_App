import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://zero-search-gateway.vercel.app/search');
  debugPrint('Testing Search Gateway: $url');

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': 'zerotech1234',
      },
      body: jsonEncode({'q': 'nvidia ceo'}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rawAnswer = data['answer'] as String;

      // Parse the embedded JSON string
      final parsedAnswer = jsonDecode(rawAnswer);

      final organic = parsedAnswer['organic'] as List?;
      debugPrint('\nSUCCESS! Status 200');
      debugPrint('Found ${organic?.length ?? 0} organic results.');
      if (organic != null && organic.isNotEmpty) {
        debugPrint('First result title: ${organic[0]['title']}');
        debugPrint('First result link: ${organic[0]['link']}');
      }
    } else {
      debugPrint('Error: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
    }
  } catch (e) {
    debugPrint('Failed to execute search: $e');
  }
}
