import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class UrlExtractorService {
  static final UrlExtractorService instance = UrlExtractorService._internal();
  UrlExtractorService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.plain,
    ),
  );

  /// Fetches raw text content from a URL, utilizing Jina AI for heavy SPA bypass and falling back to Native.
  Future<String> extractText(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';

    // 1. Attempt High-Yield High-Bypass extraction via Jina Reader API
    try {
      final jinaResponse = await _dio.get(
        'https://r.jina.ai/$trimmed',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'X-Return-Format': 'markdown'},
        ),
      );

      if (jinaResponse.statusCode == 200 && jinaResponse.data != null) {
        final text = jinaResponse.data.toString().trim();
        if (text.length > 50) {
          debugPrint(
            '[UrlExtractorService] Jina AI extraction success (${text.length} chars).',
          );
          return text;
        }
      }
    } catch (e) {
      debugPrint(
        '[UrlExtractorService] Jina AI extraction failed/rate-limited: $e. Falling back to native...',
      );
    }

    // 2. Fallback to Native HTML Extraction if Jina is rate-limited or blocked
    try {
      final response = await _dio.get(
        trimmed,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        String content = response.data.toString();

        // Extract <body> if present
        final bodyMatch = RegExp(
          r'<body[^>]*>(.*?)</body>',
          dotAll: true,
          caseSensitive: false,
        ).firstMatch(content);
        if (bodyMatch != null && bodyMatch.group(1) != null) {
          content = bodyMatch.group(1)!;
        }

        content = content.replaceAll(
          RegExp(
            r'<script\b[^>]*>.*?</script>',
            dotAll: true,
            caseSensitive: false,
          ),
          ' ',
        );
        content = content.replaceAll(
          RegExp(
            r'<style\b[^>]*>.*?</style>',
            dotAll: true,
            caseSensitive: false,
          ),
          ' ',
        );
        content = content.replaceAll(
          RegExp(r'<nav\b[^>]*>.*?</nav>', dotAll: true, caseSensitive: false),
          ' ',
        );
        content = content.replaceAll(
          RegExp(
            r'<header\b[^>]*>.*?</header>',
            dotAll: true,
            caseSensitive: false,
          ),
          ' ',
        );
        content = content.replaceAll(
          RegExp(
            r'<footer\b[^>]*>.*?</footer>',
            dotAll: true,
            caseSensitive: false,
          ),
          ' ',
        );
        content = content.replaceAll(
          RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false),
          ' ',
        );
        content = content.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (content.isNotEmpty) {
          debugPrint(
            '[UrlExtractorService] Native extraction success (${content.length} chars).',
          );
          return content;
        }
      }
    } catch (e) {
      debugPrint('[UrlExtractorService] Native extraction failed: $e.');
    }

    return '';
  }
}
