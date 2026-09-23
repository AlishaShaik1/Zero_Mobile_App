# 💍 Zero Ring & Zero Mobile App — Master Project Blueprint

> **Notice for Developers & AI Agents**:
> This document is the **single source of truth** for the entire Zero Ring ecosystem. It contains the complete architectural blueprint, end-to-end data workflows, file-by-file relationship maps, known gotchas, and exact commands to build and extract the mobile app APK. Read this file to understand the full system without needing to inspect individual files.

---

## 📑 Table of Contents
1. [Project Overview & Ecosystem](#1-project-overview--ecosystem)
2. [Quick-Start: How to Build & Extract the Mobile App APK](#2-quick-start-how-to-build--extract-the-mobile-app-apk)
3. [End-to-End System Architecture & Data Flow](#3-end-to-end-system-architecture--data-flow)
4. [Hardware & Firmware Architecture (`firmware/`)](#4-hardware--firmware-architecture)
5. [Mobile Companion App Architecture (`mobile-app/`)](#5-mobile-companion-app-architecture)
6. [Detailed File Map & Relationships](#6-detailed-file-map--relationships)
7. [Agentic Voice Execution & Tool Registry](#7-agentic-voice-execution--tool-registry)
8. [Critical Gotchas & Architecture Rules (AI Context Accelerator)](#8-critical-gotchas--architecture-rules)

---

## 1. Project Overview & Ecosystem

The **Zero Ring Ecosystem** is an ambient, wearable AI hardware and software platform comprising three interconnected layers:

```
┌─────────────────────────┐          BLE 5.0 (NimBLE)          ┌───────────────────────────┐
│     Zero Ring (HW)      │ ◄────────────────────────────────► │  Zero Mobile App (Flutter) │
│ - ESP32-S3/C3           │   - Audio Stream (I2S -> BLE)      │ - Low-Latency BLE Engine  │
│ - 0.42" OLED Display    │   - Button Events (Tap, Double)    │ - Real-Time STT (Deepgram) │
│ - I2S MEMS Microphone   │   - OLED Captions & Status         │ - Agentic Tool Execution   │
│ - Capacitive Touch Pad  │                                    │ - LLM Reasoning (Gemini)   │
└─────────────────────────┘                                    └─────────────┬─────────────┘
                                                                             │
                                                                 HTTP / API  │
                                                                             ▼
                                                               ┌───────────────────────────┐
                                                               │  Cloud & Web Services     │
                                                               │ - Next.js Landing Page    │
                                                               │ - Search APIs (Serper)    │
                                                               │ - GPU Model Inference     │
                                                               └───────────────────────────┘
```

1. **Hardware (Zero Ring)**: A miniature smart ring running custom C++ Arduino/NimBLE firmware on an ESP32 microcontroller. Equipped with an I2S digital microphone, 0.42" 128x64/72x40 OLED display, capacitive touch sensor, and lithium battery charging circuit.
2. **Mobile Companion App (`mobile-app/`)**: A cross-platform Flutter app with high-performance Android Kotlin native integration. Connects to the ring over Bluetooth Low Energy, streams voice audio, performs Speech-to-Text via Deepgram or on-device fallback, routes intents using an agentic AI router, executes system-level phone tasks (e.g., launching apps like YouTube, sending WhatsApp messages, taking camera snapshots), and pushes status captions back to the ring OLED.
3. **Web Platform (`zero-ring-landing-page/`)**: A Next.js 14 web hub providing 3D interactive hardware showcase, product specs, pre-order flow, and API documentation.

---

## 2. Quick-Start: How to Build & Extract the Mobile App APK

Follow these instructions to pull, build, and extract the Android APK from source on any development machine.

### Prerequisites
* **Flutter SDK**: Version 3.22.0 or higher ([Install Flutter](https://docs.flutter.dev/get-started/install))
* **Java Development Kit (JDK)**: JDK 17 (recommended: OpenJDK 17 or Android Studio bundled JDK)
* **Android SDK**: Android API 34 / 35 with Android SDK Build-Tools 34.0.0+
* **Git**: Installed and configured

### Step 1: Clone the Repository
```bash
git clone https://github.com/AlishaShaik1/Zero_Mobile_App.git
cd Zero_Mobile_App
```

### Step 2: Navigate to the Mobile App Directory
```bash
cd mobile-app
```

### Step 3: Install Flutter Dependencies
```bash
flutter pub get
```

### Step 4: Build the Release APK
Run the Flutter release compiler:
```bash
flutter build apk --release
```

*(Alternative via Gradle directly)*:
```bash
cd android
./gradlew assembleRelease
cd ..
```

### Step 5: Locate and Extract the Built APK
Upon successful compilation, the production release APK is generated at:
```
mobile-app/build/app/outputs/flutter-apk/app-release.apk
```
* **File Name**: `app-release.apk` (Size: ~141 MB due to bundled on-device speech models and native AI libs)
* **Version**: `1.0.12+13`

### Step 6: Transfer and Install on Your Android Phone
* **Via USB / ADB**:
  ```bash
  adb install -r build/app/outputs/flutter-apk/app-release.apk
  ```
* **Via Manual Transfer**:
  Copy `app-release.apk` to your phone via USB cable, Google Drive, or messaging, open the APK file in your phone's file manager, and tap **Install**.

### Step 7: Required Phone Permissions
On first launch, ensure the following permissions are granted in Android Settings:
* **Nearby Devices / Bluetooth**: Required for BLE scanning and connection.
* **Location**: Required by Android OS for BLE peripheral advertisement discovery.
* **Microphone**: Used for phone fallback speech input if ring audio is disconnected.

---

## 3. End-to-End System Architecture & Data Flow

### The Life of a Voice Command ("Open YouTube")

```
[User Action]
  │
  ├─► Double-tap ring touch pad
  │
[ESP32 Ring Firmware]
  │ Sets state: STATE_LISTENING
  │ OLED Displays: "LISTENING..."
  │ I2S Microphone captures 16kHz 16-bit mono PCM audio
  │ Sends audio frames over BLE Characteristic (UUID: ...2001)
  │
[Android Native BLE Layer (RingBleHandler.kt)]
  │ Receives GATT characteristic notifications
  │ Buffers raw PCM chunks and emits via Flutter EventChannel ("ring_audio_stream")
  │
[Flutter Pipeline (ring_audio_pipeline.dart)]
  │ Subscribes to audio stream
  │ Streams audio chunks to Deepgram Real-time WebSocket (DeepgramSttService)
  │ Fallback: If ring mic is offline, PhoneMicSttService captures audio
  │ Receives transcription events -> "open youtube"
  │
[UI Display (ring_companion_screen.dart)]
  │ Transcript Card displays: "open youtube"
  │ (RULE: Transcript remains visible permanently; NEVER wiped by status text)
  │
[User Press Button Once (or 1.5s Voice Silence Detector triggers)]
  │ Ring state -> STATE_THINKING (OLED: "THINKING...")
  │
[Intent Classifier & Agent Router (agent_router_service.dart)]
  │ Fast pattern matching matches "open youtube" -> Action: "app_launch", Package: "com.google.android.youtube"
  │
[Execution (MainActivity.kt via MethodChannel)]
  │ Calls Android PackageManager -> startActivity(Intent for YouTube)
  │ Phone screen launches YouTube App!
  │
[Ring OLED Feedback (ring_reply_sender.dart)]
  │ App sends OLED caption text: "Launching YouTube…" via BLE TX Characteristic
  │ Ring OLED updates from "THINKING..." to "Launching YouTube…"
```

---

## 4. Hardware & Firmware Architecture

### Directory: `firmware/` & Root `.ino` Files
* **`zero_ring_firmware.ino`**: Production ESP32 firmware.
  * **BLE Protocol**: Uses `NimBLE-Arduino` for minimal memory footprint and fast reconnection.
  * **Service UUID**: `19B10000-E8F2-537E-4F6C-D104768A1214`
  * **Characteristics**:
    * `...2001` (NOTIFY): Raw PCM voice audio stream from I2S mic.
    * `...2002` (WRITE/WRITE_NO_RESP): Text and status commands received from phone for OLED display.
    * `...2003` (NOTIFY): Touch and button events (Single tap, Double tap, Long hold).
    * `...2004` (READ/NOTIFY): Battery level and charging state.
  * **OLED Display Engine**: Drives SSD1306/SH1106 128x64 or 72x40 monochrome screens using U8g2 / Adafruit library.
  * **Touch Controller**: Capacitive touch detection with debounce state machine:
    * *Single Tap*: Confirm / Send voice prompt / Dismiss notification.
    * *Double Tap*: Start voice listening mode.
    * *Long Hold (2s)*: Toggle sleep / wake mode.
* **`i2c_oled_scanner.ino`**: Diagnostic sketch to scan I2C bus (SDA/SCL) and detect display address (`0x3C` or `0x3D`).

---

## 5. Mobile Companion App Architecture

### Directory: `mobile-app/`
The app is constructed with a decoupled layered architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                 UI Screens & Presentation                   │
│   ring_companion_screen.dart  │  chat_screen.dart           │
│   agent_screen.dart           │  live_voice_screen.dart     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Audio & Voice Pipeline                   │
│   ring_audio_pipeline.dart   │  deepgram_stt_service.dart   │
│   phone_mic_stt_service.dart │  ring_silence_detector.dart  │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                   Agentic AI & Routing                      │
│   agent_router_service.dart  │  fast_intent_classifier.dart │
│   tool_executor_service.dart │  model_service.dart          │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│             Hardware Abstraction & Native BLE               │
│   ring_ble_service.dart (Dart) <──Method/Event Channels──>  │
│   RingBleHandler.kt (Kotlin)   <──GATT Callbacks──> Ring    │
│   MainActivity.kt (Kotlin)     <──Intents──> Android OS     │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Detailed File Map & Relationships

### `mobile-app/lib/` (Dart / Flutter Core)
| File | Responsibility | Collaborators / Called By |
| :--- | :--- | :--- |
| `main.dart` | Application entry point, multi-provider wiring, theme configuration. | Bootstraps all services. |
| `screens/ring_companion_screen.dart` | Primary dashboard. Shows BLE connection state, animated Radar Scan sheet, permanent Live Transcript card, AI response card, and battery widget. | Binds to `RingBleService` and `RingAudioPipeline`. |
| `services/ring_ble_service.dart` | High-level Dart singleton managing BLE state, permission checks (Bluetooth Scan, Connect, Location), device discovery stream, and connection requests. | Interfaces with `RingBleHandler.kt` via MethodChannel. |
| `services/ring_audio_pipeline.dart` | Central voice pipeline orchestrator. Consumes PCM audio chunks, manages real-time STT sessions, routes user transcripts, coordinates with agent router, and pushes OLED captions. | Interacts with `DeepgramSttService`, `PhoneMicSttService`, and `RingReplySender`. |
| `services/ring_reply_sender.dart` | Formats and transmits short UTF-8 caption packets over BLE to the ring OLED display characteristic. | Called by `RingAudioPipeline` and `AgentRouterService`. |
| `services/ring_silence_detector.dart` | Software Voice Activity Detector (VAD). Measures RMS audio amplitude; triggers end-of-speech after 1.5 seconds of silence. | Feeds `RingAudioPipeline`. |
| `services/deepgram_stt_service.dart` | High-performance real-time STT using Deepgram WebSocket API (`wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=16000`). | Used as primary STT engine by `RingAudioPipeline`. |
| `services/phone_mic_stt_service.dart` | On-device microphone speech recognizer used as automatic fallback when ring is not transmitting audio. | Fallback in `RingAudioPipeline`. |
| `services/agent_router_service.dart` | Two-tier intent router. (Tier 1: Fast regex/rule matcher for zero-latency device actions; Tier 2: Cloud LLM for conversational and multi-step tasks). | Triggers `ToolExecutorService` and updates UI. |
| `services/fast_intent_classifier.dart` | Deterministic offline intent parser for commands like `"open youtube"`, `"open whatsapp"`, `"take photo"`. | Called by `AgentRouterService`. |
| `services/tool_executor_service.dart` | Executes resolved tool invocations (app launch, web search, camera snapshot, contact messaging). | Calls native platform channels in `MainActivity.kt`. |
| `services/model_service.dart` | Unified AI model client supporting OpenAI, Google Gemini, GLM-4, and local LiteRT/llama models. | Used for open-ended intelligence. |
| `widgets/ring_scan_sheet.dart` | Modal bottom sheet providing radar scan visualizer with live RSSI, device filter, and one-tap connect. | Triggered from `ring_companion_screen.dart`. |

### `mobile-app/android/` (Native Android / Kotlin)
| File | Responsibility | Collaborators / Details |
| :--- | :--- | :--- |
| `MainActivity.kt` | Android `FlutterActivity`. Registers MethodChannels (`"com.example.zero_air/app_launch"`, `"com.example.zero_air/ble"`). Handles launching external applications via Android Intents. | Interacts with Flutter services. |
| `RingBleHandler.kt` | Low-level Android BLE engine. Implements `BluetoothLeScanner` in low-latency mode, handles GATT connection lifecycle, MTU negotiation, characteristic notification subscriptions, and packet transmission. | Communicates with Flutter via `EventChannel("ring_ble_events")`. |
| `AndroidManifest.xml` | Declares all required permissions (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`, `RECORD_AUDIO`). Configured without `neverForLocation` trap to allow unfiltered peripheral discovery on Android 12+. | System manifest. |

---

## 7. Agentic Voice Execution & Tool Registry

The app features an extensible Agentic Tool system. When a voice command is transcribed, it is evaluated against the tool registry:

| Tool Name | Voice Trigger Examples | Execution Action | OLED Display Feedback |
| :--- | :--- | :--- | :--- |
| **`app_launch`** | *"open youtube"*, *"launch spotify"*, *"open whatsapp"* | Resolves package name (e.g. `com.google.android.youtube`) and launches Android intent via `MainActivity.kt`. | `"Launching YouTube…"` |
| **`camera_capture`** | *"take a picture"*, *"snap photo"* | Opens phone camera or captures snapshot via CameraX API. | `"Capturing Photo…"` |
| **`web_search`** | *"who won the match"*, *"search latest news"* | Queries live search engine API and formats concise summary. | `"Searching..."` |
| **`ai_chat`** | General knowledge questions, translations, summaries | Sends prompt to LLM and speaks response via TTS. | `"Thinking..."` $\rightarrow$ `"Answer Ready"` |

---

## 8. Critical Gotchas & Architecture Rules (AI Context Accelerator)

When working on or modifying this codebase, **strictly observe the following rules** established through extensive debugging:

### Rule 1: Never add `neverForLocation` to `BLUETOOTH_SCAN`
* **Why**: In `AndroidManifest.xml`, setting `android:usesPermissionFlags="neverForLocation"` causes Android 12+ (API 31+) to silently drop ESP32 NimBLE scan advertisement and scan response packets when scans do not specify exact 128-bit service UUID filters.
* **Correct declaration**:
  ```xml
  <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
  ```

### Rule 2: Never call `refreshDeviceCache(gatt)` on connect
* **Why**: Invoking the hidden Android reflection method `gatt.refresh()` inside `BluetoothProfile.STATE_CONNECTED` tears down the internal GATT client state machine on Android 13, 14, and 15, immediately aborting service discovery.

### Rule 3: Always implement `onBatchScanResults` in BLE scanner
* **Why**: Device manufacturers (Samsung, Xiaomi, Google Pixel) optimize background battery usage by delivering BLE discovery callbacks in batches (`onBatchScanResults`). If only `onScanResult` is implemented, devices delivered in batches will be discarded.

### Rule 4: Enable characteristics immediately upon service discovery
* **Why**: Do not stall characteristic enablement waiting for `onMtuChanged`. Request MTU 517 asynchronously in the background, but immediately enable notifications on `onServicesDiscovered` to avoid connection handshake timeouts.

### Rule 5: Transcripts must NEVER be overwritten by status text
* **Why**: In `ring_audio_pipeline.dart`, recognized user speech (e.g. *"open youtube"*) must be retained permanently in `_liveTranscriptController`. Routing status messages like `"Searching AI..."` into the transcript controller clears the user's speech and confuses the user. Status text must strictly go to `_liveAiResponseController`.

### Rule 6: Large APK files (>100MB) must remain ignored in Git
* **Why**: GitHub enforces a strict 100MB file limit. Compiled APKs (`~141MB`) must always be excluded via `.gitignore` (`*.apk`). Developers build fresh APKs locally using `flutter build apk --release`.

---
*Zero Ring Project — Built for high-performance wearable intelligence.*
