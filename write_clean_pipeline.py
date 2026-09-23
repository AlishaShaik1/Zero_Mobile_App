import sys

TARGET = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion\lib\services\ring_audio_pipeline.dart'

CONTENT = """\
// ring_audio_pipeline.dart
//
// RING TO PHONE VOICE TRANSFER  (rebuilt from scratch)
//
// DESIGN (simple and reliable):
//   1. Ring firmware captures mic audio, sends raw PCM chunks over BLE
//      (CHAR_MIC_AUDIO / 0x6e400002)
//   2. BLE EventChannel delivers 'audio' events to Dart
//   3. We accumulate all chunks in a BytesBuilder
//   4. After 1.5s of silence (no new chunks), we wrap the PCM in a WAV
//      header and POST it to Deepgram REST - transcript arrives in ~300ms
//   5. Transcript is displayed on the phone screen (liveTranscript stream)
//      and forwarded to GLM AI - reply sent back to ring OLED
//
// ONLY the voice-transfer part has been rebuilt.
// Everything else (BLE connection, tools, chat UI) is unchanged.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'agent_router_service.dart';
import 'phone_mic_stt_service.dart';
import 'ring_ble_service.dart';
import 'ring_reply_sender.dart';

// Result / State types

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

// Keys

const _kDeepgramKey    = 'bf8e5c0fbe1d38a88cda424c00213dc8e0e70fc0';
const _kFireworksKey   = 'fw_3iUKfhBn2vryacJynHPsUU';
const _kFireworksModel = 'accounts/fireworks/models/glm-5p3-flash';
const _kFireworksUrl   = 'https://api.fireworks.ai/inference/v1/chat/completions';
const _kChatSys =
    'You are Zero, a fast AI voice assistant on a smart ring. '
    'Keep replies under 2 short sentences. Be concise, direct, and helpful.';

// =============================================================================
// RingAudioPipeline
// =============================================================================

class RingAudioPipeline {
  RingAudioPipeline._();
  static final RingAudioPipeline instance = RingAudioPipeline._();

  // State
  bool _active = false;
  bool get isActive => _active;

  RingPipelineState _state = RingPipelineState.idle;
  RingPipelineState get state => _state;
  bool get isListening  => _state == RingPipelineState.listening;
  bool get isProcessing =>
      _state == RingPipelineState.transcribing ||
      _state == RingPipelineState.thinking     ||
      _state == RingPipelineState.replying;
  bool get isStreamingFromRing => _isStreamingFromRing || isListening;

  bool _isStreamingFromRing = false;
  bool _processingUtterance = false;

  // PCM accumulator - all BLE audio chunks collected here
  final _pcmAccumulator = BytesBuilder(copy: false);
  Timer? _silenceTimer;

  // Streams
  final _resultController         = StreamController<RingPipelineResult>.broadcast();
  final _energyController         = StreamController<double>.broadcast();
  final _liveTranscriptController = StreamController<String>.broadcast();
  final _liveAiResponseController = StreamController<String>.broadcast();
  final _stateController          = StreamController<RingPipelineState>.broadcast();

  Stream<RingPipelineResult> get results       => _resultController.stream;
  Stream<double>             get energyStream   => _energyController.stream;
  Stream<String>             get liveTranscript => _liveTranscriptController.stream;
  Stream<String>             get liveAiResponse => _liveAiResponseController.stream;
  Stream<RingPipelineState>  get stateStream    => _stateController.stream;

  StreamSubscription? _bleSubscription;

  bool _phoneMicActive = false;
  bool get isPhoneMicListening => _phoneMicActive;

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    start();
    debugPrint('[RingPipeline] Initialized - ring mic -> Deepgram REST -> phone screen');
  }

  void start() {
    if (_active) return;
    _active = true;
    _pcmAccumulator.clear();
    _bleSubscription?.cancel();
    _bleSubscription = RingBleService.instance.events.listen(_onBleEvent);
    debugPrint('[RingPipeline] BLE event listener active');
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
  }

  // ---------------------------------------------------------------------------
  // BLE Event Router
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
    _isStreamingFromRing = false;
    _processingUtterance = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _pcmAccumulator.clear();
    _setState(RingPipelineState.idle);
  }

  // ---------------------------------------------------------------------------
  // Audio Chunk Handler - VOICE TRANSFER ENTRY POINT
  // ---------------------------------------------------------------------------

  void _handleAudioChunk(Uint8List pcm) {
    // Control markers from firmware:
    //   0xFF = mic start (double-click gesture on ring)
    //   0xFE = mic stop  (single-click gesture on ring)
    if (pcm.length == 1 && pcm[0] == 0xFF) {
      if (!_isStreamingFromRing && !_processingUtterance) {
        _startRingListening();
      }
      return;
    }
    if (pcm.length == 1 && pcm[0] == 0xFE) {
      if (_isStreamingFromRing && !_processingUtterance) {
        debugPrint('[RingPipeline] Stop marker received - finalizing');
        _finalizeSpeech();
      }
      return;
    }

    if (pcm.isEmpty) return;

    // First real audio without start marker -> auto-start
    if (!_isStreamingFromRing && !_processingUtterance) {
      _startRingListening();
    }

    _pcmAccumulator.add(pcm);
    _energyController.add(_rmsEnergy(pcm));
    _resetSilenceTimer();
  }

  void _startRingListening() {
    _isStreamingFromRing = true;
    _pcmAccumulator.clear();
    _setState(RingPipelineState.listening);
    _liveTranscriptController.add('Listening...');
    debugPrint('[RingPipeline] Ring mic streaming started');
  }

  // ---------------------------------------------------------------------------
  // Silence Detection
  // ---------------------------------------------------------------------------

  void _resetSilenceTimer() {
    if (_processingUtterance) return;
    _silenceTimer?.cancel();
    // 1.5 s of silence -> declare end of speech
    _silenceTimer = Timer(
      const Duration(milliseconds: 1500),
      _finalizeSpeech,
    );
  }

  void _finalizeSpeech() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    if (_processingUtterance || !_active) return;

    final pcmBytes = _pcmAccumulator.length;
    // Need at least 200ms of audio (6400 bytes at 16 kHz 16-bit mono)
    if (pcmBytes < 6400) {
      debugPrint('[RingPipeline] Too little audio ($pcmBytes bytes) - ignoring');
      _isStreamingFromRing = false;
      _pcmAccumulator.clear();
      _setState(RingPipelineState.idle);
      return;
    }

    _isStreamingFromRing = false;
    _processingUtterance = true;

    final pcm = Uint8List.fromList(_pcmAccumulator.toBytes());
    _pcmAccumulator.clear();
    debugPrint('[RingPipeline] Speech end - \${pcm.length} PCM bytes -> Deepgram REST');

    _transcribeAndProcess(pcm);
  }

  // ---------------------------------------------------------------------------
  // Voice Transfer Core: PCM -> Deepgram REST -> Transcript
  // ---------------------------------------------------------------------------

  Future<void> _transcribeAndProcess(Uint8List pcm) async {
    _setState(RingPipelineState.transcribing);
    _liveTranscriptController.add('Transcribing...');

    String transcript = '';

    try {
      // Wrap raw PCM in a 44-byte WAV header
      final wav = _buildWav(pcm);
      debugPrint('[RingPipeline] Sending \${wav.length} bytes WAV to Deepgram REST...');

      final response = await http.post(
        Uri.parse(
          'https://api.deepgram.com/v1/listen'
          '?model=nova-3'
          '&smart_format=true'
          '&language=en-US',
        ),
        headers: {
          'Authorization': 'Token \$_kDeepgramKey',
          'Content-Type': 'audio/wav',
        },
        body: wav,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['results']?['channels']?[0]
            ?['alternatives']?[0]?['transcript'] as String?;
        transcript = raw?.trim() ?? '';
        debugPrint('[RingPipeline] Deepgram transcript: "\$transcript"');
      } else {
        debugPrint(
          '[RingPipeline] Deepgram HTTP \${response.statusCode}: '
          '\${response.body.substring(0, response.body.length.clamp(0, 200))}',
        );
      }
    } catch (e) {
      debugPrint('[RingPipeline] Deepgram REST error: \$e');
    }

    // Show on phone - even if empty, so UI updates
    if (transcript.isEmpty) {
      _liveTranscriptController.add('(Could not recognise - please try again)');
      _processingUtterance = false;
      _setState(RingPipelineState.idle);
      return;
    }

    // Show transcript on phone - THIS IS WHAT THE USER SEES
    _liveTranscriptController.add(transcript);

    // Continue to AI response
    await _processUtteranceWithTranscript(transcript);
  }

  // ---------------------------------------------------------------------------
  // AI Processing - direct GLM chat
  // ---------------------------------------------------------------------------

  Future<void> _processUtteranceWithTranscript(String transcript) async {
    _setState(RingPipelineState.thinking);

    String chatReply = '';

    try {
      chatReply = await _fireworksChat(transcript);

      if (chatReply.trim().isEmpty) {
        chatReply = 'Sorry, could not get a response. Please try again!';
      }

      debugPrint('[RingPipeline] Final reply: "\$chatReply"');
      _liveAiResponseController.add(chatReply);

      final result = RingPipelineResult(
        transcript: transcript,
        route: const AgentRoute(toolName: 'none', isNone: true),
        chatReply: chatReply,
        timestamp: DateTime.now(),
      );
      _resultController.add(result);
      await _sendReplyToRing(result);
    } catch (e, st) {
      debugPrint('[RingPipeline] Fatal error: \$e\\n\$st');
    } finally {
      _processingUtterance = false;
      _setState(RingPipelineState.idle);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Uint8List _buildWav(Uint8List pcm, {
    int sampleRate    = 16000,
    int channels      = 1,
    int bitsPerSample = 16,
  }) {
    final dataSize   = pcm.length;
    final byteRate   = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final hdr        = ByteData(44);

    hdr.setUint32(0,  0x52494646, Endian.big);
    hdr.setUint32(4,  36 + dataSize, Endian.little);
    hdr.setUint32(8,  0x57415645, Endian.big);
    hdr.setUint32(12, 0x666d7420, Endian.big);
    hdr.setUint32(16, 16,          Endian.little);
    hdr.setUint16(20, 1,           Endian.little);
    hdr.setUint16(22, channels,    Endian.little);
    hdr.setUint32(24, sampleRate,  Endian.little);
    hdr.setUint32(28, byteRate,    Endian.little);
    hdr.setUint16(32, blockAlign,  Endian.little);
    hdr.setUint16(34, bitsPerSample, Endian.little);
    hdr.setUint32(36, 0x64617461, Endian.big);
    hdr.setUint32(40, dataSize,    Endian.little);

    final out = Uint8List(44 + dataSize);
    out.setRange(0,  44,            hdr.buffer.asUint8List());
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

  Future<String> _fireworksChat(String query) async {
    try {
      final body = jsonEncode({
        'model':       _kFireworksModel,
        'max_tokens':  800,
        'top_k':       40,
        'temperature': 0.5,
        'messages': [
          {'role': 'system', 'content': _kChatSys},
          {'role': 'user',   'content': query},
        ],
      });
      final resp = await http.post(
        Uri.parse(_kFireworksUrl),
        headers: {
          'Accept':        'application/json',
          'Content-Type':  'application/json',
          'Authorization': 'Bearer \$_kFireworksKey',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        return (decoded['choices']?[0]?['message']?['content'] as String?)
                ?.trim() ?? '';
      }
    } catch (e) {
      debugPrint('[RingPipeline] GLM error: \$e');
    }
    return '';
  }

  Future<void> _sendReplyToRing(RingPipelineResult result) async {
    final caption = result.chatReply ?? 'OK';
    await RingReplySender.instance.sendCaption(caption);
    try {
      await RingReplySender.instance.sendTextAsAudio(caption);
    } catch (e) {
      debugPrint('[RingPipeline] TTS error: \$e');
    }
  }

  void _setState(RingPipelineState s) {
    _state = s;
    _stateController.add(s);
  }

  // ---------------------------------------------------------------------------
  // Manual triggers (UI buttons - phone mic)
  // ---------------------------------------------------------------------------

  Future<void> triggerManualSpeechStart() async {
    if (_phoneMicActive) return;
    _phoneMicActive = true;
    _setState(RingPipelineState.listening);
    _liveTranscriptController.add('Listening via phone mic...');
    debugPrint('[RingPipeline] Phone mic listening started');

    await PhoneMicSTT.instance.startListening(
      listenFor: const Duration(seconds: 12),
      pauseFor: const Duration(seconds: 2),
      onResult: (transcript) async {
        _phoneMicActive = false;
        debugPrint('[RingPipeline] Phone mic transcript: "\$transcript"');
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

  /// Process direct text query (typed in chat screen)
  Future<void> processTextQuery(String text) async {
    if (text.trim().isEmpty) return;
    _processingUtterance = true;
    _liveTranscriptController.add(text);
    _setState(RingPipelineState.thinking);
    try {
      final reply = await _fireworksChat(text);
      final result = RingPipelineResult(
        transcript: text,
        route: const AgentRoute(toolName: 'none', isNone: true),
        chatReply: reply.isNotEmpty ? reply : 'No response.',
        timestamp: DateTime.now(),
      );
      _resultController.add(result);
      _liveAiResponseController.add(result.chatReply!);
      await _sendReplyToRing(result);
    } finally {
      _processingUtterance = false;
      _setState(RingPipelineState.idle);
    }
  }
}
"""

with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(CONTENT)

print(f'Written {len(CONTENT)} chars to {TARGET}')
# Quick sanity check - count braces
opens = CONTENT.count('{')
closes = CONTENT.count('}')
print(f'Brace check: {{ count={opens}, }} count={closes}')
