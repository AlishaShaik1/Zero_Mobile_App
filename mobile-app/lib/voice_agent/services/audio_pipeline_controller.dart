// audio_pipeline_controller.dart
// Continuous, always-on speech → LLM → TTS pipeline.
// • Mic is open at all times until the user explicitly pauses it.
// • ASR endpoint (0.5 s trailing silence) → immediate LLM call — no long wait.
// • Silence watchdog 2 s (snappy re-listen), 4 s router timeout, 3 s first-token guard.
// • Barge-in cancels TTS + generation the instant user voice is detected.
// • Tool results shown in UI before TTS starts.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/model_service.dart';
import '../../services/agent_router_service.dart';
import '../../services/pipeline_service.dart';
import '../../services/search_service.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../services/model_manager.dart';
import '../../services/ring_reply_sender.dart';

enum AudioPipelineState {
  idle,
  initializing,
  listening,
  routing,
  generating,
  speaking,
  error,
}

class AudioPipelineController {
  AudioPipelineController._();
  static final AudioPipelineController instance = AudioPipelineController._();

  // ── State ──────────────────────────────────────────────────────────────────
  AudioPipelineState _state = AudioPipelineState.idle;
  AudioPipelineState get state => _state;

  bool _running = false; // overall session alive
  bool _micPaused = false; // user deliberately paused the mic
  bool _processing = false; // currently routing/generating/speaking
  bool _bargeInEnabled = true;

  // ── Streams ────────────────────────────────────────────────────────────────
  StreamSubscription? _commandSub;
  StreamSubscription? _transcriptSub;

  final _transcriptCtrl = StreamController<String>.broadcast();
  Stream<String> get liveTranscriptStream => _transcriptCtrl.stream;

  final _llmCtrl = StreamController<String>.broadcast();
  Stream<String> get liveLlmResponseStream => _llmCtrl.stream;

  final _stateCtrl = StreamController<AudioPipelineState>.broadcast();
  Stream<AudioPipelineState> get stateStream => _stateCtrl.stream;

  final _errorCtrl = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorCtrl.stream;

  // ── Watchdog ───────────────────────────────────────────────────────────────
  Timer? _watchdog;

  String _currentLlmText = '';
  String _currentSpokenText = '';

  OrchestrationPipeline? _pipeline;

  // ── State helpers ──────────────────────────────────────────────────────────

