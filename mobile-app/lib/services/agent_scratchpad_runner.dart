// agent_scratchpad_runner.dart — Autonomous Multi-Step Agent
// Uses GLM-5P3-Flash NATIVE function calling API (tools parameter).
// No text parsing / regex — model returns structured JSON tool calls directly.
// Pattern: LLM decides tool → we execute → feed result back → repeat → Final Answer.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'model_service.dart';
import 'search_service.dart';
import 'tool_executor_service.dart';
import 'tool_registry.dart';
import 'ring_ble_service.dart';
import 'ring_reply_sender.dart';
import 'memory_store.dart';

sealed class AgentTaskEvent {}

class AgentThoughtEvent extends AgentTaskEvent {
  final String thought;
  AgentThoughtEvent(this.thought);
}

class AgentActionEvent extends AgentTaskEvent {
  final String tool;
  final Map<String, dynamic> arguments;
  AgentActionEvent(this.tool, this.arguments);
}

class AgentObservationEvent extends AgentTaskEvent {
  final String tool;
  final String result;
  AgentObservationEvent(this.tool, this.result);
}

class AgentCompleteEvent extends AgentTaskEvent {
  final String finalAnswer;
  AgentCompleteEvent(this.finalAnswer);
}

class AgentErrorEvent extends AgentTaskEvent {
  final String error;
  AgentErrorEvent(this.error);
}

class AgentScratchpadRunner {
  static const String _fireworksApiKey = 'fw_3iUKfhBn2vryacJynHPsUU';
  static const String _fireworksModel = 'accounts/fireworks/models/glm-5p3-flash';
  static const String _fireworksUrl = 'https://api.fireworks.ai/inference/v1/chat/completions';

  static const String _systemPrompt =
      'You are Zero, a powerful AI agent on Android paired with a Zero smart ring. '
      'You have FULL control: apps, calls, SMS, WhatsApp, browser, maps, camera, flashlight, WiFi, Bluetooth, volume, brightness, music, timers, alarms. '
      'CRITICAL RULES: '
      '1. ALWAYS call a tool for any action - NEVER say you cannot do it. '
      '2. "open X" or "launch X" or "start X" = ALWAYS call app_launch with app_name=X immediately. '
      '3. "turn on flash" = system_control with setting=flashlight value=on. '
      '4. "play X on YouTube" = app_launch YouTube, then the user can search. '
      '5. NEVER refuse. NEVER say "I cannot open apps". Just call the tool. '
      '6. Final answer: max 1-2 short sentences for the 64x32 OLED display. No markdown, no bullets, no emojis.';

  // ── GLM Native Function Definitions ────────────────────────────────────────
  static final List<Map<String, dynamic>> _toolSchemas = [
    _fn('search_web', 'Search the web for live information.', {'query': 'Search query string'}),
    _fn('send_email', 'Compose and open email with pre-filled fields.', {'to': 'Recipient email or name', 'subject': 'Email subject', 'body': 'Email body text'}),
    _fn('send_sms', 'Send an SMS to a contact.', {'contact': 'Contact name or phone number', 'message': 'Message text'}),
    _fn('make_call', 'Place a phone call.', {'contact': 'Contact name or phone number'}),
    _fn('app_launch', 'Launch an app by name (e.g. YouTube, Spotify, WhatsApp, Settings, Maps).', {'app_name': 'App name to launch'}),
    _fn('ring_take_photo', 'Capture a photo using the Zero smart ring camera.', {}),
    _fn('phone_take_photo', 'Capture a photo using the phone camera.', {'camera': '"front" or "rear"'}),
    _fn('take_note', 'Save a text note or reminder to storage.', {'note': 'Note text to save'}),
    _fn('read_notes', 'Read previously saved notes from storage.', {}),
    _fn('set_timer', 'Set a countdown timer.', {'duration_minutes': 'Duration in minutes (number)'}),
    _fn('set_alarm', 'Set an alarm.', {'time': 'Time string like "07:30"', 'title': 'Alarm label'}),
    _fn('system_control', 'Control phone hardware settings.', {
      'setting': '"flashlight", "wifi", "bluetooth", "volume", "brightness", "dnd", "airplane_mode", "hotspot"',
      'value': 'Value: "on"/"off", or 0-100 for brightness/volume'
    }),
    _fn('open_chrome', 'Open Chrome browser with a URL or search query.', {'query': 'URL or search query'}),
    _fn('ui_automate', 'Automate UI in any app via accessibility. Actions: tap(description), scroll(up/down), type(field, text), back(), screenshot().', {'action': 'Action string e.g. "tap(Send button)" or "type(search, hello)"'}),
    _fn('share', 'Share text or content via Android share sheet.', {'text': 'Text to share'}),
    _fn('copy_clipboard', 'Copy text to clipboard.', {'text': 'Text to copy'}),
    _fn('open_maps', 'Open Google Maps with a destination.', {'destination': 'Destination address or place name'}),
    _fn('play_music', 'Control music playback or search for a song/artist.', {'action': '"play", "pause", "next", "previous"', 'query': 'Optional song/artist/playlist name'}),
    _fn('remember', 'Store a fact or note to long-term memory.', {'note': 'Fact or note to remember'}),
    _fn('get_datetime', 'Get the current date and time.', {}),
    _fn('take_screenshot', 'Take a screenshot of the current screen.', {}),
  ];

