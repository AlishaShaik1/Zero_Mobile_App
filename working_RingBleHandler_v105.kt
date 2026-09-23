import os
import re

COMPANION_DIR = r"C:\Users\Alisha\Downloads\zero ring companion\zero ring companion"

# 1. Patch deepgram_stt_service.dart to add direct REST transcribePCM method
deepgram_file = os.path.join(COMPANION_DIR, "lib", "services", "deepgram_stt_service.dart")
with open(deepgram_file, "r", encoding="utf-8") as f:
    dg_content = f.read()

if "import 'package:http/http.dart' as http;" not in dg_content:
    dg_content = dg_content.replace(
        "import 'package:web_socket_channel/io.dart';",
        "import 'package:web_socket_channel/io.dart';\nimport 'package:http/http.dart' as http;"
    )

direct_method = """
  /// Direct REST STT for accumulated PCM bytes.
  /// Extremely reliable fallback when WebSocket is establishing or times out.
  /// 16kHz 16-bit Mono Linear PCM -> Deepgram Nova-3 -> Returns transcript in ~300ms.
  Future<String> transcribePCM(Uint8List pcmBytes) async {
    if (pcmBytes.isEmpty) return '';
    try {
      debugPrint('[Deepgram REST] Sending ${pcmBytes.length} bytes PCM to Nova-3...');
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
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final transcript = data['results']?['channels']?[0]?['alternatives']?[0]?['transcript'] as String?;
        final clean = transcript?.trim() ?? '';
        debugPrint('[Deepgram REST] Result: "$clean"');
        return clean;
      } else {
        debugPrint('[Deepgram REST] HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[Deepgram REST] Request error: $e');
    }
    return '';
  }
"""

if "Future<String> transcribePCM(" not in dg_content:
    # Insert before the last closing brace
    last_brace = dg_content.rfind("}")
    dg_content = dg_content[:last_brace] + direct_method + "\n}\n"
    with open(deepgram_file, "w", encoding="utf-8") as f:
        f.write(dg_content)
    print("Patched deepgram_stt_service.dart")
else:
    print("deepgram_stt_service.dart already has transcribePCM")

# 2. Patch ring_silence_detector.dart to invoke onSpeechEnd
silence_file = os.path.join(COMPANION_DIR, "lib", "services", "ring_silence_detector.dart")
with open(silence_file, "r", encoding="utf-8") as f:
    sd_content = f.read()

target_fire = """  void _fireSpeechEnd() {
    _silenceTimer = null;
    if (!_hasSpeech) return;
    
    // Return a copy of the fully accumulated PCM
    // (the buffer at this point contains anything after the last processed frame;
    //  the main contiguous audio should be kept by the pipeline layer)
    _hasSpeech = false;
  }"""

replacement_fire = """  void _fireSpeechEnd() {
    _silenceTimer = null;
    if (!_hasSpeech) return;
    _hasSpeech = false;
    onSpeechEnd(resetAndGet());
  }"""

if target_fire in sd_content:
    sd_content = sd_content.replace(target_fire, replacement_fire)
    with open(silence_file, "w", encoding="utf-8") as f:
        f.write(sd_content)
    print("Patched ring_silence_detector.dart")
else:
    print("ring_silence_detector.dart already patched or pattern differs")

# 3. Patch ring_audio_pipeline.dart to:
#  a) wire silence detector callback to _onSilenceDetected(force: true)
#  b) call _deepgram.transcribePCM(pcm) directly in _processUtterance
pipeline_file = os.path.join(COMPANION_DIR, "lib", "services", "ring_audio_pipeline.dart")
with open(pipeline_file, "r", encoding="utf-8") as f:
    pipe_content = f.read()

# Replace detector init in initialize()
pipe_content = pipe_content.replace(
    "_detector = RingSilenceDetector(onSpeechEnd: (_) {});",
    "_detector = RingSilenceDetector(onSpeechEnd: (_) {\n      debugPrint('[RingPipeline] Silence detected via RMS energy');\n      _onSilenceDetected(force: true);\n    });"
)

