// deepgram_stt_service.dart
// Real-time Deepgram Nova-3 STT over WebSocket.
// Replaces on-device Kotlin SpeechRecognizer for streaming transcription.
// $200 free credit, no card needed. 200ms latency, multilingual.
//
// Usage: ring_audio_pipeline.dart calls sendPCM() on each BLE audio chunk.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

class DeepgramSTT {
  static const _apiKey = '36dd865f774bfe84b2044e54f9b7c3f175a10634';

  // Nova-3: best accuracy, multilingual, 200ms endpointing for fast detection
  static const _wsUri =
      'wss://api.deepgram.com/v1/listen'
      '?model=nova-3'
      '&encoding=linear16'
      '&sample_rate=16000'
      '&channels=1'
      '&interim_results=true'
      '&endpointing=200'
      '&utterance_end_ms=800';

  IOWebSocketChannel? _ws;
  StreamSubscription? _sub;
  bool _connected = false;
  bool _shouldBeConnected = false;

  // Buffer PCM while connecting (prevents dropped audio)
  final _pendingPcm = <Uint8List>[];

  /// Called on every transcript (partial + final)
  Function(String text, bool isFinal)? onTranscript;

  /// Called on error
  Function(dynamic error)? onError;

  bool get isConnected => _connected;

  // ─── Connect ────────────────────────────────────────────────────────────────
  void start() {
    _shouldBeConnected = true;
    if (_connected) return;
    _connect();
  }

  void _connect() {
    if (!_shouldBeConnected) return;
    try {
      _ws = IOWebSocketChannel.connect(
        Uri.parse(_wsUri),
        headers: {'Authorization': 'Token $_apiKey'},
        connectTimeout: const Duration(seconds: 5),
      );
      _connected = true;
      debugPrint('[Deepgram] WebSocket connected');

      // Flush any buffered PCM from before connection was ready
      if (_pendingPcm.isNotEmpty) {
        for (final chunk in _pendingPcm) {
          _ws!.sink.add(chunk);
        }
        debugPrint('[Deepgram] Flushed ${_pendingPcm.length} buffered chunks');
        _pendingPcm.clear();
      }

      _sub = _ws!.stream.listen(
        _onData,
        onError: (e) {
          debugPrint('[Deepgram] WS error: $e');
          _connected = false;
          onError?.call(e);
          if (_shouldBeConnected) {
            Future.delayed(const Duration(milliseconds: 500), _connect);
          }
        },
        onDone: () {
          debugPrint('[Deepgram] WS closed');
          _connected = false;
          if (_shouldBeConnected) {
            Future.delayed(const Duration(milliseconds: 300), _connect);
          }
        },
      );
    } catch (e) {
      _connected = false;
      debugPrint('[Deepgram] Connect error: $e');
      onError?.call(e);
      if (_shouldBeConnected) {
        Future.delayed(const Duration(seconds: 1), _connect);
      }
    }
  }

  // ─── Send raw PCM from BLE directly (Uint8List, no base64) ─────────────────
  void sendPCM(Uint8List pcmChunk) {
    if (!_connected || _ws == null) {
      if (_pendingPcm.length < 500) {
        _pendingPcm.add(pcmChunk);
      }
      return;
    }
    try {
      _ws!.sink.add(pcmChunk);
    } catch (e) {
      debugPrint('[Deepgram] Send error: $e');
    }
  }

  // ─── Stop ───────────────────────────────────────────────────────────────────
  void stop() {
    _shouldBeConnected = false;
    _pendingPcm.clear();
    if (!_connected) return;
    try {
      _ws?.sink.add(jsonEncode({'type': 'CloseStream'}));
      _ws?.sink.close();
    } catch (_) {}
    _sub?.cancel();
    _connected = false;
    debugPrint('[Deepgram] Stopped');
  }

  // ─── Parse Deepgram response ─────────────────────────────────────────────────
  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;

      if (json['type'] == 'UtteranceEnd') {
        debugPrint('[Deepgram] UtteranceEnd received');
        return;
      }