  void _setState(AudioPipelineState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateCtrl.isClosed) _stateCtrl.add(next);
    debugPrint('[Live] → ${next.name}');
  }

  void _emitError(String msg) {
    debugPrint('[Live] ❌ $msg');
    if (!_errorCtrl.isClosed) _errorCtrl.add(msg);
    _setState(AudioPipelineState.error);
  }

  void _armWatchdog(int seconds, String label, VoidCallback onTimeout) {
    _watchdog?.cancel();
    _watchdog = Timer(Duration(seconds: seconds), () {
      debugPrint('[Live] ⏱ watchdog: $label');
      onTimeout();
    });
  }

  void _disarmWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Open the session and start listening instantly.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _micPaused = false;
    _setState(AudioPipelineState.initializing);

    try {
      final prefs = await SharedPreferences.getInstance();
      _bargeInEnabled = prefs.getBool('barge_in_enabled') ?? true;

      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        _emitError('Microphone permission denied');
        _running = false;
        _setState(AudioPipelineState.idle);
        return;
      }

      // Boot isolate if needed
      if (!ZeroAudioService.instance.isInitialized) {
        final kwsPath = await ModelManager.instance.ensureKeywordsFile();
        await ZeroAudioService.instance.initKeywordSpotter(kwsPath);
      }

      // ── CRITICAL: Ensure LLM is loaded before taking any voice commands ──
      // ModelService.chat() returns "Model not loaded yet." if not ready —
      // Live Voice would speak that error on every utterance without this.
      if (!ModelService().isReady) {
        debugPrint('[Live] LLM not ready — initializing now...');
        try {
          await ModelService().initialize();
          debugPrint('[Live] LLM ready ✅');
        } catch (e) {
          debugPrint(
            '[Live] LLM init failed: $e — will retry on first command',
          );
        }
      }

      // Initialize TTS engine (CRITICAL — speak() is a no-op if not done)
      if (!TtsService.instance.isInitialized) {
        try {
          await TtsService.instance.initialize();
        } catch (e) {
          debugPrint(
            '[Live] TTS init failed: $e — will continue without voice',
          );
        }
      }

      // Partials → live transcript display
      await _transcriptSub?.cancel();
      _transcriptSub = ZeroAudioService.instance.transcriptStream.listen((
        text,
      ) {
        if (!_transcriptCtrl.isClosed) _transcriptCtrl.add(text);

        // Acknowledge speech started — disarm the silence (3s) watchdog
        _disarmWatchdog();

        // Barge-in while AI is talking → cancel immediately
        if (_bargeInEnabled &&
            text.trim().length > 2 &&
            (_state == AudioPipelineState.speaking ||
                _state == AudioPipelineState.generating)) {
          debugPrint('[Live] Barge-in!');
          _cancelAi();
        }
      });

      // Final committed utterance from ASR endpoint
      await _commandSub?.cancel();
      _commandSub = ZeroAudioService.instance.commandStream.listen((cmd) {
        if (!_running || _micPaused) return;
        _disarmWatchdog();
        _handleCommand(cmd);
      });

      await _openMic();
    } catch (e) {
      _emitError('Start failed: $e');
      _running = false;
      _setState(AudioPipelineState.idle);
    }
  }

  /// Hard stop — closes the session completely.
  void stop() {
    _running = false;
    _micPaused = false;
    _processing = false;
    _disarmWatchdog();
    _commandSub?.cancel();
    _transcriptSub?.cancel();
    _commandSub = null;
    _transcriptSub = null;
    _cancelAi();
    ZeroAudioService.instance.resetToKwsMode();
    _setState(AudioPipelineState.idle);
  }

  /// Toggle mic on/off without ending the session.
  Future<void> toggleMic() async {
    if (!_running) return;

    // If the AI is currently thinking or speaking, toggle acts as an interrupt.
    if (_processing) {
      await interrupt();
      return;
    }

    if (_micPaused) {
      _micPaused = false;
      await _openMic();
    } else {
      _micPaused = true;
      ZeroAudioService.instance.resetToKwsMode();
      _setState(AudioPipelineState.idle);
    }
  }

  /// Interrupt AI speaking/thinking and immediately return to listening.
  Future<void> interrupt() async {
    if (!_running || !_processing) return;
    debugPrint('[Live] User interrupted manually');
    _cancelAi();
    _processing = false;
    _micPaused = false;
    await _openMic();
  }

  bool get isMicPaused => _micPaused;

  // ── Internal: open mic + arm silence watchdog ──────────────────────────────

  Future<void> _openMic() async {
    if (!_running || _micPaused || _processing) return;
    _setState(AudioPipelineState.listening);
    debugPrint('[Live] Opening mic for next utterance');

    try {
      await ZeroAudioService.instance.startDirectListening();
    } catch (e) {
      _emitError('Mic open failed: $e');
      // Brief back-off then retry
      await Future.delayed(const Duration(seconds: 1));
      if (_running && !_micPaused) await _openMic();
      return;
    }

    // 2-second silence watchdog: faster re-listen if no speech detected.
    _armWatchdog(2, 'silence', () async {
      if (_running && !_micPaused && !_processing) {
        await _openMic(); // reset & re-listen quietly
      }
    });
  }

  // ── Command handler ────────────────────────────────────────────────────────

  Future<void> _handleCommand(String text) async {
    if (text.trim().isEmpty) {
      if (_running && !_micPaused) await _openMic();
      return;
    }

    _processing = true;

    final trimmed = text.trim();
    if (!_transcriptCtrl.isClosed) _transcriptCtrl.add(trimmed);
    _currentLlmText = '';
    _currentSpokenText = '';
    // Instant visual feedback: show what we heard while routing
    if (!_llmCtrl.isClosed) _llmCtrl.add('▸ $trimmed');

    try {
      // 1. Fast routing — 4 s cap (Q4 model is faster than Q8)
      _setState(AudioPipelineState.routing);
      AgentRoute route;
      try {
        route = await AgentRouterService.instance.route(
          trimmed,
          timeout: const Duration(seconds: 4),
        );
      } catch (_) {
        route = const AgentRoute(toolName: '', isNone: true);
      }

      if (!route.isNone) {
        // Tool intent → execute via pipeline
        debugPrint('[Live] Executing Tool: ${route.toolName}');
        _setState(AudioPipelineState.generating);

        _pipeline ??= OrchestrationPipeline(ModelService(), SearchService());
        String toolResponse = '';

        if (route.toolName == 'multi') {
          await for (final chunk in _pipeline!.run(trimmed)) {
            toolResponse += chunk;
            if (!_llmCtrl.isClosed) {
              _llmCtrl.add(toolResponse); // stream to UI live
            }
          }
        } else {
          await for (final chunk in _pipeline!.run(
            trimmed,
            presetTools: [route.toolName],
            presetParam: route.param,
            injectedArgs: route.arguments.isNotEmpty ? route.arguments : null,
          )) {
            toolResponse += chunk;
            if (!_llmCtrl.isClosed) {
              _llmCtrl.add(toolResponse); // stream to UI live
            }
          }
        }

        final cleanedOutput = toolResponse.replaceAll(RegExp(r'//.*?\n'), '');
        final spokenResult = _clean(cleanedOutput);

        if (spokenResult.isNotEmpty && _running) {
          _setState(AudioPipelineState.speaking);
          _currentSpokenText += '$spokenResult ';
          if (!_llmCtrl.isClosed) _llmCtrl.add(spokenResult);
          RingReplySender.instance.sendCaption(spokenResult).ignore(); // display on ring
          await TtsService.instance.speakAndWait(spokenResult);
        }

        _processing = false;
        if (_running && !_micPaused) await _openMic();
        return;
      }

      // 2. TTS Generation (from pre-generated reply OR fallback chat)
      _setState(AudioPipelineState.generating);
      _armWatchdog(3, 'first-token timeout', () async {
        // 3 s is enough for fast Q4 model
        _cancelAi();
        _processing = false;
        if (_running && !_micPaused) await _openMic();
      });

      String sentenceBuffer = '';
      bool gotFirstToken = false;

      // Ensure we disarm watchdog as data is coming
      void checkFirstToken() {
        if (!gotFirstToken) {
          _disarmWatchdog();
          gotFirstToken = true;
        }
      }

      final preReply = route.reply;
      if (preReply != null && preReply.isNotEmpty) {
        // FAST PATH: Router already gave us the full plain-text reply!
        checkFirstToken();
        _currentLlmText = preReply;
        if (!_llmCtrl.isClosed) _llmCtrl.add(_currentLlmText);

        final sentence = _clean(preReply);
        if (sentence.isNotEmpty && _running) {
          _setState(AudioPipelineState.speaking);
          _currentSpokenText += '$sentence ';
          RingReplySender.instance.sendCaption(sentence).ignore(); // display on ring
          await TtsService.instance.speakAndWait(sentence);
        }
      } else {
        // SLOW PATH: Fallback LLM pass if router dropped it
        await for (final delta in ModelService().chat(trimmed)) {
          if (!_running) break;
          checkFirstToken();

          if (delta is ThinkingDelta) {
            _currentLlmText += delta.text;
            if (!_llmCtrl.isClosed) _llmCtrl.add(_currentLlmText);
            continue;
          }

          if (delta is! ContentDelta) continue;

          _currentLlmText += delta.text;
          sentenceBuffer += delta.text;
          if (!_llmCtrl.isClosed) _llmCtrl.add(_currentLlmText);

          // Sentence-level TTS streaming for low latency
          if (_isSentenceEnd(sentenceBuffer)) {
            final sentence = _clean(sentenceBuffer);
            sentenceBuffer = '';
            if (sentence.isNotEmpty && _running) {
              _setState(AudioPipelineState.speaking);
              _currentSpokenText += '$sentence ';
              RingReplySender.instance.sendCaption(sentence).ignore(); // display on ring
              await TtsService.instance.speakAndWait(sentence);
              if (_running) _setState(AudioPipelineState.generating);
            }
          }
        } // end await for
      } // end else

      _disarmWatchdog();

      // Flush tail
      final tail = _clean(sentenceBuffer);
      if (tail.isNotEmpty && _running) {
        _setState(AudioPipelineState.speaking);
        _currentSpokenText += '$tail ';
        RingReplySender.instance.sendCaption(tail).ignore(); // display on ring
        await TtsService.instance.speakAndWait(tail);
      }
    } catch (e) {
      _emitError('Pipeline error: $e');
      await Future.delayed(const Duration(seconds: 1));
    } finally {
      _disarmWatchdog();
      _processing = false;
      // Always return to listening after response
      if (_running && !_micPaused) await _openMic();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _cancelAi() {
    if (_currentSpokenText.isNotEmpty) {
      ModelService().commitPartialResponse(_currentSpokenText);
      _currentSpokenText = '';
    }
    try {
      ModelService().cancelGeneration();
    } catch (_) {}
    try {
      TtsService.instance.stop();
    } catch (_) {}
  }

  bool _isSentenceEnd(String t) {
    if (t.length < 4) return false;
    return t.endsWith('. ') ||
        t.endsWith('.\n') ||
        t.endsWith('! ') ||
        t.endsWith('? ');
  }

  /// Strips model artifacts before display/TTS.

  String _clean(String t) {

    // Remove all XML/HTML tags (<think>, <tool>, <|im_end|>, <s>, etc.)

    t = t.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove JSON fragments to avoid routing artifacts leaking to screen

    t = t.replaceAll(RegExp(r'\{[^}]*\}'), '');

    // Collapse extra whitespace

    t = t.replaceAll(RegExp(r' +'), ' ');

    return t.trim();

  }

}

