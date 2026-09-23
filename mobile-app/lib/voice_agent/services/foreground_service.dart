import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:convert';
import 'package:flutter_overlay_window/flutter_overlay_window.dart'
    as overlay_window;

import 'audio_service.dart';
import 'model_manager.dart';

// ── Called in background isolate by the foreground task ──────────
@pragma('vm:entry-point')
void foregroundTaskCallback() {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(_ZeroAirTaskHandler());
}

class _ZeroAirTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint(
      'Zero Air Debug: Foreground service TaskHandler onStart at $timestamp',
    );

    // Broadcast transcripts back to main isolate
    ZeroAudioService.instance.transcriptStream.listen((text) {
      FlutterForegroundTask.sendDataToMain(
        jsonEncode({"type": "transcript", "text": text}),
      );
    });

    // Bug #15 support: Broadcast debug logs to main isolate for the debug panel
    ZeroAudioService.instance.debugStream.listen((text) {
      FlutterForegroundTask.sendDataToMain(
        jsonEncode({"type": "debug", "text": text}),
      );
    });

    // Launch overlay immediately upon wake word detection
    ZeroAudioService.instance.wakeStream.listen((keyword) async {
      debugPrint(
        "Zero Air Debug: Wake word caught in background isolate. Triggering LiveOverlayWidget.",
      );
      try {
        final isOverlayActive =
            await overlay_window.FlutterOverlayWindow.isActive();
        if (!isOverlayActive) {
          await overlay_window.FlutterOverlayWindow.showOverlay(
            alignment: overlay_window.OverlayAlignment.center,
            enableDrag: true,
            flag: overlay_window.OverlayFlag.focusPointer,
            visibility: overlay_window.NotificationVisibility.visibilityPublic,
            positionGravity: overlay_window.PositionGravity.auto,
            height: 450,
            width: overlay_window.WindowSize.matchParent,
          );
        }
      } catch (e) {
        debugPrint("Overlay open error: $e");
      }
    });

    // Actually start emitting debug logs
    ZeroAudioService.instance.replayStartupLogs();

    try {
      final mgr = ModelManager.instance; // Bug #7: singleton
      // Bug #16: Removed dead initRecognizer() call
      final kwsPath = await mgr.ensureKeywordsFile();
      await ZeroAudioService.instance.initKeywordSpotter(kwsPath);
      await ZeroAudioService.instance.startListening();
      debugPrint(
        'Zero Air Debug: Background audio engine successfully started.',
      );
    } catch (e, st) {
      debugPrint('Zero Air Debug: Background audio engine CRASHED: $e\n$st');
      // Bug #22: Notify user via notification that the service is in error state
      try {
        await FlutterForegroundTask.updateService(
          notificationTitle: 'Zero Air',
          notificationText:
              'Error: audio engine failed to start. Please restart.',
        );
        FlutterForegroundTask.sendDataToMain(
          jsonEncode({"type": "error", "text": 'Audio engine failed: $e'}),
        );
      } catch (_) {}
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep-alive heartbeat
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    ZeroAudioService.instance.dispose();
  }
}

// ── Public API ────────────────────────────────────────────────────
class ForegroundAudioService {
  static bool _initialized = false;

  static void _ensureInit() {
    if (_initialized) return;
    debugPrint('Zero Air Debug: Initializing FlutterForegroundTask options...');
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'zero_air_mic',
          channelName: 'Zero Air – Background Listening',
          channelDescription:
              'Keeps the microphone active so "Zero" works in the background.',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(10000),
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: false,
        ),
      );
      _initialized = true;
      debugPrint('Zero Air Debug: FlutterForegroundTask init successful.');
    } catch (e, st) {
      debugPrint('Zero Air Debug: FlutterForegroundTask init FAILED: $e\n$st');
    }
  }

  /// Start the foreground service (shows persistent notification).
  static Future<void> start() async {
    _ensureInit();
    debugPrint(
      'Zero Air Debug: Attempting to startService() on FlutterForegroundTask...',
    );
    try {
      final result = await FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: 'Zero Air',
        notificationText: 'Listening for "Zero"…',
        callback: foregroundTaskCallback,
      );
      debugPrint('Zero Air Debug: startService returned: $result');
    } catch (e, st) {
      debugPrint('Zero Air Debug: startService FAILED: $e\n$st');
      rethrow;
    }
  }

  /// Update the notification text (e.g. when woken by wake word).
  static Future<void> update(String text) async {
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Zero Air',
        notificationText: text,
      );
    } catch (e) {
      debugPrint('Zero Air Debug: updateService failed (ignored): $e');
    }
  }

  /// Stop the foreground service.
  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }

  static Future<bool> get isRunning async {
    _ensureInit();
    return await FlutterForegroundTask.isRunningService;
  }
}
