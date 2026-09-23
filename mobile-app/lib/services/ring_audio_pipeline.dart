// ring_audio_pipeline.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// RING → PHONE VOICE TRANSFER  (rebuilt FROM SCRATCH)
// ═══════════════════════════════════════════════════════════════════════════
//
// The entire old voice-transfer stack (native Kotlin SpeechRecognizer pipe,
// "not installed" recognizer errors, double EventChannel subscriptions,
// silent dead-ends) was removed. This file is the ONE and ONLY place where
// ring mic audio becomes text on the phone.
//
// THE WHOLE FLOW (nothing else is involved):
//
//   1. Ring firmware streams raw 16 kHz mono 16-bit PCM over BLE
//      (CHAR_MIC_AUDIO 0x6e400002):
//          [0xFF]  start marker  (button hold or phone "Start Listen")
//          [PCM…]  240-byte chunks, ~133 per second, while speaking
//          [0xFE]  stop marker   (button release)
//      Markers are OPTIONAL — without them the first chunk auto-starts and
//      the silence timer ends the utterance.
//
//   2. This pipeline accumulates every PCM chunk in a BytesBuilder.
//      The UI gets live proof of reception via the `diagnostics` stream
//      ("2.4s of ring audio received…") so you can always SEE the audio
//      arriving.
//
//   3. End of speech = 0xFE marker, or 1.8 s of silence, or 30 s max.
//
//   4. PCM is wrapped in a 44-byte WAV header and POSTed to Deepgram REST.
//      Two API keys + two models are tried in order, so one bad/expired
//      key cannot kill the feature.
//
//   5. The transcript is shown on the phone IMMEDIATELY (liveTranscript),
//      then forwarded to the existing agentic brain
//      (AgentRouterService → ToolExecutorService / GLM chat) exactly like
//      before, and the reply goes back to the ring OLED.
//
//   • No Android SpeechRecognizer anywhere → no "service not installed"
//     errors, works on every device.
//   • Every failure shows a SPECIFIC reason on screen — nothing ever
//     freezes on "Listening…" again.
//
// Everything else (BLE connect, camera, caption, TTS reply, phone mic) is
// untouched and reused.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'agent_router_service.dart';
import 'model_service.dart';
import 'phone_mic_stt_service.dart';
import 'ring_ble_service.dart';
import 'ring_constants.dart';
import 'ring_reply_sender.dart';
import 'search_service.dart';
import 'tool_executor_service.dart';

// ── Result / State types (public API — other screens depend on these) ───────

class RingPipelineResult {
  final String transcript;
  final AgentRoute route;
  final String? chatReply;
  final DateTime timestamp;

  const RingPipelineResult({
    required this.transcript,
    required this.route,
    this.chatReply,
    required this.timestamp,
  });
}

enum RingPipelineState { idle, listening, transcribing, thinking, replying }

// ── Voice-transfer tuning ────────────────────────────────────────────────────

/// 16 kHz × 2 bytes/sample = 32 000 bytes per second.
const int _kBytesPerSecond = 32000;

/// Below this much captured audio we treat the "utterance" as noise.
const int _kMinAudioBytes = 6400; // 0.2 s

/// No audio for this long while listening → end of speech.
const int _kSilenceMs = 1800;

/// Hard cap for one utterance (a stuck button must not eat RAM).
const int _kMaxAudioBytes = 960000; // 30 s

/// Marker bytes from the ring firmware.
const int _kMarkerStart = 0xFF;
const int _kMarkerStop = 0xFE;

// ── Deepgram STT (cloud — no on-device speech service required) ──────────────

// Two keys are tried in order: if the first is expired/invalid the second is
// used automatically, so the feature survives a bad key.
const List<String> _kDeepgramKeys = [
  'bf8e5c0fbe1d38a88cda424c00213dc8e0e70fc0', // primary (ring pipeline)
  '36dd865f774bfe84b2044e54f9b7c3f175a10634', // fallback (stt service)
];

const List<String> _kDeepgramModels = ['nova-3', 'nova-2'];

// ── GLM chat (unchanged — the "AI" half, not the voice-transfer half) ────────

