// ring_constants.dart — Zero Ring BLE protocol constants
// All UUIDs, characteristic roles, and command strings in one place.
// Never hardcode these outside of this file.

/// Base service UUID advertised by the ring.
const String kRingServiceUuid = '6e400001-0000-1000-8000-00805f9b34fb';

/// Ring device name used for scan filter.
const String kRingDeviceName = 'Zero';

// ── Characteristic UUIDs ─────────────────────────────────────────────────────

/// Ring → Phone  NOTIFY  Raw 16 kHz mono PCM audio chunks (mic input).
const String kCharMicAudio = '6e400002-0000-1000-8000-00805f9b34fb';

/// Phone → Ring  WRITE   Raw 16 kHz mono PCM audio chunks (AI speech reply).
const String kCharAiReply = '6e400003-0000-1000-8000-00805f9b34fb';

/// Phone → Ring  WRITE   ASCII command strings (see [RingCommand]).
const String kCharCommand = '6e400004-0000-1000-8000-00805f9b34fb';

/// Phone → Ring  WRITE   UTF-8 caption / subtitle text.
const String kCharCaption = '6e400005-0000-1000-8000-00805f9b34fb';

/// Ring → Phone  NOTIFY  Chunked binary media (photo/video/audio).
const String kCharMedia = '6e400006-0000-1000-8000-00805f9b34fb';

/// Ring → Phone  NOTIFY  Air-mouse deltas [dx, dy] signed bytes at ~30–60 Hz.
const String kCharAirMouse = '6e400007-0000-1000-8000-00805f9b34fb';

/// Standard BLE CCCD descriptor UUID — must be written to enable NOTIFY.
const String kCccdUuid = '00002902-0000-1000-8000-00805f9b34fb';

// ── Command strings written to [kCharCommand] ────────────────────────────────

/// Ring captures a still photo and streams it back via [kCharMedia].
const String kCmdTakePhoto = 'take_photo';

/// Ring starts recording video, streams frames via [kCharMedia].
const String kCmdRecordVideo = 'record_video';

/// Ends an in-progress video/audio recording.
const String kCmdStopRecord = 'stop_record';

/// Records a raw audio clip (not a note) for playback.
const String kCmdRecordAudio = 'record_audio';

/// Records audio tagged as a note — app routes through STT and stores as text.
const String kCmdTakeNote = 'take_note';

// ── Protocol constants ────────────────────────────────────────────────────────

/// Requested MTU — yields ~512 usable bytes per write after BLE overhead.
const int kMtuRequest = 517;

/// Safe chunk size for caption / audio-reply writes (leaves BLE overhead room).
const int kChunkSize = 500;

/// Silence timeout before end-of-speech is declared (milliseconds).
/// 1200ms: fast enough for voice commands, long enough for natural pauses.
const int kSilenceTimeoutMs = 1200;

/// Minimum raw PCM bytes needed before silence triggers processing.
/// 16kHz × 2 bytes/sample × 0.5s = 16 000 bytes — avoids triggering on noise.
const int kMinSpeechBytes = 16000;

/// RMS energy below this level is treated as silence (16-bit PCM, 0–32767).
const double kSilenceRmsThreshold = 150.0;

/// MethodChannel name for BLE operations (native ↔ Dart).
const String kBleChannel = 'com.example.zero_ring/ble';

/// EventChannel name for BLE events (native → Dart stream).
const String kBleEventChannel = 'com.example.zero_ring/ble_events';
