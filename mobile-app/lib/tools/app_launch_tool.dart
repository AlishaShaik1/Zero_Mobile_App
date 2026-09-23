import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/chain_runner.dart';

/// App Launch Tool — extracts app name → native channel fuzzy-matches installed packages.
class AppLaunchTool extends BaseTool {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  AppLaunchTool() : super('app_launch');

  @override
  Future<String> executePromptB(
    ModelService modelService,
    String userMessage,
  ) async {
    return await modelService.extractSingleField(
      fieldName: 'app name to launch or open on the device',
      toolName: 'launch_app',
      userMessage: userMessage,
      maxTokens: 15,
    );
  }

  @override
  Future<String> executeNative(String promptBOutput) async => 'delegated';

  @override
  Future<String> execute(
    ModelService modelService,
    SearchService searchService,
    String userMessage, {
    String? preExtractedParam,
  }) async {
    final String appName;
    if (preExtractedParam != null && preExtractedParam.isNotEmpty) {
      appName = preExtractedParam;
    } else {
      appName = (await executePromptB(modelService, userMessage)).trim();
    }
    if (appName.isEmpty) return 'Could not determine which app to launch.';

    try {
      await _channel.invokeMethod('launch_app', {'app_name': appName});
      return '📱 Launching $appName.';
    } catch (e) {
      return '❌ Could not launch $appName: $e';
    }
  }
}
