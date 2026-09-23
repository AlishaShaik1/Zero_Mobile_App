import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:dio/dio.dart';

void main() async {
  debugPrint('--- Testing Zero Search Gateway ---');
  final dio = Dio();

  try {
    final response = await dio.post(
      'https://zero-search-gateway.vercel.app/search',
      data: {'q': 'latest artificial intelligence news'},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': 'zerotech1234',
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      if (data is Map) {
        debugPrint('Gateway Response Keys: ${data.keys.toList()}');
        List? organicList;
        if (data.containsKey('answer')) {
          debugPrint('Found nested answer wrapper, parsing...');
          final rawAnswerString = data['answer'].toString();
          final nested = jsonDecode(rawAnswerString);
          organicList = nested['organic'] as List?;
        } else if (data.containsKey('organic')) {
          debugPrint('Found direct organic object array, parsing...');
          organicList = data['organic'] as List?;
        }

        if (organicList != null && organicList.isNotEmpty) {
          debugPrint(
            '\nGateway is ON. Scraped ${organicList.length} organic links.',
          );
          for (var item in organicList.take(3)) {
            debugPrint('- Title: ${item["title"]}');
            debugPrint('  URL: ${item["link"]}');
          }
        } else {
          debugPrint('No organic results found in data.');
        }
      } else {
        debugPrint('Invalid response format type: ${data.runtimeType}');
      }
    } else {
      debugPrint('Gateway error: ${response.statusCode}');
    }
  } catch (e) {
    if (e is DioException) {
      debugPrint('DioError: ${e.message} ${e.response?.data}');
    } else {
      debugPrint('Failed to reach gateway: $e');
    }
  }
}
