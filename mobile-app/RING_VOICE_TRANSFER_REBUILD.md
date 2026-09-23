# Ring → Phone Voice Transfer — Full Rebuild (2026-09-23)

Everything else (BLE connection, camera, captions, AI tools, chat) is
**unchanged**. Only the ring → phone voice path was removed and rebuilt.

## What was removed

| Old part | Why it was removed |
|---|---|
| `RingSttHandler.kt` (native `SpeechRecognizer` + ParcelFileDescriptor pipe) | Required an on-device speech service. On phones where it's missing/broken Android reports "not installed" style errors — and feeding custom PCM through it is unreliable across ROMs. **Deleted.** |
| `BackgroundRingProcessor` `SpeechRecognizer` pipe | Same problem when the app is in the background. Replaced with cloud STT (Deepgram REST via OkHttp). |
| Double `EventChannel` subscription in `RingBleService` | `initialize()` was called from `main.dart` **and** the ring screens → every audio chunk was delivered twice → the pipeline double-counted audio. Now guarded. |
| Fragile `data is Uint8List` codec check | Audio could be silently dropped if the codec delivered a plain `List<int>`. Now accepts both. |
| Old phone button flow ("Start Listen" → phone mic) | The button listened on the **phone** mic while you spoke into the **ring** → "Listening…" with no text. Now starts the **ring** mic when the ring is connected (phone mic only as fallback when no ring). |

## New flow (one path, no moving parts)

```
Ring double-tap (or 2s hold, or phone "Start Listen")
        │  firmware sends: 0xFF  → PCM chunks (16 kHz mono) → 0xFE
        ▼
Kotlin RingBleHandler  ──►  Dart RingAudioPipeline  (only place voice is handled)
        │                        │
        │  (app in background:   │  accumulates PCM
        │   BackgroundRing       │  live counter shown on screen
        │   Processor does the   ▼
        │   same job natively)  Deepgram REST (WAV)  →  transcript
        │                        │
        │                        ▼
        │                 text appears on phone ("You: …")
        │                        │
        └────────────────────────┴► existing agentic brain (unchanged)
                                      → reply → ring OLED caption + TTS
```

- End of speech = `0xFE` marker (button release), or 1.8 s of silence, or 30 s cap.
- Works with or without firmware markers (auto-start on first chunk).
- No Android `SpeechRecognizer` anywhere → no "not installed" errors, works on every device.
- Deepgram tries **2 API keys × 2 models** in order — one expired key can't kill the feature.

## Firmware changes (re-flash the ring with `zero_ring_firmware.ino` or `firmware`)

1. `start_listen` / `stop_record` BLE commands — so the phone's
   "Start Listen" button can start/stop the ring mic.
2. Silence auto-stop: 2.5 s of silence ends the session and sends the `0xFE`
   marker (a session can no longer sit on "Listening…" forever).
3. The older `firmware` copy gained the `0xFF`/`0xFE` markers it was missing.

## Voice-link diagnostics card (below the connection card)

The companion screen now shows **which stage of the link is broken**:

| Screen says | Meaning |
|---|---|
| `Not connected — error: …` | BLE scan/connect failed — the error text says why (Bluetooth off, permissions, …) |
| `Looking for the ring…` | Scanning. Ring must be awake and not connected to another phone |
| `Connected — but mic NOT enabled` | GATT connected but NOTIFY enable failed — voice can't work until reconnect |
| `Connected — MTU N too small` | 240-byte audio chunks can't pass; the app auto-retries MTU negotiation |
| `Voice link ready — MTU 517 · mic ON` | Everything armed — double-tap and speak |

Plus, while speaking, the green line shows `Ring audio received: X.Xs (N KB)` —
live proof the ring's mic is physically reaching the phone.

Known root causes fixed in this rebuild:
- **MTU too small (23)**: Android BLE's default MTU cannot carry the ring's
  240-byte PCM notifications — NimBLE drops them silently, so the 1-byte
  "start" marker arrived (ring says Listening) but no audio ever reached the
  phone. Now: MTU negotiation is verified + retried, reported to the UI, and
  the firmware sizes chunks to the negotiated MTU as a safety net.
- **Android 12+ scan finding nothing**: `BLUETOOTH_SCAN` now declared with
  `neverForLocation` so scanning no longer depends on location permission.

## How to verify (no more blind "fixed" claims)

1. **On-screen**: open Zero Ring companion screen, press **Start Listen**
   (or hold the ring button 2 s). A green line appears:
   `Ring audio received: 2.4s (77 KB)` — this proves the ring's audio is
   physically reaching the phone.
2. **Transcript**: when you stop speaking, "You:" shows your words within ~1–2 s.
3. **logcat** (USB debug): `adb logcat -s RingBle RingVoice`
   - `Ring mic marker: START (0xFF)` / `STOP (0xFE)`
   - `Ring mic audio flowing: N chunks so far`
   - `Utterance complete: Xs → Deepgram`
   - `Deepgram OK (key#1, nova-3): "your words"` — or the exact HTTP error.

If the green counter **never moves** → the BLE audio link isn't delivering
(connection/MTU side — check logcat `RingBle` for GATT events).
If the counter moves but no transcript → the screen now shows the **exact**
STT error (e.g. `STT error: HTTP 401 (…)`), so you know it's the API key, not
the ring.

## Files changed

- `lib/services/ring_audio_pipeline.dart` — rewritten (the only voice-transfer engine)
- `lib/services/ring_ble_service.dart` — init guard + robust audio decoding
- `lib/screens/ring_companion_screen.dart` — live audio indicator, ring-mic button, correct gesture guide
- `android/.../RingBleHandler.kt` — removed dead STT routing, added audio-flow logs
- `android/.../RingSttHandler.kt` — **deleted**
- `android/.../BackgroundRingProcessor.kt` — STT replaced with Deepgram REST
- `android/.../MainActivity.kt` — STT channel wiring removed
- `zero_ring_firmware.ino` + `firmware` — start_listen/stop_record + auto-stop
