import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startBackgroundKwsTask() {
  FlutterForegroundTask.setTaskHandler(BackgroundKwsTaskHandler());
}

class BackgroundKwsTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, dynamic taskStarter) async {
    debugPrint('[BackgroundKws] Background voice service started.');
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isEngineShutdown) async {
    debugPrint('[BackgroundKws] Background voice service stopped.');
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('[BackgroundKws] Notification button $id pressed');
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}
}
