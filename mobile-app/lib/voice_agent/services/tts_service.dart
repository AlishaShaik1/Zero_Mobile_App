import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// TtsService — uses Android's Google TTS engine directly for human-quality voice.
/// No Sherpa/ONNX/espeak dependencies — zero extra APK size, zero init errors.
///
/// Google TTS (com.google.android.tts) ships on all modern Android devices
/// and uses the same neural voice as Google Assistant. It is already cached on-device.
class TtsService {
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _isInit = false;
  bool get isInitialized => _isInit;

  /// Kept for API compatibility with BLE pipeline — always null with this engine.
  dynamic get rawEngine => null;

  final List<String> _sentenceQueue = [];
  bool _isPlaying = false;
  Completer<void>? _playCompleter;

  TtsService._() {
    _tts.setCompletionHandler(() {
      _isPlaying = false;
      if (_sentenceQueue.isEmpty) {
        _playCompleter?.complete();
        _playCompleter = null;
      } else {
        _playNextInQueue();
      }
    });

    _tts.setErrorHandler((msg) {
      debugPrint('ZeroTTS error: $msg');
      _isPlaying = false;
      _playCompleter?.complete();
      _playCompleter = null;
    });
  }

  Future<void> initialize() async {
    if (_isInit) return;

    try {
      // Force Google TTS engine — same neural voice as Google Assistant.
      // On devices without Google TTS the system falls back to the default engine gracefully.
      await _tts.setEngine('com.google.android.tts');
    } catch (_) {
      // Engine may not exist on some custom ROMs — fall back to default.
      debugPrint('ZeroTTS: Google TTS engine not found, using system default.');
    }

    try {
      await _tts.setLanguage('en-US');

      // 0.57 is the sweet spot: sounds natural and human, not robotic.
      // Google's neural voice at 0.5 is too slow; 0.6 starts feeling rushed.
      await _tts.setSpeechRate(0.57);

      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0); // 1.0 = natural, unchanged pitch
    } catch (e) {
      debugPrint('ZeroTTS: init config error: $e');
    }

    _isInit = true;
    debugPrint('ZeroTTS: Google neural TTS initialized ✅');
  }

  /// Cancel current speech and flush the queue.
  Future<void> stop() async {
    _sentenceQueue.clear();
    _isPlaying = false;
    _playCompleter?.complete();
    _playCompleter = null;
    await _tts.stop();
  }

  /// Queue text for playback — returns immediately.
  Future<void> speak(String text) async {
    if (!_isInit || text.trim().isEmpty) return;
    _sentenceQueue.add(text.trim());
    _playNextInQueue();
  }

  /// Speak text and wait until audio fully finishes.
  Future<void> speakAndWait(String text) async {
    if (!_isInit || text.trim().isEmpty) return;
    _sentenceQueue.add(text.trim());
    _playCompleter ??= Completer<void>();
    _playNextInQueue();
    await _playCompleter!.future;
  }

  Future<void> _playNextInQueue() async {
    if (_isPlaying || _sentenceQueue.isEmpty) return;
    _isPlaying = true;
    final text = _sentenceQueue.removeAt(0);
    await _tts.speak(text);
  }

  void dispose() {
    _tts.stop();
  }
}