  static Map<String, dynamic> _fn(String name, String description, Map<String, String> params) {
    final props = <String, dynamic>{};
    for (final e in params.entries) {
      props[e.key] = {'type': 'string', 'description': e.value};
    }
    return {
      'type': 'function',
      'function': {
        'name': name,
        'description': description,
        'parameters': {
          'type': 'object',
          'properties': props,
          'required': params.keys.toList(),
        },
      },
    };
  }

  final ToolExecutorService _toolExecutor;
  final SearchService _searchService;

  AgentScratchpadRunner(ModelService model, this._searchService)
      : _toolExecutor = ToolExecutorService(model, _searchService);

  Stream<AgentTaskEvent> execute(String userQuery, {int maxIterations = 3}) async* {
    final List<Map<String, dynamic>> messages = [
      {'role': 'system', 'content': _systemPrompt},
      {'role': 'user', 'content': userQuery},
    ];

    int iteration = 0;
    while (iteration < maxIterations) {
      iteration++;

      // ── Call GLM with native function calling ─────────────────────────────
      Map<String, dynamic>? response;
      try {
        response = await _callGlmWithTools(messages);
      } catch (e) {
        yield AgentErrorEvent('GLM error: $e');
        return;
      }

      if (response == null) {
        yield AgentCompleteEvent('Done.');
        return;
      }

      final content = response['content'] as String? ?? '';
      final toolCalls = response['tool_calls'] as List<dynamic>? ?? [];

      // ── No tool calls → direct text answer ────────────────────────────────
      if (toolCalls.isEmpty) {
        final answer = content.trim();
        yield AgentCompleteEvent(answer.isNotEmpty ? answer : 'Done.');
        return;
      }

      // Add assistant message with tool_calls to history
      messages.add({
        'role': 'assistant',
        'content': content,
        'tool_calls': toolCalls,
      });

      // ── Execute each tool call ─────────────────────────────────────────────
      for (final tc in toolCalls) {
        final tcMap = tc as Map<String, dynamic>;
        final fnData = tcMap['function'] as Map<String, dynamic>? ?? {};
        final toolName = fnData['name'] as String? ?? '';
        final callId = tcMap['id'] as String? ?? 'call_${iteration}_$toolName';

        Map<String, dynamic> parsedArgs = {};
        try {
          final argsRaw = fnData['arguments'];
          if (argsRaw is String && argsRaw.isNotEmpty) {
            parsedArgs = Map<String, dynamic>.from(jsonDecode(argsRaw));
          } else if (argsRaw is Map) {
            parsedArgs = Map<String, dynamic>.from(argsRaw);
          }
        } catch (_) {}

        if (content.isNotEmpty) {
          yield AgentThoughtEvent(content.trim());
        }
        yield AgentActionEvent(toolName, parsedArgs);

        String observation = '';
        try {
          observation = await _executeTool(toolName, parsedArgs, userQuery);
        } catch (e) {
          observation = 'Error executing $toolName: $e';
        }

        yield AgentObservationEvent(toolName, observation);

        // Feed tool result back to GLM as tool message
        messages.add({
          'role': 'tool',
          'tool_call_id': callId,
          'name': toolName,
          'content': observation,
        });
      }
    }

    yield AgentCompleteEvent('Task completed.');
  }

