import 'package:flutter/services.dart';
import '../services/search_service.dart';
import '../services/model_service.dart';
import '../services/chain_runner.dart';

/// Camera Tool — two-step execution.
/// LLM Call 1 (executePromptB): detect intent → "front" (selfie) or "rear" (photo).
/// Native (executeNative): fires ACTION_IMAGE_CAPTURE intent with lens facing hint.
///
/// Android 2026 note:
///   android.intent.extras.CAMERA_FACING (0=rear, 1=front) and
///   android.intent.extra.USE_FRONT_CAMERA (API 36+) are passed as best-effort hints.
///   Stock Android Camera / Google Camera respects these on most devices.
///   Samsung OneUI may ignore them — user can flip camera manually if needed.
class CameraTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  CameraTool() : super('camera');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    // Fast regex pass: "selfie" → front, else → rear
    final lower = userMessage.toLowerCase();
    if (RegExp(
      r'\b(selfie|front\s*cam|front\s*camera|facing\s*me)\b',
    ).hasMatch(lower)) {
      return 'front';
    }
    if (RegExp(
      r'\b(photo|pic|picture|rear|back\s*cam|take\s*a\s*shot)\b',
    ).hasMatch(lower)) {
      return 'rear';
    }

    // LLM Call 1: only if regex doesn't catch it
    final raw = await modelService.generateOneShot(
      'The user wants to take a photo. Reply ONLY with exactly one word: front or rear.\n'
          'If they say selfie, front-facing, or facing me → front. Otherwise → rear.',
      'USER: "$userMessage"\nCAMERA SIDE:',
      maxTokens: 5,
    );
    return raw.trim().toLowerCase().contains('front') ? 'front' : 'rear';
  }

  @override
  Future<String> executeNative(String promptBOutput) async {
    final isFront = promptBOutput.trim() == 'front';
    try {
      // take_photo_timed: opens camera then auto-clicks shutter after 2s via Accessibility
      await _channel.invokeMethod<dynamic>('take_photo_timed', {
        'front': isFront,
        'delay_ms': 2000,
      });
      return 'success:${isFront ? "front" : "rear"}';
    } catch (e) {
      return 'failure:$e';
    }
  }

  @override
  Future<String> execute(
    ModelService modelService,
  // ignore: avoid_renaming_method_parameters
    SearchService search,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    final String action;
    if (preExtractedParam != null && preExtractedParam.isNotEmpty) {
      action = preExtractedParam.trim().toLowerCase();
    } else {
      action = await executePromptB(modelService, userMessage);
    }
    final result = await executeNative(action);
    return confirmResult(userMessage, result);
  }

  @override
  String confirmResult(String userMessage, String executionResult) {
    if (executionResult.startsWith('success:')) {
      final parts = executionResult.split(':');
      final side = parts.length > 1 ? parts[1] : 'rear';
      return side == 'front'
          ? '🤳 Front camera opened — taking selfie in 2 seconds!'
          : '📷 Camera opened — taking photo in 2 seconds!';
    }
    return 'Could not open the camera. Make sure the app has camera permission.';
  }
}
