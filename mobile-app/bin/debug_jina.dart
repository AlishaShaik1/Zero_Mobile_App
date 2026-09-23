import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

void main() async {
  const url = 'https://techcrunch.com';
  final dio = Dio();

  debugPrint('Trying r.jina.ai...');
  try {
    final response = await dio.get(
      'https://r.jina.ai/$url',
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'X-Return-Format': 'markdown', // Ensure pure markdown
        },
      ),
    );
    debugPrint('Jina AI status: ${response.statusCode}');
    if (response.statusCode == 200) {
      final text = response.data.toString();
      debugPrint('Extracted length: ${text.length}');
      debugPrint('Preview: \n${text.substring(0, 100)}...');
    }
  } catch (e) {
    debugPrint('Jina AI error: $e');
  }
}