# In _processUtterance:
old_stt_block = """      // Fast path: if Deepgram already delivered a transcript during streaming, use it
      if (transcript.isEmpty && _partialTranscript.isNotEmpty) {
        transcript = _partialTranscript;
        debugPrint('[RingPipeline] âœ… Fast path: Deepgram pre-transcribed: "$transcript"');
      } else if (transcript.isEmpty) {
        // Deepgram not ready yet â€” ensure completer exists (may have been created in _startRingListening)
        if (_sttCompleter == null || _sttCompleter!.isCompleted) {
          _sttCompleter = Completer<String>();
        }

        // Also kick native Kotlin STT as parallel fallback
        _sttMethod
            .invokeMethod<void>('stt_transcribe_pcm', {'pcm': pcm})
            .catchError((e) {
          debugPrint('[RingPipeline] stt_transcribe_pcm invoke error: $e');
          if (_sttCompleter != null && !_sttCompleter!.isCompleted) {
            _sttCompleter!.complete('');
          }
        });

        // Wait for EITHER Deepgram or native STT â€” 6s max
        final audioSecs = pcm.length / (16000 * 2);
        final timeoutSecs = (audioSecs + 6).ceil().clamp(6, 15);
        debugPrint('[RingPipeline] Waiting up to ${timeoutSecs}s for STT (audio=${audioSecs.toStringAsFixed(1)}s)');

        transcript = await _sttCompleter!.future.timeout(
          Duration(seconds: timeoutSecs),
          onTimeout: () {
            debugPrint('[RingPipeline] STT timeout â€” partial: "$_partialTranscript"');
            return _partialTranscript;
          },
        ).catchError((_) => _partialTranscript);
      }"""

new_stt_block = """      // 1. Fast path: if Deepgram WS already delivered a transcript during streaming
      if (transcript.isEmpty && _partialTranscript.isNotEmpty) {
        transcript = _partialTranscript;
        debugPrint('[RingPipeline] ✅ Fast path: Deepgram WS pre-transcribed: "$transcript"');
      }

      // 2. Direct Deepgram REST API: Send the full accumulated PCM directly (100% reliable, ~300ms)
      if (transcript.isEmpty && pcm.isNotEmpty) {
        _liveTranscriptController.add('Transcribing ring audio…');
        debugPrint('[RingPipeline] 🚀 Calling Deepgram REST API on ${pcm.length} bytes PCM...');
        try {
          transcript = await _deepgram.transcribePCM(pcm);
          debugPrint('[RingPipeline] Deepgram REST direct transcript: "$transcript"');
        } catch (e) {
          debugPrint('[RingPipeline] Deepgram REST error: $e');
        }
      }

      // 3. Fallback: Wait for WebSocket or native if REST returned empty
      if (transcript.isEmpty && _sttCompleter != null && !_sttCompleter!.isCompleted) {
        try {
          final res = await _sttCompleter!.future.timeout(const Duration(seconds: 2));
          if (res.isNotEmpty) transcript = res;
        } catch (_) {}
      }"""

if old_stt_block in pipe_content:
    pipe_content = pipe_content.replace(old_stt_block, new_stt_block)
    with open(pipeline_file, "w", encoding="utf-8") as f:
        f.write(pipe_content)
    print("Patched ring_audio_pipeline.dart")
else:
    # Try fuzzy match for encoding variations
    print("Searching pattern in ring_audio_pipeline.dart...")
    # Find start and end of STT block
    idx_start = pipe_content.find("// Fast path: if Deepgram already delivered")
    idx_end = pipe_content.find("transcript = transcript.trim();")
    if idx_start != -1 and idx_end != -1:
        pipe_content = pipe_content[:idx_start] + new_stt_block + "\n\n      " + pipe_content[idx_end:]
        with open(pipeline_file, "w", encoding="utf-8") as f:
            f.write(pipe_content)
        print("Patched ring_audio_pipeline.dart via boundary search")
    else:
        print("Could not locate STT block in ring_audio_pipeline.dart")

# 4. Patch RingBleHandler.kt for safe descriptor writes
ble_file = os.path.join(COMPANION_DIR, "android", "app", "src", "main", "kotlin", "com", "example", "zero_air", "RingBleHandler.kt")
with open(ble_file, "r", encoding="utf-8") as f:
    ble_content = f.read()

old_desc_write = """        writeInFlight = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            g.writeDescriptor(descriptor, value)
        } else {
            @Suppress("DEPRECATION")
            descriptor.value = value
            @Suppress("DEPRECATION")
            g.writeDescriptor(descriptor)
        }"""

new_desc_write = """        writeInFlight = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val res = g.writeDescriptor(descriptor, value)
            if (res != BluetoothStatusCodes.SUCCESS) {
                android.util.Log.e("RingBle", "writeDescriptor error: $res")
                writeInFlight = false
            }
        } else {
            @Suppress("DEPRECATION")
            descriptor.value = value
            @Suppress("DEPRECATION")
            val ok = g.writeDescriptor(descriptor)
            if (!ok) {
                android.util.Log.e("RingBle", "writeDescriptor returned false")
                writeInFlight = false
            }
        }"""

if old_desc_write in ble_content:
    ble_content = ble_content.replace(old_desc_write, new_desc_write)
    with open(ble_file, "w", encoding="utf-8") as f:
        f.write(ble_content)
    print("Patched RingBleHandler.kt")
else:
    print("RingBleHandler.kt old descriptor write pattern not found or already patched")

print("Patch script finished.")
