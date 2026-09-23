// search_service.dart — Zero Search Gateway
// Connects to the remote search backend.
// The LLM only sees results AFTER search completes — it never decides
// whether to search, the deterministic router already made that call.
import 'dart:convert' as dart_json;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class SearchResult {
  final String title;
  final String snippet;
  final String url;

  const SearchResult({
    required this.title,
    required this.snippet,
    required this.url,
  });

  @override
  String toString() => '$title: $snippet ($url)';
}

class SearchService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
      },
    ),
  );

  static const String _gatewayUrl =
      'https://zero-search-gateway.vercel.app/search';
  static const String _gatewayApiKey = String.fromEnvironment(
    'GATEWAY_API_KEY',
    defaultValue: 'zerotech1234',
  );

  // ─── Direct Result List (for Deep Search) ────────────────────────
  Future<List<SearchResult>> searchRaw(String query) async {
    try {
      final response = await _dio.post(
        _gatewayUrl,
        data: {'q': query},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': _gatewayApiKey,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('answer')) {
          try {
            final answerRaw = data['answer'];
            Map nested;
            if (answerRaw is Map) {
              nested = answerRaw;
            } else {
              nested = dart_json.jsonDecode(answerRaw.toString());
            }

            final organicList = nested['organic'] as List?;
            if (organicList != null && organicList.isNotEmpty) {
              return organicList.map((item) {
                return SearchResult(
                  title: item['title']?.toString() ?? 'No Title',
                  snippet: item['snippet']?.toString() ?? 'No Snippet',
                  url: item['link']?.toString() ?? '',
                );
              }).toList();
            }
          } catch (e) {
            debugPrint('[SearchService] Failed to parse nested JSON: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[SearchService] Gateway failed: $e');
    }
    return [];
  }

  // ─── String Result (for simple chat tools) ───────────────────────
  Future<String> search(String query) async {
    final results = await searchRaw(query);
    if (results.isEmpty) {
      return 'Sorry, I could not find any results for that right now or there was a connection error.';
    }

    // Format up to 5 results nicely for the LLM
    final buffer = StringBuffer();
    for (int i = 0; i < results.length && i < 5; i++) {
      final r = results[i];
      buffer.writeln('Result ${i + 1}: ${r.title}');
      buffer.writeln('Snippet: ${r.snippet}');
      buffer.writeln('URL: ${r.url}\n');
    }
    return buffer.toString();
  }
}