      final isFinal = (json['is_final'] as bool?) ?? false;
      final speechFinal = (json['speech_final'] as bool?) ?? false;
      final transcript = json['channel']
          ?['alternatives']
          ?[0]
          ?['transcript'] as String?;

      if (transcript != null && transcript.isNotEmpty) {
        debugPrint('[Deepgram] ${isFinal ? "FINAL" : "partial"}: "$transcript"');
        onTranscript?.call(transcript, isFinal || speechFinal);
      }
    } catch (e) {
      debugPrint('[Deepgram] Parse error: $e');
    }
  }

  /// Build a proper 44-byte WAV header for raw PCM data.
  /// Deepgram REST accepts both raw PCM (with query params) and WAV.
  /// WAV is more universally compatible.
  static Uint8List _buildWav(Uint8List pcm, {int sampleRate = 16000, int channels = 1, int bitsPerSample = 16}) {
    final dataSize = pcm.length;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final header = ByteData(44);

    // RIFF chunk
    header.setUint32(0, 0x52494646, Endian.big);   // "RIFF"
    header.setUint32(4, 36 + dataSize, Endian.little); // chunk size
    header.setUint32(8, 0x57415645, Endian.big);   // "WAVE"

    // fmt sub-chunk
    header.setUint32(12, 0x666d7420, Endian.big);  // "fmt "
    header.setUint32(16, 16, Endian.little);        // sub-chunk size
    header.setUint16(20, 1, Endian.little);         // PCM = 1
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data sub-chunk
    header.setUint32(36, 0x64617461, Endian.big);  // "data"
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcm);
    return result;
  }

  /// Direct REST STT for accumulated PCM bytes.
  /// Sends audio wrapped in WAV header for maximum compatibility.
  /// 16kHz 16-bit Mono Linear PCM -> Deepgram Nova-3 -> Returns transcript in ~300ms.
  Future<String> transcribePCM(Uint8List pcmBytes) async {
    if (pcmBytes.isEmpty) return '';
    try {
      // Wrap raw PCM in WAV header for reliable Deepgram REST processing
      final wavBytes = _buildWav(pcmBytes);
      debugPrint('[Deepgram REST] Sending ${wavBytes.length} bytes (WAV) to Nova-3 (${pcmBytes.length} PCM bytes)...');

      final uri = Uri.parse(
        'https://api.deepgram.com/v1/listen'
        '?model=nova-3'
        '&smart_format=true',
      );
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'audio/wav',
        },
        body: wavBytes,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript = data['results']?['channels']?[0]?['alternatives']?[0]?['transcript'] as String?;
        final clean = transcript?.trim() ?? '';
        debugPrint('[Deepgram REST] Result: "$clean"');
        return clean;
      } else {
        debugPrint('[Deepgram REST] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
        // Fallback: try with raw PCM + encoding params
        return await _transcribePCMRaw(pcmBytes);
      }
    } catch (e) {
      debugPrint('[Deepgram REST] WAV request error: $e — trying raw PCM fallback');
      return await _transcribePCMRaw(pcmBytes);
    }
  }

  /// Fallback: send raw PCM with encoding query params (original approach)
  Future<String> _transcribePCMRaw(Uint8List pcmBytes) async {
    try {
      final uri = Uri.parse(
        'https://api.deepgram.com/v1/listen'
        '?model=nova-3'
        '&encoding=linear16'
        '&sample_rate=16000'
        '&channels=1'
        '&smart_format=true',
      );
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Token $_apiKey',
          'Content-Type': 'application/octet-stream',
        },
        body: pcmBytes,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript = data['results']?['channels']?[0]?['alternatives']?[0]?['transcript'] as String?;
        final clean = transcript?.trim() ?? '';
        debugPrint('[Deepgram REST raw] Result: "$clean"');
        return clean;
      } else {
        debugPrint('[Deepgram REST raw] HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      }
    } catch (e) {
      debugPrint('[Deepgram REST raw] Error: $e');
    }
    return '';
  }
}