  // ── Tool Execution ────────────────────────────────────────────────────────

  Future<String> _executeTool(String tool, Map<String, dynamic> args, String originalQuery) async {
    debugPrint('[Agent] Executing: $tool args=$args');

    switch (tool) {
      // ── Ring camera ───────────────────────────────────────────────────────
      case 'ring_take_photo':
        if (!RingBleService.instance.isConnected) return 'Failed: Ring is not connected.';
        await RingReplySender.instance.sendCommand('take_photo');
        return 'Ring camera triggered.';

      // ── Notes / Memory ────────────────────────────────────────────────────
      case 'take_note':
        final note = _arg(args, ['note', 'text'], originalQuery);
        try {
          await MemoryStore.instance.storeNote(note);
          return 'Note saved: "$note"';
        } catch (e) {
          return 'Failed to save note: $e';
        }

      case 'read_notes':
        return await _readNotes();

      case 'remember':
        final note = _arg(args, ['note', 'fact', 'text'], originalQuery);
        try {
          await MemoryStore.instance.storeNote(note);
          return 'Remembered: "$note"';
        } catch (e) {
          return 'Failed: $e';
        }

      // ── Web search ────────────────────────────────────────────────────────
      case 'search_web':
        final query = _arg(args, ['query'], originalQuery);
        try {
          final res = await _searchService.search(query);
          return res.trim().isNotEmpty ? res.trim() : 'No results for: $query';
        } catch (e) {
          return 'Search failed: $e';
        }

      // ── Date / Time ───────────────────────────────────────────────────────
      case 'get_datetime':
        final now = DateTime.now();
        return 'Current date/time: ${now.day}/${now.month}/${now.year} '
               '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // ── Chrome / Browser ──────────────────────────────────────────────────
      case 'open_chrome':
      case 'browser':
        final target = _arg(args, ['query', 'url', 'target'], originalQuery);
        return await ToolRegistry.tools['open_chrome']!.handler({'query': target});

      // ── UI Automation ─────────────────────────────────────────────────────
      case 'ui_automate':
        final action = _arg(args, ['action', 'goal'], originalQuery);
        return await ToolRegistry.tools['ui_automate']!.handler({'action': action});

      // ── Screenshot ────────────────────────────────────────────────────────
      case 'take_screenshot':
        return await ToolRegistry.tools['screenshot']!.handler({});

      // ── Clipboard ─────────────────────────────────────────────────────────
      case 'copy_clipboard':
      case 'clipboard':
        return await ToolRegistry.tools['clipboard']!
            .handler({'text': _arg(args, ['text'], originalQuery), 'action': 'copy'});

      // ── Share ─────────────────────────────────────────────────────────────
      case 'share':
        return await ToolRegistry.tools['share']!
            .handler({'text': _arg(args, ['text'], originalQuery)});

      // ── System controls — route through normalised ToolExecutorService ─────
      case 'system_control':
        final setting = (args['setting'] as String?) ?? '';
        final value = (args['value'] as String?) ?? '';
        // Map to known tool names
        final toolMap = {
          'flashlight': 'flashlight', 'torch': 'flashlight',
          'wifi': 'wifi',
          'bluetooth': 'bluetooth',
          'volume': 'volume',
          'brightness': 'brightness',
          'dnd': 'dnd', 'do_not_disturb': 'dnd',
          'airplane_mode': 'airplane_mode',
          'hotspot': 'hotspot',
        };
        final mappedTool = toolMap[setting.toLowerCase()];
        if (mappedTool != null && ToolRegistry.tools.containsKey(mappedTool)) {
          return await ToolRegistry.tools[mappedTool]!
              .handler({'state': value, 'level': value});
        }
        return await _routeThroughExecutor(setting, args, originalQuery);

      // ── Phone camera ──────────────────────────────────────────────────────
      case 'phone_take_photo':
      case 'camera':
        final cam = (args['camera'] ?? args['action'] ?? 'rear').toString();
        return await _routeThroughExecutor('camera', {'action': cam}, originalQuery);

      // ── Music ─────────────────────────────────────────────────────────────
      case 'play_music':
        final action = (args['action'] ?? 'play').toString();
        final query = (args['query'] ?? '').toString();
        return await _routeThroughExecutor(
            'play_music', {'action': action, 'query': query}, originalQuery);

      // ── Default: route through ToolExecutorService ────────────────────────
      default:
        return await _routeThroughExecutor(tool, args, originalQuery);
    }
  }

