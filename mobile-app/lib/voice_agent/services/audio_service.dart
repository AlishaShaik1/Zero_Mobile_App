import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

// ─────────────────── ZeroAudioService (Pure On-Device STT) ───────────────────
class ZeroAudioService {
  ZeroAudioService._();
  static final ZeroAudioService instance = ZeroAudioService._();

  final SpeechToText _stt = SpeechToText();
  bool _isInit = false;
  bool _isListening = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _commandController = StreamController<String>.broadcast();
  final _wakeController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _debugController = StreamController<String>.broadcast();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<String> get commandStream => _commandController.stream;
  Stream<String> get wakeStream => _wakeController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<String> get debugStream => _debugController.stream;

  bool get isInitialized => _isInit;
  bool get isListening => _isListening;

  void _logDebug(String msg) {
    debugPrint('[ZeroAudioService] $msg');
    if (!_debugController.isClosed) {
      _debugController.add(msg);
    }
  }

  void replayStartupLogs() {
    _logDebug('ZeroAudioService: On-Device STT Engine Active ✅');
  }

  Future<void> initKeywordSpotter([String? kwsTokensPath]) async {
    if (_isInit) return;
    try {
      _isInit = await _stt.initialize(
        onError: (err) {
          _logDebug('STT Error: ${err.errorMsg}');
          if (!_errorController.isClosed) {
            _errorController.add(err.errorMsg);
          }
        },
        onStatus: (status) {
          _logDebug('STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );
      _logDebug('On-Device SpeechRecognizer initialized: $_isInit');
    } catch (e) {
      _logDebug('Failed to init On-Device STT: $e');
      _isInit = false;
    }
  }

  Future<void> startListening() async {
    await startDirectListening();
  }

  Future<void> startDirectListening() async {
    if (!_isInit) {
      await initKeywordSpotter();
    }
    if (!_isInit) return;

    if (_isListening) {
      await _stt.stop();
    }

    try {
      _isListening = true;
      await _stt.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isNotEmpty) {
            if (!_transcriptController.isClosed) {
              _transcriptController.add(words);
            }
            if (result.finalResult) {
              if (!_commandController.isClosed) {
                _commandController.add(words);
              }
            }
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      _logDebug('Error starting STT listen: $e');
      _isListening = false;
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _stt.stop();
      _isListening = false;
    }
  }

  void resetToKwsMode() {
    // Reset state for next speech input
    _isListening = false;
  }

  void dispose() {
    _stt.stop();
    _transcriptController.close();
    _commandController.close();
    _wakeController.close();
    _errorController.close();
    _debugController.close();
  }
}