const _kFireworksKey = 'fw_3iUKfhBn2vryacJynHPsUU';
const _kFireworksModel = 'accounts/fireworks/models/glm-5p3-flash';
const _kFireworksUrl = 'https://api.fireworks.ai/inference/v1/chat/completions';
const _kChatSys =
    'You are Zero, a fast AI voice assistant on a smart ring. '
    'Keep replies under 2 short sentences. Be concise, direct, and helpful.';

// =============================================================================
// RingAudioPipeline
// =============================================================================

class RingAudioPipeline {
  RingAudioPipeline._();
  static final RingAudioPipeline instance = RingAudioPipeline._();

  // ── State ─────────────────────────────────────────────────────────────────

  bool _active = false;
  bool get isActive => _active;

  RingPipelineState _state = RingPipelineState.idle;
  RingPipelineState get state => _state;
  bool get isListening => _state == RingPipelineState.listening;
  bool get isProcessing =>
      _state == RingPipelineState.transcribing ||
      _state == RingPipelineState.thinking ||
      _state == RingPipelineState.replying;

  /// True while ring mic audio is flowing (BLE session active).
  bool _isStreamingFromRing = false;
  bool get isStreamingFromRing => _isStreamingFromRing || isListening;

  bool _processingUtterance = false;
  bool _phoneInitiatedRingMic = false;

  // ── PCM accumulator (the ring's audio lands here) ─────────────────────────

  final _pcmAccumulator = BytesBuilder(copy: false);
  Timer? _silenceTimer;
  int get receivedBytes => _pcmAccumulator.length;
  double get receivedSeconds => _pcmAccumulator.length / _kBytesPerSecond;

  // ── Streams (public API) ──────────────────────────────────────────────────

  final _resultController = StreamController<RingPipelineResult>.broadcast();
  final _energyController = StreamController<double>.broadcast();
  final _liveTranscriptController = StreamController<String>.broadcast();
  final _liveAiResponseController = StreamController<String>.broadcast();
  final _stateController = StreamController<RingPipelineState>.broadcast();

  /// Live human-readable status of the ring→phone voice link, e.g.
  /// "Ring audio received: 2.4s (77 KB)". The companion screen shows this so
  /// the user can always SEE that ring audio is arriving.
  final _diagnosticsController = StreamController<String>.broadcast();

  Stream<RingPipelineResult> get results => _resultController.stream;
  Stream<double> get energyStream => _energyController.stream;
  Stream<String> get liveTranscript => _liveTranscriptController.stream;
  Stream<String> get liveAiResponse => _liveAiResponseController.stream;
  Stream<RingPipelineState> get stateStream => _stateController.stream;
  Stream<String> get diagnostics => _diagnosticsController.stream;

  StreamSubscription? _bleSubscription;

  bool _phoneMicActive = false;
  bool get isPhoneMicListening => _phoneMicActive;

  bool _initialized = false;

  // Throttle for the diagnostics stream (≤ ~10 updates/s).
  DateTime _lastDiagEmit = DateTime.fromMillisecondsSinceEpoch(0);

  // Remember which Deepgram key worked last (skip dead keys).
  int _workingKeyIndex = 0;