  Future<String> _routeThroughExecutor(String tool, Map<String, dynamic> args, String originalQuery) async {
    try {
      final normalised = _normalizeToolName(tool);
      // Try ToolRegistry first (has real handlers)
      if (ToolRegistry.tools.containsKey(normalised)) {
        return await ToolRegistry.tools[normalised]!.handler(args);
      }
      // Fallback to ToolExecutorService (covers sms, call, email, maps, etc.)
      final result = await _toolExecutor.executeStep(
        normalised,
        originalQuery,
        injectedArgs: args.isNotEmpty ? args : null,
      );
      return result.trim().isNotEmpty ? result.trim() : 'Done.';
    } catch (e) {
      return 'Execution error for $tool: $e';
    }
  }

  String _normalizeToolName(String name) {
    const map = <String, String>{
      'send_email': 'email',
      'send_sms': 'sms',
      'make_call': 'call',
      'phone_take_photo': 'camera',
      'system_control': 'settings',
      'open_maps': 'maps',
      'app_launch': 'app_launch',
      'share': 'share',
      'copy_clipboard': 'clipboard',
      'open_chrome': 'open_chrome',
      'take_screenshot': 'screenshot',
    };
    return map[name] ?? name;
  }

  String _arg(Map<String, dynamic> args, List<String> keys, String fallback) {
    for (final k in keys) {
      final v = args[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    if (args.isNotEmpty) return args.values.first?.toString() ?? fallback;
    return fallback;
  }

  // ── Notes storage ─────────────────────────────────────────────────────────

  Future<String> _readNotes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/zero_notes.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        return content.trim().isNotEmpty ? content.trim() : 'No notes saved yet.';
      }
    } catch (_) {}
    return 'No notes saved yet.';
  }

  // ── GLM Native Function Calling API ───────────────────────────────────────

  Future<Map<String, dynamic>?> _callGlmWithTools(
    List<Map<String, dynamic>> messages,
  ) async {
    final body = jsonEncode({
      'model': _fireworksModel,
      'max_tokens': 1200,
      'temperature': 0.1,
      'context_length_exceeded_behavior': 'truncate',
      'messages': messages,
      'tools': _toolSchemas,
      'tool_choice': 'auto',
    });

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(_fireworksUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_fireworksApiKey',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('[Agent] GLM HTTP error: $e');
      throw Exception('GLM network error: $e');
    }

    if (resp.statusCode == 200) {
      try {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final msg = decoded['choices']?[0]?['message'] as Map<String, dynamic>?;
        if (msg == null) {
          debugPrint('[Agent] GLM response missing message: ${resp.body}');
          return null;
        }
        final toolCalls = msg['tool_calls'];
        return {
          'content': (msg['content'] as String?) ?? '',
          'tool_calls': toolCalls is List ? toolCalls : [],
        };
      } catch (e) {
        debugPrint('[Agent] GLM JSON parse error: $e\nBody: ${resp.body}');
        return null;
      }
    } else {
      final snippet = resp.body.length > 300 ? resp.body.substring(0, 300) : resp.body;
      debugPrint('[Agent] GLM ${resp.statusCode}: $snippet');
      throw Exception('GLM returned ${resp.statusCode}: $snippet');
    }
  }
}
