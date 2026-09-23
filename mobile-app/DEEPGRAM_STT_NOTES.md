# Deepgram STT — Research Note (saved 2026-09-02)

## Winner: Deepgram over AssemblyAI for Real-Time STT

### AssemblyAI — BLOCKED for free accounts on streaming
- Real-time streaming API requires credit card verification even for free tier
- $50 credit is real but **streaming specifically needs card first** → 402 error
- Not viable for frictionless dev setup

### Deepgram — CLEAR WINNER
- **$200 free credit, NO credit card required** (~12,000 minutes real-time)
- Nova-3 model: sub-200ms latency, excellent accuracy
- Pay-as-you-go starts at $200 free, no minimum spend
- 4x more free credit than AssemblyAI, no streaming block

## Flutter Integration (Tested Pattern)

```yaml
# pubspec.yaml
dependencies:
  web_socket_channel: ^3.0.1
```

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';

class DeepgramSTT {
  static const _apiKey = 'YOUR_DEEPGRAM_API_KEY';
  IOWebSocketChannel? _ws;
  Function(String)? onTranscript;

  void start() {
    // 16kHz, 16-bit signed PCM, mono — exactly what Zero Ring sends
    final uri = Uri.parse(
      'wss://api.deepgram.com/v1/listen'
      '?model=nova-3'
      '&encoding=linear16'
      '&sample_rate=16000'
      '&channels=1'
      '&interim_results=true'
    );
    _ws = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Token $_apiKey'},
    );
    _ws!.stream.listen((data) {
      final json = jsonDecode(data as String);
      final transcript = json['channel']?['alternatives']?[0]?['transcript'];
      if (transcript != null && transcript.isNotEmpty) {
        onTranscript?.call(transcript);
      }
    }, onError: (e) => print('WS error: $e'));
  }

  // BLE gives you Uint8List → send directly, no conversion needed
  void sendPCM(Uint8List bleChunk) => _ws?.sink.add(bleChunk);

  void stop() {
    _ws?.sink.add(jsonEncode({'type': 'CloseStream'}));
    _ws?.sink.close();
  }
}
```

## Why this works perfectly with Zero Ring
- Deepgram accepts raw Uint8List PCM directly — no base64 encoding
- `linear16 + 16000` matches Ring firmware output exactly
- Auth is in HTTP header (not WS protocol field) → no 402
- `IOWebSocketChannel` works on Android with standard headers

## Setup
1. Sign up at deepgram.com
2. Console → Create API Key
3. Paste key → done in 2 min

## TODO: Replace current on-device STT (Kotlin SpeechRecognizer) with Deepgram
- Current: BLE PCM → WAV file → Kotlin SpeechRecognizer (on-device, slow, English-only)
- Better: BLE PCM chunks → Deepgram WebSocket (cloud, multilingual, 200ms latency)
- Integration point: ring_audio_pipeline.dart _onBleEvent()

## API Key
DEEPGRAM_API_KEY=36dd865f774bfe84b2044e54f9b7c3f175a10634
