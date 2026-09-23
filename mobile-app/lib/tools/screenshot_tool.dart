import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

/// Screenshot Tool — immediate single-step trigger.
/// No LLM needed: when routed here, capture immediately.
///
/// Android 2026 note:
///   Android 9+ requires MediaProjection + user consent dialog + ForegroundService
///   (foregroundServiceType="mediaProjection") for external/third-party screenshot capture.
///   The native `take_screenshot` handler must:
///     1. Start a MediaProjection foreground service (declared in AndroidManifest).
///     2. Show the system consent dialog if not already granted.
///     3. Write the frame via VirtualDisplay + ImageReader to gallery.
///   Permission is persisted for the session; re-asks if process restarts.
class ScreenshotTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  ScreenshotTool() : super('screenshot');

  // No LLM call needed — always "capture"
  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async => 'capture';

  @override
  Future<String> executeNative(String promptBOutput) async {
    try {
      // Native side handles MediaProjection lifecycle and returns saved file path.
      final path = await _channel.invokeMethod<String>('take_screenshot');
      return path != null && path.isNotEmpty
          ? 'success:$path'
          : 'failure:no_path';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      return '📸 Screenshot saved to your gallery.';
    }
    if (executionResult == 'failure:no_path') {
      return '📸 Screenshot taken but could not get the file path. Check your gallery.';
    }
    return 'Could not take a screenshot. Make sure the app has the Screen Capture permission.';
  }
}
