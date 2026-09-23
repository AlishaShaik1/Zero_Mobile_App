// pipeline_service.dart — orchestrates multi-tool execution chains
import 'model_service.dart';
import 'search_service.dart';
import 'chain_runner.dart';
import 'tool_registry.dart';
import '../tools/flashlight_tool.dart';
import '../tools/wifi_tool.dart';
import '../tools/brightness_tool.dart';
import '../tools/volume_tool.dart';
import '../tools/screenshot_tool.dart';
import '../tools/timer_tool.dart';
import '../tools/alarm_tool.dart';
import '../tools/email_tool.dart';
import '../tools/sms_tool.dart';
import '../tools/whatsapp_tool.dart';
import '../tools/call_tool.dart';
import '../tools/clipboard_tool.dart';
import '../tools/share_tool.dart';
import '../tools/contacts_tool.dart';
import '../tools/app_launch_tool.dart';
import '../tools/calendar_tool.dart';
import '../tools/settings_tool.dart';
import '../tools/hotspot_tool.dart';
import '../tools/bluetooth_tool.dart';
import '../tools/airplane_mode_tool.dart';
import '../tools/dnd_tool.dart';
import '../tools/search_tool.dart';
import '../tools/play_music_tool.dart';
import '../tools/camera_tool.dart';
import '../tools/memory_tool.dart';
import '../tools/datetime_tool.dart';
import '../tools/recording_tool.dart';
import '../tools/browser_tool.dart';

class OrchestrationPipeline {
  final ModelService _model;
  final SearchService _search;
  late final ChainRunner _chainRunner;

  OrchestrationPipeline(this._model, this._search) {
    _chainRunner = ChainRunner(_model, _search, [
      FlashlightTool(),
      WifiTool(),
      BrightnessTool(),
      VolumeTool(),
      ScreenshotTool(),
      CameraTool(),
      TimerTool(),
      AlarmTool(),
      EmailTool(),
      SmsTool(),
      WhatsappTool(),
      CallTool(),
      ClipboardTool(),
      ShareTool(),
      ContactsTool(),
      AppLaunchTool(),
      CalendarTool(),
      SettingsTool(),
      HotspotTool(),
      BluetoothTool(),
      AirplaneModeTool(),
      DndTool(),
      PlayMusicTool(),
      SearchTool(),
      MemoryTool(),
      DateTimeTool(),
      RecordingTool(),
      BrowserTool(),
    ]);
  }

  Stream<String> run(
    String userMessage, {
    List<String>? presetTools,
    String? presetParam,
    Map<String, dynamic>? injectedArgs,
  }) async* {
    List<String> toolsToRun = presetTools ?? [];

    if (toolsToRun.isEmpty) {
      yield '// Planning multi-action sequence…\n';
      toolsToRun = await _model.extractPlanArray(userMessage, const [
        'flashlight',
        'wifi',
        'bluetooth',
        'hotspot',
        'airplane_mode',
        'dnd',
        'brightness',
        'volume',
        'screenshot',
        'camera',
        'timer',
        'alarm',
        'email',
        'whatsapp',
        'call',
        'sms',
        'calendar',
        'contacts',
        'clipboard',
        'share',
        'settings',
        'app_launch',
        'play_music',
        'ui_automate',
        'search',
        'recording',
        'camera',
      ]);
    }

    if (toolsToRun.isEmpty) {
      yield '// No tools identified. Falling back to chat.\n\n';
      await for (final delta in _model.chat(userMessage)) {
        if (delta is ContentDelta) yield delta.text;
      }
      return;
    }

    yield '// Executing: ${toolsToRun.join(', ')}\n';

    final results = <String>[];
    for (var name in toolsToRun) {
      if (name == 'search_web') name = 'search';
      if (name == 'remember') name = 'memory';
      if (name == 'time') name = 'datetime';
      if (name == 'app') name = 'app_launch';

      // 1. Direct high-speed execution using the precise JSON parameters
      // from the router, completely bypassing secondary prompts.
      final directTool = ToolRegistry.tools[name];
      if (directTool != null) {
        try {
          // Pass the traced JSON arguments. If none, pass the fallback param map.
          final argsToPass =
              injectedArgs ??
              (presetParam != null
                  ? {
                      'value': presetParam,
                      'state': presetParam,
                      'query': presetParam,
                    }
                  : {});

          final r = await directTool.handler(argsToPass);
          results.add(r);
          yield '$r\n';
          continue; // Successfully executed directly!
        } catch (e) {
          results.add('$name failed: $e');
          yield '$name failed: $e\n';
          break;
        }
      }

      // 2. Legacy fallback for tools not yet migrated to ToolRegistry
      if (!_chainRunner.hasTool(name)) {
        results.add('$name: not found');
        continue;
      }

      try {
        final r = await _chainRunner.executeTool(
          name,
          userMessage,
          preExtractedParam: presetParam,
        );
        results.add(r);
        yield '$r\n';
      } catch (e) {
        results.add('$name failed: $e');
        yield '$name failed: $e\n';
        break;
      }
    }
  }
}
