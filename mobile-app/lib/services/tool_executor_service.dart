// tool_executor_service.dart — resolves params and executes single tools
import 'model_service.dart';
import 'tool_registry.dart';
import 'search_service.dart';
import 'chain_runner.dart';
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
import '../tools/recording_tool.dart';
import '../tools/search_tool.dart';
import '../tools/play_music_tool.dart';
import '../tools/camera_tool.dart';
import '../tools/memory_tool.dart';
import '../tools/datetime_tool.dart';
import '../tools/browser_tool.dart';
import 'zero_cowork_service.dart';

class ToolExecutorService {
  final ModelService _model;
  final SearchService _search;
  late final ChainRunner _chainRunner;

  ToolExecutorService(this._model, this._search) {
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

  // ── PUBLIC: single-tool stream (routing entry-point from chat_screen) ────────
  Stream<String> execute(
    String userMessage, {
    String? detectedTool,
    String? preExtractedParam,
    Map<String, dynamic>? injectedArgs,
  }) async* {
    String toolName = detectedTool ?? '';
    if (toolName.isEmpty) {
      toolName = await _llmClassifySingleTool(userMessage);
      if (toolName.isEmpty || toolName == 'chat') {
        await for (final delta in _model.chat(userMessage)) {
          if (delta is ContentDelta) yield delta.text;
        }
        return;
      }
    }

    // Normalize tool name aliases from the unified JSON classifier
    if (toolName == 'search_web') toolName = 'search';
    if (toolName == 'remember') toolName = 'memory';
    if (toolName == 'time') toolName = 'datetime';

    // ── Zero Co-work: cloud browser AI agent (zerolabs.live) ─────────────────
    if (toolName == 'zero_cowork') {
      // Extract the task from preExtractedParam or injectedArgs or raw message
      final coworkTask = preExtractedParam ??
          injectedArgs?['task']?.toString() ??
          injectedArgs?['query']?.toString() ??
          userMessage;
      yield* ZeroCoworkService.instance.execute(coworkTask);
      return;
    }

    // Normalize argument key aliases from JSON classifier output
    if (injectedArgs != null) {
      final a = Map<String, dynamic>.from(injectedArgs);
      if (toolName == 'app_launch' &&
          a.containsKey('app') &&
          !a.containsKey('app_name')) {
        a['app_name'] = a['app'];
      }
      if (toolName == 'whatsapp' &&
          a.containsKey('contact') &&
          !a.containsKey('contact_name')) {
        a['contact_name'] = a['contact'];
      }
      if (toolName == 'maps' &&
          a.containsKey('destination') &&
          !a.containsKey('query')) {
        a['query'] = a['destination'];
      }
      if ((toolName == 'volume' || toolName == 'brightness') &&
          a.containsKey('value') &&
          !a.containsKey('level')) {
        a['level'] = a['value'];
      }
      injectedArgs = a;
    }

    if (_chainRunner.hasTool(toolName)) {
      final result = await _chainRunner.executeTool(
        toolName,
        userMessage,
        preExtractedParam: preExtractedParam,
        injectedArgs: injectedArgs,
      );
      yield '\n$result';
      return;
    }

    // Attempt to map preExtractedParam into injectedArgs if tool expects a single arg
    Map<String, dynamic>? args = injectedArgs;
    if (args == null &&
        preExtractedParam != null &&
        preExtractedParam.isNotEmpty) {
      args = _mapPreExtractedToArgs(toolName, preExtractedParam);
    }

    // Fallback path (tools not in ChainRunner)
    String result;
    try {
      result = await executeStep(toolName, userMessage, injectedArgs: args);
    } catch (e) {
      result = 'Error: $e';
    }
    yield '\n$result';
  }

  Map<String, dynamic>? _mapPreExtractedToArgs(String toolName, String param) {
    switch (toolName) {
      case 'app_launch':
        return {'app_name': param};
      case 'browser':
        return {'url': param};
      case 'maps':
        return {'query': param};
      case 'call':
        return {'contact': param};
      case 'sms':
        return {'contact': param};
      case 'whatsapp':
        return {'contact_name': param, 'contact': param};
      case 'email':
        return {'to': param, 'contact': param};
      case 'settings':
        return {'setting': param};
      case 'share':
        return {'text': param};
      case 'clipboard':
        return {'text': param, 'action': param};
      case 'search':
        return {};
      case 'memory':
        return {'note': param};
      case 'recording':
        return {'state': param};
      case 'play_music':
        return {'action': param, 'query': param};
      case 'volume':
        return {'level': param, 'action': param};
      case 'flashlight':
      case 'wifi':
      case 'bluetooth':
        return {'state': param};
      default:
        return null;
    }
  }

  // ── PUBLIC: step execution (no LLM summary; used by pipeline) ───────────────
  Future<String> executeStep(
    String toolName,
    String userMessage, {
    Map<String, dynamic>? injectedArgs,
  }) async {
    // Special delegation: search uses SearchService
    if (toolName == 'search') {
      final query = _extractSearchQuery(userMessage);
      final results = await _search.search(query);
      final prompt =
          'Summarize this search data for the query "$query":\n$results';
      final sb = StringBuffer();
      await for (final delta in _model.chat(prompt)) {
        if (delta is ContentDelta) sb.write(delta.text);
      }
      return sb.toString();
    }

    // Standard registry execution
    final params = injectedArgs ?? await _resolveParams(toolName, userMessage);
    final tool = ToolRegistry.tools[toolName];
    if (tool == null) return 'Unknown tool: $toolName';
    return tool.handler(params);
  }

  // ── PARAM RESOLUTION — all 21 tools, fully written out ───────────────────────
  Future<Map<String, dynamic>> _resolveParams(
    String toolName,
    String userMessage, {
    Map<String, dynamic>? injectedArgs,
  }) async {
    // If caller already provided resolved params, use them
    if (injectedArgs != null && injectedArgs.isNotEmpty) return injectedArgs;

    final lower = userMessage.toLowerCase();

    switch (toolName) {
      // ── 1. FLASHLIGHT: regex — on/off keywords ─────────────────────────────
      case 'flashlight':
        final isOff = RegExp(
          r'\b(off|close|disable|stop|turn off)\b',
        ).hasMatch(lower);
        return {'state': isOff ? 'off' : 'on'};

      // ── 2. WIFI: no params ─────────────────────────────────────────────────
      case 'wifi':
        return {};

      // ── 3. BLUETOOTH: no params ────────────────────────────────────────────
      case 'bluetooth':
        return {};

      // ── 4. BRIGHTNESS: regex — %, keywords, numerics ──────────────────────
      case 'brightness':
        int level = 128;
        final pctMatch = RegExp(r'(\d+)\s*%').firstMatch(lower);
        if (pctMatch != null) {
          level = ((int.tryParse(pctMatch.group(1)!) ?? 50) * 255 / 100)
              .round()
              .clamp(0, 255);
        } else if (RegExp(r'\b(max|full|highest|100)\b').hasMatch(lower)) {
          level = 255;
        } else if (RegExp(r'\b(min|lowest|off|dark|0)\b').hasMatch(lower)) {
          level = 0;
        } else if (RegExp(r'\b(dim|low|25)\b').hasMatch(lower)) {
          level = 64;
        } else if (RegExp(r'\b(half|medium|50|mid)\b').hasMatch(lower)) {
          level = 128;
        } else if (RegExp(r'\b(high|75|bright)\b').hasMatch(lower)) {
          level = 192;
        } else {
          final numMatch = RegExp(r'\b(\d{1,3})\b').firstMatch(lower);
          if (numMatch != null) {
            final v = int.tryParse(numMatch.group(1)!) ?? 50;
            level = v <= 100
                ? (v * 255 / 100).round().clamp(0, 255)
                : v.clamp(0, 255);
          }
        }
        return {'level': level};

      // ── 5. VOLUME: regex — %, keywords, up/down, numerics ─────────────────
      case 'volume':
        int level = 7;
        final pctMatch = RegExp(r'(\d+)\s*%').firstMatch(lower);
        if (pctMatch != null) {
          level = ((int.tryParse(pctMatch.group(1)!) ?? 50) * 15 / 100)
              .round()
              .clamp(0, 15);
        } else if (RegExp(r'\b(max|full|highest|100)\b').hasMatch(lower)) {
          level = 15;
        } else if (RegExp(r'\b(mute|silent|off|0)\b').hasMatch(lower)) {
          level = 0;
        } else if (RegExp(r'\b(low|down|quiet|25)\b').hasMatch(lower)) {
          level = 3;
        } else if (RegExp(r'\b(half|medium|50|mid)\b').hasMatch(lower)) {
          level = 7;
        } else if (RegExp(r'\b(high|up|loud|75)\b').hasMatch(lower)) {
          level = 12;
        } else {
          final numMatch = RegExp(r'\b(\d{1,2})\b').firstMatch(lower);
          if (numMatch != null) {
            final v = int.tryParse(numMatch.group(1)!) ?? 7;
            level = v <= 15 ? v : (v * 15 / 100).round().clamp(0, 15);
          }
        }
        return {'level': level};

      // ── 6. SCREENSHOT: no params ───────────────────────────────────────────
      case 'screenshot':
        return {};

      // ── 7. TIMER: regex — number + unit ───────────────────────────────────
      case 'timer':
        final numUnit = RegExp(
          r'(\d+)\s*(min|minute|hour|hr|sec|second)',
          caseSensitive: false,
        ).firstMatch(lower);
        int minutes = 1;
        if (numUnit != null) {
          final val = int.tryParse(numUnit.group(1)!) ?? 1;
          final unit = numUnit.group(2)!.toLowerCase();
          if (unit.startsWith('hour') || unit == 'hr') {
            minutes = val * 60;
          } else if (unit.startsWith('sec')) {
            minutes = (val / 60).ceil().clamp(1, 999);
          } else {
            minutes = val;
          }
        } else {
          final bare = RegExp(r'\b(\d+)\b').firstMatch(lower);
          if (bare != null) minutes = int.tryParse(bare.group(1)!) ?? 1;
        }
        return {'duration_minutes': minutes};

      // ── 8. ALARM: regex for time offset + label ───────────────────────────
      case 'alarm':
        String title = 'Reminder';
        final titleMatch = RegExp(
          r'(?:remind(?:er)?\s+(?:me\s+)?(?:to\s+)?|alarm\s+(?:for\s+)?)(.+?)(?:\s+(?:in|at|after|for)\s+\d|\.|$)',
          caseSensitive: false,
        ).firstMatch(userMessage);
        if (titleMatch != null && titleMatch.group(1) != null) {
          title = titleMatch.group(1)!.trim();
          if (title.length > 60) title = title.substring(0, 60);
        }
        int offset = 10;
        final timeMatch = RegExp(
          r'(\d+)\s*(min|minute|hour|hr)',
          caseSensitive: false,
        ).firstMatch(lower);
        if (timeMatch != null) {
          final val = int.tryParse(timeMatch.group(1)!) ?? 10;
          final unit = timeMatch.group(2)!.toLowerCase();
          offset = (unit.startsWith('hour') || unit == 'hr') ? val * 60 : val;
        }
        return {'title': title, 'time_offset_minutes': offset};

      // ── 9. EMAIL: 3 isolated LLM field extractions ─────────────────────────
      case 'email':
        final to = await _model.extractSingleField(
          fieldName: 'recipient email or name',
          toolName: 'email',
          userMessage: userMessage,
        );
        final subject = await _model.extractSingleField(
          fieldName: 'email subject line',
          toolName: 'email',
          userMessage: userMessage,
        );
        final body = await _model.extractSingleField(
          fieldName: 'email body text',
          toolName: 'email',
          userMessage: userMessage,
          maxTokens: 150,
        );
        return {
          'to': to.isNotEmpty ? to : 'unknown',
          'subject': subject.isNotEmpty ? subject : 'Message',
          'body': body.isNotEmpty ? body : userMessage,
        };

      // ── 10. WHATSAPP: 2 isolated LLM field extractions ────────────────────
      case 'whatsapp':
        final contact = await _model.extractSingleField(
          fieldName: 'contact name or number',
          toolName: 'whatsapp',
          userMessage: userMessage,
        );
        final message = await _model.extractSingleField(
          fieldName: 'message text',
          toolName: 'whatsapp',
          userMessage: userMessage,
          maxTokens: 120,
        );
        return {
          'contact_name': contact.isNotEmpty ? contact : 'unknown',
          'message_body': message.isNotEmpty ? message : userMessage,
        };

      // ── 11. CALL: 1 LLM field extraction ──────────────────────────────────
      case 'call':
        final contact = await _model.extractSingleField(
          fieldName: 'contact name or phone number',
          toolName: 'call',
          userMessage: userMessage,
        );
        return {'contact': contact.isNotEmpty ? contact : userMessage};

      // ── 12. SMS: 2 isolated LLM field extractions ─────────────────────────
      case 'sms':
        final contact = await _model.extractSingleField(
          fieldName: 'contact name or number',
          toolName: 'sms',
          userMessage: userMessage,
        );
        final message = await _model.extractSingleField(
          fieldName: 'message text',
          toolName: 'sms',
          userMessage: userMessage,
          maxTokens: 120,
        );
        return {
          'contact': contact.isNotEmpty ? contact : 'unknown',
          'message': message.isNotEmpty ? message : userMessage,
        };

      // ── 13. BROWSER: pure LLM extraction ─────────────
      case 'browser':
        final query = await _model.extractSingleField(
          fieldName: 'URL or search query to open in browser',
          toolName: 'browser',
          userMessage: userMessage,
        );
        String url = query.isNotEmpty ? query.trim() : userMessage;
        if (!url.startsWith('http')) {
          if (url.contains('.') && !url.contains(' ')) {
            url = 'https://$url';
          } else {
            url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
          }
        }
        return {'url': url};

      // ── 14. MAPS: 1 LLM field extraction ──────────────────────────────────
      case 'maps':
        final destination = await _model.extractSingleField(
          fieldName: 'destination or place name',
          toolName: 'maps',
          userMessage: userMessage,
        );
        return {'query': destination.isNotEmpty ? destination : userMessage};

      // ── 15. APP LAUNCH: pure LLM extraction ────────────────────
      case 'app_launch':
        final appName = await _model.extractSingleField(
          fieldName: 'app name to launch',
          toolName: 'app_launch',
          userMessage: userMessage,
        );
        return {'app_name': appName.isNotEmpty ? appName : 'unknown'};

      // ── 16. SETTINGS: pure LLM extraction ────────────────
      case 'settings':
        final category = await _model.extractSingleField(
          fieldName: 'settings category name',
          toolName: 'settings',
          userMessage: userMessage,
        );
        return {'setting': category.isNotEmpty ? category : 'main'};

      // ── 17. SHARE: 1 LLM field extraction ────────────────────────────────
      case 'share':
        final text = await _model.extractSingleField(
          fieldName: 'text content to share',
          toolName: 'share',
          userMessage: userMessage,
          maxTokens: 150,
        );
        return {'text': text.isNotEmpty ? text : userMessage};

      // ── 18. CLIPBOARD: 1 LLM field extraction ─────────────────────────────
      case 'clipboard':
        final text = await _model.extractSingleField(
          fieldName: 'text to copy to clipboard',
          toolName: 'clipboard',
          userMessage: userMessage,
          maxTokens: 150,
        );
        return {'text': text.isNotEmpty ? text : userMessage};

      // ── 19. CALENDAR: 2 LLM field extractions ─────────────────────────────
      case 'calendar':
        final title = await _model.extractSingleField(
          fieldName: 'event title or name',
          toolName: 'calendar',
          userMessage: userMessage,
        );
        final time = await _model.extractSingleField(
          fieldName: 'event date and time',
          toolName: 'calendar',
          userMessage: userMessage,
        );
        return {
          'title': title.isNotEmpty ? title : '',
          'time': time.isNotEmpty ? time : '',
        };

      // ── 20. CONTACTS: no params ────────────────────────────────────────────
      case 'contacts':
        return {};

      // ── 21. UI_AUTOMATE: 2 LLM field extractions ──────────────────────────
      case 'ui_automate':
        final app = await _model.extractSingleField(
          fieldName: 'app name to automate',
          toolName: 'ui_automate',
          userMessage: userMessage,
        );
        final goal = await _model.extractSingleField(
          fieldName: 'goal or task to accomplish in the app',
          toolName: 'ui_automate',
          userMessage: userMessage,
          maxTokens: 120,
        );
        return {
          'app': app.isNotEmpty ? app : 'browser',
          'goal': goal.isNotEmpty ? goal : userMessage,
        };

      // ── 22. REMEMBER: regex extraction ────────────────────────────────────
      case 'remember':
        return {'note': _extractNoteFromMessage(userMessage)};

      default:
        return {};
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────────
  String _extractNoteFromMessage(String msg) {
    final match = RegExp(
      r"\b(?:remember\s+that|remember\s+this\s*:?|don'?t\s+forget\s+(?:that)?|note\s+that|save\s+this\s*:?|keep\s+in\s+mind\s+that|store\s+this\s*:?|make\s+a\s+note\s+(?:that)?)\s+(.+?)(?:\.|$)",
      caseSensitive: false,
    ).firstMatch(msg);
    if (match != null && match.group(1) != null) return match.group(1)!.trim();
    // Fallback: strip trigger words and return the rest
    return msg
        .replaceAll(
          RegExp(
            r'\b(remember|note|save|store|forget|mind)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  String _extractSearchQuery(String msg) {
    return msg
        .replaceAll(
          RegExp(
            r'\b(search for|look up|google|find me|search)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  // ── LLM SINGLE-TOOL CLASSIFIER (fallback when router didn't match) ───────────
  Future<String> _llmClassifySingleTool(String userMessage) async {
    const sysPrompt =
        'You are a tool classifier. Reply with EXACTLY ONE word from the list.';
    final userPrompt =
        'Pick the single best tool for this message:\n'
        'toggle_torch, toggle_wifi, toggle_bluetooth, set_brightness, set_volume, '
        'take_screenshot, set_timer, set_reminder, send_email, send_whatsapp_message, '
        'make_call, send_sms, open_browser, open_maps, launch_app, open_settings, '
        'share_text, copy_to_clipboard, open_calendar, open_contacts, ui_automate, '
        'remember, search_web, airplane_mode, alarm, chat\n\n'
        'Message: "$userMessage"\n\n'
        'ONE WORD:';
    final raw = await _model.generateOneShot(
      sysPrompt,
      userPrompt,
      maxTokens: 10,
    );
    final word = raw.trim().toLowerCase().split(RegExp(r'[\s.,!?]+')).first;
    // Validate against known tools
    final allTools = {...ToolRegistry.allPlannerTools, 'search', 'chat'};
    if (allTools.contains(word)) return word;
    // Fuzzy: check if any tool name appears in raw
    for (final t in allTools) {
      if (raw.toLowerCase().contains(t)) return t;
    }
    return 'chat';
  }
}
