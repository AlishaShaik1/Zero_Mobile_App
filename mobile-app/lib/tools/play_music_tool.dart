import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// Play Music Tool — extracts song/artist query → opens Spotify via deep link.
class PlayMusicTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  PlayMusicTool() : super('play_music');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async => '';

  @override
  Future<String> executeNative(String promptBOutput) async => '';

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    // Step 1: extract song/artist from message (bypass if provided by agent router)
    String query = preExtractedParam ?? '';
    if (query.trim().isEmpty) {
      query = await modelService.extractSingleField(
        fieldName: 'song name or artist name or music search query for Spotify',
        toolName: 'play_music',
        userMessage: userMessage,
        maxTokens: 30,
      );
    }

    // Step 2: clarification if no song/artist was specified
    if (query.trim().isEmpty) {
      return '🎵 What song or artist would you like me to play on Spotify?';
    }

    final cleanQuery = query.trim();

    // Step 3: open Spotify with play-from-search deep link (plays directly)
    try {
      final played = await _channel.invokeMethod<bool>('play_spotify', {
        'query': cleanQuery,
      });
      if (played == true) {
        return '🎵 Playing "$cleanQuery" on Spotify!';
      }
      // Spotify not installed — fallback to YouTube Music search in browser
      final ytQuery = Uri.encodeQueryComponent(cleanQuery);
      await _channel.invokeMethod('open_browser', {
        'url': 'https://music.youtube.com/search?q=$ytQuery',
      });
      return '🎵 Spotify not installed — opened "$cleanQuery" in YouTube Music.';
    } catch (e) {
      return '🎵 Could not play music: $e';
    }
  }
}
