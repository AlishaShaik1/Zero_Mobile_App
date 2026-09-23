// ring_silence_detector.dart — Pure-Dart RMS energy silence detector
//
// Usage:
//   final detector = RingSilenceDetector(onSpeechEnd: (pcm) { ... });
//   detector.addChunk(rawPcmBytes);   // call for every BLE mic chunk
//   detector.reset();                  // call before a new voice session

import 'dart:async';
import 'dart:math' show sqrt;
import 'dart:typed_data';
import 'ring_constants.dart';

/// Fired when silence following speech is detected.
/// [pcm] is the accumulated 16 kHz mono 16-bit PCM since the last reset.
typedef SpeechEndCallback = void Function(Uint8List pcm);

class RingSilenceDetector {
  RingSilenceDetector({
    required this.onSpeechEnd,
    int silenceTimeoutMs = kSilenceTimeoutMs,
    this._silenceThreshold = kSilenceRmsThreshold,
  })  : _silenceTimeout = Duration(milliseconds: silenceTimeoutMs);

  final SpeechEndCallback onSpeechEnd;
  final Duration _silenceTimeout;
  final double _silenceThreshold;

  // Rolling 20 ms frames at 16 kHz = 320 samples = 640 bytes per frame.
  static const int _frameBytes = 640;

  final _buffer = BytesBuilder(copy: false);
  Timer? _silenceTimer;
  bool _hasSpeech = false;

  /// Feed raw 16-bit PCM bytes from the ring's mic characteristic.
  void addChunk(Uint8List chunk) {
    _buffer.add(chunk);
    _processFrames();
  }

  void _processFrames() {
    final buffered = _buffer.toBytes();
    int offset = 0;

    while (offset + _frameBytes <= buffered.length) {
      final frame = buffered.sublist(offset, offset + _frameBytes);
      final rms = _computeRms(frame);

      if (rms > _silenceThreshold) {
        _hasSpeech = true;
        // Reset silence countdown on every speech frame
        _silenceTimer?.cancel();
        _silenceTimer = null;
      } else if (_hasSpeech && _silenceTimer == null) {
        // Speech was active; start counting silence
        _silenceTimer = Timer(_silenceTimeout, _fireSpeechEnd);
      }

      offset += _frameBytes;
    }

    // Keep unprocessed tail
    if (offset < buffered.length) {
      final tail = buffered.sublist(offset);
      _buffer.clear();
      _buffer.add(tail);
    } else {
      _buffer.clear();
      // Re-add everything to maintain state since BytesBuilder is consumed on toBytes
    }
  }

  void _fireSpeechEnd() {
    _silenceTimer = null;
    if (!_hasSpeech) return;
    _hasSpeech = false;
    onSpeechEnd(resetAndGet());
  }

  /// Reset state for a new utterance. Returns accumulated PCM bytes so far.
  Uint8List resetAndGet() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _hasSpeech = false;
    final out = _buffer.toBytes();
    _buffer.clear();
    return Uint8List.fromList(out);
  }

  void reset() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _hasSpeech = false;
    _buffer.clear();
  }

  bool get hasSpeech => _hasSpeech;

  // ── RMS calculation ────────────────────────────────────────────────────────

  /// Compute root-mean-square energy of a 16-bit LE PCM frame.
  static double _computeRms(Uint8List frame) {
    final data = ByteData.view(frame.buffer, frame.offsetInBytes, frame.length);
    final sampleCount = frame.length ~/ 2;
    if (sampleCount == 0) return 0;

    double sum = 0;
    for (int i = 0; i < sampleCount; i++) {
      final s = data.getInt16(i * 2, Endian.little).toDouble();
      sum += s * s;
    }
    return sqrt(sum / sampleCount);
  }

  void dispose() {
    _silenceTimer?.cancel();
  }
}
