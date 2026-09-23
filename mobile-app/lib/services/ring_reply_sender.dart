// ring_reply_sender.dart — Sends AI replies back to the Zero Ring via BLE.
//
// Three reply types:
//   1. Caption text  → kCharCaption  (UTF-8, chunked with seq-byte prefix)
//   2. Audio PCM     → kCharAiReply  (not supported — falls back to caption)
//   3. Command       → kCharCommand  (ASCII command string, e.g. "take_photo")
//
// All writes delegate to RingBleService._writeChunked() / sendCommand().

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;

import '../voice_agent/services/tts_service.dart';
import 'ring_ble_service.dart';
import 'ring_constants.dart';

class RingReplySender {
  RingReplySender._();
  static final RingReplySender instance = RingReplySender._();

  final RingBleService _ble = RingBleService.instance;

  // ── Caption ─────────────────────────────────────────────────────────────

  /// Send a UTF-8 caption string to the ring screen.
  /// Automatically chunked at [kChunkSize] bytes with seq-byte prefix.
  Future<void> sendCaption(String text) async {
    if (!_ble.isConnected || text.isEmpty) return;
    await _ble.sendCaption(text);
    debugPrint(
      '[RingReply] Caption sent: "${text.substring(0, text.length.clamp(0, 60))}…"',
    );
  }

  // ── Command ─────────────────────────────────────────────────────────────

  /// Send an ASCII command to the ring (e.g. kCmdTakePhoto, kCmdRecordVideo).
  /// Use the [kCmd*] constants from ring_constants.dart.
  Future<void> sendCommand(String cmd) async {
    if (!_ble.isConnected) return;
    await _ble.sendCommand(cmd);
    debugPrint('[RingReply] Command sent: $cmd');
  }

  // ── Audio ────────────────────────────────────────────────────────────────

  /// Synthesise [text] via the existing sherpa_onnx TTS engine and send
  /// the raw 16-bit PCM to the ring's AI Speech Reply characteristic.
  ///
  /// Falls back to sending only the caption if TTS is unavailable.
  Future<void> sendTextAsAudio(String text) async {
    if (!_ble.isConnected || text.isEmpty) return;

    // First send caption so the ring has instant text feedback
    await sendCaption(text);

    // Try to get PCM from the shared TTS engine
    final pcm = await _synthesizePcm(text);
    if (pcm != null && pcm.isNotEmpty) {
      await _ble.sendAudioReply(pcm);
      debugPrint('[RingReply] Audio sent: ${pcm.length} bytes');
    }
  }

  /// Synthesise text using sherpa_onnx and return raw 16-bit PCM bytes.
  /// Returns null if TTS is not initialized.
  Future<Uint8List?> _synthesizePcm(String text) async {
    // Access the shared TtsService instance; if sherpa_onnx is available use it.
    // We call the internal _tts directly via the public generate API indirection
    // since TtsService doesn't expose raw PCM directly.
    // Workaround: we instantiate a temporary generate call on the shared engine.
    try {
      // Get the sherpa engine from TtsService via the side-effect-free path.
      // The engine is already initialized and cached by TtsService.instance.
      final engine = _getSherpaEngine();
      if (engine == null) return null;

      final audio = engine.generate(text: text, sid: 0, speed: 1.0);
      final samples = audio.samples; // Float32List
      final sampleRate = audio.sampleRate; // typically 22050

      // Resample to 16 kHz if needed (ring expects 16 kHz)
      final pcm16k = sampleRate == 16000
          ? _float32ToInt16(samples)
          : _resampleAndConvert(samples, sampleRate, 16000);

      return pcm16k;
    } catch (e) {
      debugPrint('[RingReply] TTS synthesis error: $e');
      return null;
    }
  }

  // ── PCM helpers ──────────────────────────────────────────────────────────

  /// Convert Float32 normalized samples → 16-bit signed PCM bytes (little-endian).
  static Uint8List _float32ToInt16(Float32List samples) {
    final out = Uint8List(samples.length * 2);
    final view = ByteData.view(out.buffer);
    for (int i = 0; i < samples.length; i++) {
      int s = (samples[i] * 32767).round().clamp(-32768, 32767);
      view.setInt16(i * 2, s, Endian.little);
    }
    return out;
  }

  /// Linear decimation resample from [srcRate] to [dstRate].
  /// Good enough for 22050→16000 (speech); not quality-critical for ring speaker.
  static Uint8List _resampleAndConvert(
    Float32List src,
    int srcRate,
    int dstRate,
  ) {
    final ratio = srcRate / dstRate;
    final outLen = (src.length / ratio).floor();
    final out = Uint8List(outLen * 2);
    final view = ByteData.view(out.buffer);
    for (int i = 0; i < outLen; i++) {
      final srcIdx = (i * ratio).floor().clamp(0, src.length - 1);
      int s = (src[srcIdx] * 32767).round().clamp(-32768, 32767);
      view.setInt16(i * 2, s, Endian.little);
    }
    return out;
  }

  // ── Engine access ─────────────────────────────────────────────────────────

  /// Returns null — Sherpa TTS removed; BLE audio falls back to caption-only.
  static dynamic _getSherpaEngine() {
    try {
      return TtsService.instance.rawEngine; // always null now
    } catch (_) {
      return null;
    }
  }
}