  // Agentic tool executor (ModelService/SearchService are factory singletons)
  final _executor = ToolExecutorService(ModelService(), SearchService());

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    start();
    debugPrint(
      '[RingVoice] Ready — ring mic → Deepgram REST → text on phone. '
      'Double-tap the ring to speak (or hold the button 2s).',
    );
  }

  void start() {
    if (_active) return;
    _active = true;
    _pcmAccumulator.clear();
    // Subscribe to BLE events exactly ONCE.
    _bleSubscription?.cancel();
    _bleSubscription = RingBleService.instance.events.listen(_onBleEvent);
    debugPrint('[RingVoice] BLE event listener attached');
  }

  void stop() {
    _active = false;
    _isStreamingFromRing = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _bleSubscription?.cancel();
    _bleSubscription = null;
    _pcmAccumulator.clear();
    _setState(RingPipelineState.idle);
  }

  void dispose() {
    stop();
    _resultController.close();
    _energyController.close();
    _liveTranscriptController.close();
    _liveAiResponseController.close();
    _stateController.close();
    _diagnosticsController.close();
  }

  // ---------------------------------------------------------------------------
  // BLE event router — the ONLY entry point for ring voice
  // ---------------------------------------------------------------------------

  void _onBleEvent(RingEvent event) {
    if (!_active) return;
    switch (event) {
      case RingAudioChunk(:final pcm):
        _handleAudioChunk(pcm);
        break;
      case RingConnectionEvent(:final state):
        if (state == RingConnectionState.disconnected) {
          _onRingDisconnected();
        }
        break;
      default:
        break;
    }
  }

  void _onRingDisconnected() {
    if (_isStreamingFromRing) {
      debugPrint('[RingVoice] Ring disconnected mid-utterance');
      _liveTranscriptController.add('(Ring disconnected)');
    }
    _isStreamingFromRing = false;
    _phoneInitiatedRingMic = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _pcmAccumulator.clear();
    if (!_processingUtterance) _setState(RingPipelineState.idle);
  }

  // ---------------------------------------------------------------------------
  // Audio chunk handler — ring mic → accumulator
  // ---------------------------------------------------------------------------

  void _handleAudioChunk(Uint8List pcm) {
    if (pcm.isEmpty) return;

    // ── Control markers (1 byte) ─────────────────────────────────────────────
    if (pcm.length == 1) {
      if (pcm[0] == _kMarkerStart) {
        _phoneInitiatedRingMic = _phoneInitiatedRingMic || _awaitingRingMic;
        if (!_isStreamingFromRing && !_processingUtterance) {
          _startRingListening();
        }
        return;
      }
      if (pcm[0] == _kMarkerStop) {
        if (_isStreamingFromRing && !_processingUtterance) {
          debugPrint('[RingVoice] Stop marker (0xFE) — sending to STT now');
          _finalizeSpeech();
        }
        return;
      }
      // Any other 1-byte packet: ignore.
      return;
    }

    // ── Real PCM chunk ───────────────────────────────────────────────────────
    if (_processingUtterance) return; // busy with previous utterance

    // First real audio (e.g. firmware without start marker) → auto-start.
    if (!_isStreamingFromRing) {
      _startRingListening();
    }

    // Hard cap so a stuck button can't grow forever.
    if (_pcmAccumulator.length + pcm.length > _kMaxAudioBytes) {
      debugPrint('[RingVoice] Max utterance length reached — finalizing');
      _finalizeSpeech();
      return;
    }

    _pcmAccumulator.add(pcm);
    _energyController.add(_rmsEnergy(pcm));
    _resetSilenceTimer();
    _emitDiagnostics();
  }

  void _startRingListening() {
    _isStreamingFromRing = true;
    _awaitingRingMic = false;
    _pcmAccumulator.clear();
    _setState(RingPipelineState.listening);
    _liveTranscriptController.add('Listening…');
    debugPrint('[RingVoice] Ring mic session started');
  }

  // ---------------------------------------------------------------------------
  // Silence detection (safety net — 0xFE marker is the primary end signal)
  // ---------------------------------------------------------------------------

  void _resetSilenceTimer() {
    if (_processingUtterance) return;
    _silenceTimer?.cancel();
    _silenceTimer = Timer(
      const Duration(milliseconds: _kSilenceMs),
      () {
        debugPrint('[RingVoice] ${_kSilenceMs}ms of silence — finalizing');
        _finalizeSpeech();
      },
    );
  }

  void _finalizeSpeech() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    if (_processingUtterance || !_active) return;

    final pcmBytes = _pcmAccumulator.length;
    _isStreamingFromRing = false;

    if (pcmBytes < _kMinAudioBytes) {
      debugPrint(
        '[RingVoice] Only ${pcmBytes} bytes captured — too short, ignoring',
      );
      _pcmAccumulator.clear();
      _setState(RingPipelineState.idle);
      _liveTranscriptController.add('(No speech detected — try again)');
      // The ring (older firmware without auto-stop) may still be streaming
      // silence — ask it to stop so we don't loop forever.
      _stopRingMicIfPhoneInitiated();
      if (RingBleService.instance.isConnected) {
        RingReplySender.instance.sendCommand(kCmdStopRecord);
      }
      return;
    }

    _processingUtterance = true;
    final pcm = Uint8List.fromList(_pcmAccumulator.toBytes());
    _pcmAccumulator.clear();
    debugPrint(
      '[RingVoice] Utterance complete: ${(pcm.length / _kBytesPerSecond).toStringAsFixed(1)}s '
      '(${pcm.length} PCM bytes) → Deepgram',
    );

    _transcribeAndProcess(pcm);
  }

  // ---------------------------------------------------------------------------
  // STT core: PCM → WAV → Deepgram REST → transcript
  // ---------------------------------------------------------------------------

  Future<void> _transcribeAndProcess(Uint8List pcm) async {
    _setState(RingPipelineState.transcribing);
    _liveTranscriptController.add('Transcribing…');

    final wav = _buildWav(pcm);
    debugPrint('[RingVoice] Sending ${wav.length}-byte WAV to Deepgram…');

    var transcript = '';
    String? lastError;

    // Try keys in order (the known-working key first), then models.
    final keyOrder = [
      _workingKeyIndex,
      for (final i in _kDeepgramKeys.indices)
        if (i != _workingKeyIndex) i,
    ];

    var succeeded = false;
    for (final keyIdx in keyOrder) {
      for (final model in _kDeepgramModels) {
        final (text, err) = await _deepgramRest(
          key: _kDeepgramKeys[keyIdx],
          model: model,
          wav: wav,
        );
        if (err == null) {
          transcript = text;
          _workingKeyIndex = keyIdx;
          succeeded = true;
          debugPrint(
            '[RingVoice] Deepgram OK (key#${keyIdx + 1}, $model): "$transcript"',
          );
          break;
        }
        lastError = err;
        debugPrint(
          '[RingVoice] Deepgram failed (key#${keyIdx + 1}, $model): $err',
        );
      }
      if (succeeded) break;
    }

    // ── Show the result on the phone — always something concrete ────────────
    if (transcript.isEmpty) {
      final msg =
          lastError != null ? 'STT error: $lastError' : '(No words detected — hold the ring button and speak)';
      debugPrint('[RingVoice] No transcript — $msg');
      _liveTranscriptController.add(msg);
      _liveAiResponseController.add('I could not hear you. Try again.');
      _processingUtterance = false;
      _setState(RingPipelineState.idle);
      _stopRingMicIfPhoneInitiated();
      return;
    }

    // THE TRANSCRIPT — this is what appears on the phone screen.
    _liveTranscriptController.add(transcript);

    await _processUtteranceWithTranscript(transcript);
  }

  Future<(String, String?)> _deepgramRest({
    required String key,
    required String model,
    required Uint8List wav,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              'https://api.deepgram.com/v1/listen'
              '?model=${model}'
              '&smart_format=true'
              '&language=en-US',
            ),
            headers: {
              'Authorization': 'Token $key',
              'Content-Type': 'audio/wav',
            },
            body: wav,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['results']?['channels']?[0]
            ?['alternatives']?[0]?['transcript'] as String?;
        return (raw?.trim() ?? '', null);
      }

      final body = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      return ('', 'HTTP ${response.statusCode} ($body)');
    } catch (e) {
      return ('', '$e');
    }
  }

  // ---------------------------------------------------------------------------
  // Phone-initiated ring mic (the companion-screen "Start Listen" button)
  // ---------------------------------------------------------------------------

  bool _awaitingRingMic = false;

  /// Ask the RING to start streaming its mic (phone-initiated session).
  /// Falls back to nothing if the ring is not connected.
  Future<bool> startRingMicFromPhone() async {
    if (!RingBleService.instance.isConnected) return false;
    _awaitingRingMic = true;
    _liveTranscriptController.add('Starting ring mic…');
    await RingReplySender.instance.sendCommand('start_listen');
    debugPrint('[RingVoice] start_listen sent to ring');
    return true;
  }

  /// Ask the ring to stop streaming its mic.
  Future<void> stopRingMicFromPhone() async {
    if (!RingBleService.instance.isConnected) return;
    await RingReplySender.instance.sendCommand(kCmdStopRecord);
  }

  void _stopRingMicIfPhoneInitiated() {
    if (_phoneInitiatedRingMic && RingBleService.instance.isConnected) {
      _phoneInitiatedRingMic = false;
      // Let the ring know the session is over (its OLED returns to home).
      RingReplySender.instance.sendCommand(kCmdStopRecord);
    }
  }

  // ---------------------------------------------------------------------------
  // AI processing — AgentRouter → ToolExecutor (agentic) OR GLM chat
  // (UNCHANGED from before — this is the "AI" half, not voice transfer)
  // ---------------------------------------------------------------------------

  Future<void> _processUtteranceWithTranscript(String transcript) async {
    _setState(RingPipelineState.thinking);
    // Keep user's spoken words in liveTranscript — post status to liveAiResponse
    _liveAiResponseController.add('Searching AI…');

    String chatReply = '';
    AgentRoute route = const AgentRoute(toolName: 'none', isNone: true);

    try {
      // ── Step 1: Route via AgentRouterService (fast local + Fireworks GLM) ──
      debugPrint('[RingVoice] Routing: "$transcript"');
      route = await AgentRouterService.instance.route(transcript);
      debugPrint(
        '[RingVoice] Route: ${route.toolName} | args: ${route.arguments}',
      );

      if (route.isNone) {
        // ── Conversational reply ─────────────────────────────────────────────
        final quickReply = route.reply;
        if (quickReply != null && quickReply.isNotEmpty) {
          chatReply = quickReply;
        } else {
          chatReply = await _fireworksChat(transcript);
        }
        if (chatReply.trim().isEmpty) {
          chatReply = 'How can I help you?';
        }
        debugPrint('[RingVoice] Chat reply: "$chatReply"');
        _liveAiResponseController.add(chatReply);
      } else {
        // ── Execute agentic tool via ToolExecutorService ─────────────────────
        _liveAiResponseController.add('Doing: ${route.toolName}…');
        debugPrint('[RingVoice] Executing tool: ${route.toolName}');

        final sb = StringBuffer();
        await for (final chunk in _executor.execute(
          transcript,
          detectedTool: route.toolName,
          preExtractedParam: route.param,
        )) {
          sb.write(chunk);
        }
        chatReply = sb.toString().trim();
        if (chatReply.isEmpty) chatReply = 'Done!';
        debugPrint('[RingVoice] Tool result: "$chatReply"');
        _liveAiResponseController.add(chatReply);
      }

      final result = RingPipelineResult(
        transcript: transcript,
        route: route,
        chatReply: chatReply,
        timestamp: DateTime.now(),
      );
      _resultController.add(result);
      await _sendReplyToRing(result);
    } catch (e, st) {
      debugPrint('[RingVoice] Fatal error: $e\n$st');
      chatReply = 'Sorry, something went wrong.';
      _liveAiResponseController.add(chatReply);
    } finally {
      _processingUtterance = false;
      _setState(RingPipelineState.idle);
      _stopRingMicIfPhoneInitiated();
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Uint8List _buildWav(Uint8List pcm, {
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final dataSize = pcm.length;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final hdr = ByteData(44);

    hdr.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    hdr.setUint32(4, 36 + dataSize, Endian.little);
    hdr.setUint32(8, 0x57415645, Endian.big); // "WAVE"
    hdr.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    hdr.setUint32(16, 16, Endian.little);
    hdr.setUint16(20, 1, Endian.little); // PCM
    hdr.setUint16(22, channels, Endian.little);
    hdr.setUint32(24, sampleRate, Endian.little);
    hdr.setUint32(28, byteRate, Endian.little);
    hdr.setUint16(32, blockAlign, Endian.little);
    hdr.setUint16(34, bitsPerSample, Endian.little);
    hdr.setUint32(36, 0x64617461, Endian.big); // "data"
    hdr.setUint32(40, dataSize, Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setRange(0, 44, hdr.buffer.asUint8List());
    out.setRange(44, 44 + dataSize, pcm);
    return out;
  }

  double _rmsEnergy(Uint8List pcm) {
    if (pcm.length < 2) return 0.0;
    final samples = pcm.length ~/ 2;
    double sum = 0;
    final view = ByteData.view(pcm.buffer, pcm.offsetInBytes, pcm.lengthInBytes);
    for (int i = 0; i < samples; i++) {
      final s = view.getInt16(i * 2, Endian.little);
      sum += s * s;
    }
    return (math.sqrt(sum / samples) / 4000.0).clamp(0.0, 1.0);
  }

  /// Emit "Ring audio received: X.Xs (N KB)" — throttled to ~10/s.
  void _emitDiagnostics() {
    final now = DateTime.now();
    if (now.difference(_lastDiagEmit).inMilliseconds < 100) return;
    _lastDiagEmit = now;
    final bytes = _pcmAccumulator.length;
    final seconds = (bytes / _kBytesPerSecond).toStringAsFixed(1);
    final kb = (bytes / 1024).toStringAsFixed(0);
    _diagnosticsController.add('Ring audio received: ${seconds}s ($kb KB)');
  }

  Future<String> _fireworksChat(String query) async {
    try {
      final body = jsonEncode({
        'model': _kFireworksModel,
        'max_tokens': 800,
        'top_k': 40,
        'temperature': 0.5,
        'messages': [
          {'role': 'system', 'content': _kChatSys},
          {'role': 'user', 'content': query},
        ],
      });
      final resp = await http
          .post(
            Uri.parse(_kFireworksUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_kFireworksKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        return (decoded['choices']?[0]?['message']?['content'] as String?)
                ?.trim() ??
            '';
      }
    } catch (e) {
      debugPrint('[RingVoice] GLM error: $e');
    }
    return '';
  }

  Future<void> _sendReplyToRing(RingPipelineResult result) async {
    final caption = result.chatReply ?? 'OK';
    await RingReplySender.instance.sendCaption(caption);
    try {
      await RingReplySender.instance.sendTextAsAudio(caption);
    } catch (e) {
      debugPrint('[RingVoice] TTS error: $e');
    }
  }

  void _setState(RingPipelineState s) {
    _state = s;
    _stateController.add(s);
  }

  // ---------------------------------------------------------------------------
  // Manual triggers (UI buttons)
  // ---------------------------------------------------------------------------

  /// Finalize whatever ring audio is buffered right now (Stop & Send button).
  void finalizeNow() {
    if (_isStreamingFromRing && !_processingUtterance) {
      debugPrint('[RingVoice] Manual finalize requested');
      _finalizeSpeech();
    }
  }

  Future<void> triggerManualSpeechStart() async {
    if (_phoneMicActive) return;
    _phoneMicActive = true;
    _setState(RingPipelineState.listening);
    _liveTranscriptController.add('Listening via phone mic…');
    debugPrint('[RingVoice] Phone mic listening started');

    await PhoneMicSTT.instance.startListening(
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 2),
      onResult: (transcript) async {
        _phoneMicActive = false;
        debugPrint('[RingVoice] Phone mic transcript: "$transcript"');
        if (transcript.trim().isNotEmpty) {
          _liveTranscriptController.add(transcript);
          _processingUtterance = true;
          await _processUtteranceWithTranscript(transcript);
        } else {
          _setState(RingPipelineState.idle);
        }
      },
    );
  }

  Future<void> triggerManualSpeechEnd() async {
    if (_phoneMicActive) {
      _phoneMicActive = false;
      await PhoneMicSTT.instance.stopListening();
    }
    if (_pcmAccumulator.length > 0 || _isStreamingFromRing) {
      _silenceTimer?.cancel();
      _finalizeSpeech();
    }
  }

  /// Process direct text query (typed in chat screen) — also uses AgentRouter
  Future<void> processTextQuery(String text) async {
    if (text.trim().isEmpty) return;
    _processingUtterance = true;
    _liveTranscriptController.add(text);
    await _processUtteranceWithTranscript(text);
  }
}
