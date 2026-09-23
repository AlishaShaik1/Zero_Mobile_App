// phone_mic_stt_service.dart
// Uses speech_to_text package to listen from the PHONE MIC and
// route transcript through the same AI pipeline as ring audio.
//
// This is the reliable fallback for:
//  - "Start Listen" button in ring companion screen
//  - Chat screen voice input
//  - Whenever ring BLE is not available

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Lightweight wrapper around speech_to_text for phone mic input.
class PhoneMicSTT {
  PhoneMicSTT._();
  static final PhoneMicSTT instance = PhoneMicSTT._();

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _isListening = false;

  // Streams
  final _transcriptCtrl = StreamController<String>.broadcast();
  final _statusCtrl = StreamController<PhoneMicStatus>.broadcast();

  Stream<String> get transcript => _transcriptCtrl.stream;
  Stream<PhoneMicStatus> get status => _statusCtrl.stream;

  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      _initialized = await _stt.initialize(
        onError: (e) {
          debugPrint('[PhoneMicSTT] Error: ${e.errorMsg}');
          _isListening = false;
          _statusCtrl.add(PhoneMicStatus.error);
        },
        onStatus: (s) {
          debugPrint('[PhoneMicSTT] Status: $s');
          if (s == 'done' || s == 'notListening') {
            _isListening = false;
            _statusCtrl.add(PhoneMicStatus.idle);
          }
        },
      );
      debugPrint('[PhoneMicSTT] Initialized: $_initialized');
    } catch (e) {
      debugPrint('[PhoneMicSTT] Init error: $e');
      _initialized = false;
    }
    return _initialized;
  }

  /// Start listening from phone mic.
  /// [onResult] called with final transcript when speech ends.
  Future<void> startListening({
    required void Function(String transcript) onResult,
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 2),
    String localeId = 'en_IN',
  }) async {
    if (!await initialize()) {
      debugPrint('[PhoneMicSTT] Not initialized - cannot listen');
      _statusCtrl.add(PhoneMicStatus.error);
      return;
    }
    if (_isListening) await stopListening();

    _isListening = true;
    _statusCtrl.add(PhoneMicStatus.listening);
    debugPrint('[PhoneMicSTT] Starting phone mic listen...');

    String lastPartial = '';

    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          final text = result.recognizedWords.trim();
          if (text.isNotEmpty) {
            lastPartial = text;
            _transcriptCtrl.add(text);
            debugPrint('[PhoneMicSTT] ${result.finalResult ? "FINAL" : "partial"}: "$text"');
          }
          if (result.finalResult) {
            _isListening = false;
            _statusCtrl.add(PhoneMicStatus.idle);
            if (text.isNotEmpty) {
              onResult(text);
            } else if (lastPartial.isNotEmpty) {
              onResult(lastPartial);
            }
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          cancelOnError: false,
          partialResults: true,
          listenFor: listenFor,
          pauseFor: pauseFor,
          localeId: localeId,
        ),
      );
    } catch (e) {
      debugPrint('[PhoneMicSTT] listen error: $e');
      _isListening = false;
      _statusCtrl.add(PhoneMicStatus.error);
      // If we have a partial, still use it
      if (lastPartial.isNotEmpty) onResult(lastPartial);
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;
    await _stt.stop();
    _statusCtrl.add(PhoneMicStatus.idle);
    debugPrint('[PhoneMicSTT] Stopped');
  }

  void dispose() {
    _stt.cancel();
    _transcriptCtrl.close();
    _statusCtrl.close();
  }
}

enum PhoneMicStatus { idle, listening, error }
