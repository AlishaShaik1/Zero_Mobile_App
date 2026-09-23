// agent_router_service.dart -- unified JSON classifier
// Routes user intent to device tools via Fireworks GLM-5P3-Flash API.
// Falls back to local llama.cpp if API fails.
// Thinking/reasoning is DISABLED for routing -- pure speed.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:llamadart/llamadart.dart';
import 'model_service.dart';

class AgentRoute {
  final String toolName;
  final Map<String, dynamic> arguments;
  final bool isMulti;
  final bool isNone;
  final String reason;

  /// Populated when the router decides no tool is needed — use this text
  /// as the chat reply directly instead of calling ModelService.chat().
  final String? reply;

  const AgentRoute({
    required this.toolName,
    this.arguments = const {},
    this.isMulti = false,
    this.isNone = false,
    this.reason = '',
    this.reply,
  });

  String? get param {
    if (arguments.isEmpty) return null;
    final val =
        arguments['task'] ??      // zero_cowork task argument
        arguments['state'] ??
        arguments['value'] ??
        arguments['action'] ??
        arguments['level'] ??
        arguments['query'] ??
        arguments['contact'] ??
        arguments['contact_name'] ??
        arguments['app_name'] ??
        arguments['app'] ??
        arguments['note'] ??
        arguments['text'] ??
        arguments['message'] ??
        arguments['url'] ??
        arguments['destination'] ??
        arguments['duration'] ??
        arguments['time'] ??
        arguments['direction'] ??
        (arguments.isNotEmpty ? arguments.values.first : null);
    return val?.toString();
  }

  bool get hasParam => param != null && param!.isNotEmpty;

  @override
  String toString() =>
      'AgentRoute(tool=$toolName, args=$arguments, multi=$isMulti, none=$isNone, reply=$reply)';
}

class AgentRouterService {
  AgentRouterService._();
  static final AgentRouterService instance = AgentRouterService._();

  bool _routing = false;
  // Always ready — Fireworks API doesn't need a local model download
  bool get isReady => true;

  // ── Fireworks GLM-5P3-Flash API config ─────────────────────────────────────
  static const String _fireworksApiKey = 'fw_3iUKfhBn2vryacJynHPsUU';
  static const String _fireworksModel = 'accounts/fireworks/models/glm-5p3-flash';
  static const String _fireworksUrl =
      'https://api.fireworks.ai/inference/v1/chat/completions';

  Future<void> initialize() async {}
  void dispose() {}

  // Unified JSON classifier prompt.
  // Model ALWAYS outputs ONE JSON object.
  // For device actions: {"tool":"<name>", ...args}
  // For conversation: {"tool":"none","reply":"<short reply here>"}
  // NEVER outputs plain text — always JSON. Thinking DISABLED for speed.
  static const String _sysPrompt =
      'Output ONLY valid JSON. Always respond with {"tool":...}.\n'
      'You are a phone command router. ALWAYS use app_launch for ANY open/launch/start app request.\n'
      'NEVER say you cannot open apps. NEVER refuse. Always call the tool.\n'
      'Device command -> tool JSON. Conversation -> {"tool":"none","reply":"..."}\n'
      'flashlight on->{"tool":"flashlight","state":"on"}\n'
      'turn on flash->{"tool":"flashlight","state":"on"}\n'
      'turn on flashlight->{"tool":"flashlight","state":"on"}\n'
      'torch off->{"tool":"flashlight","state":"off"}\n'
      'wifi on->{"tool":"wifi","state":"on"}\n'
      'bluetooth on->{"tool":"bluetooth","state":"on"}\n'
      'brightness 80->{"tool":"brightness","value":80}\n'
      'volume up->{"tool":"volume","action":"up"}\n'
      'volume 5->{"tool":"volume","value":5}\n'
      'mute->{"tool":"volume","action":"mute"}\n'
      '10 minute timer->{"tool":"timer","duration":"10 minutes"}\n'
      'alarm 7am->{"tool":"alarm","time":"07:00"}\n'
      'call mom->{"tool":"call","contact":"mom"}\n'
      'text John hi->{"tool":"sms","contact":"John","message":"hi"}\n'
      'whatsapp Sara->{"tool":"whatsapp","contact":"Sara"}\n'
      'email boss->{"tool":"email","contact":"boss"}\n'
      'navigate Delhi->{"tool":"maps","destination":"Delhi"}\n'
      'search best phones->{"tool":"search_web","query":"best phones"}\n'
      'who is Elon->{"tool":"search_web","query":"who is Elon Musk"}\n'
      'open browser->{"tool":"browser"}\n'
      'open YouTube->{"tool":"app_launch","app_name":"YouTube"}\n'
      'launch YouTube->{"tool":"app_launch","app_name":"YouTube"}\n'
      'play youtube->{"tool":"app_launch","app_name":"YouTube"}\n'
      'play songs on youtube->{"tool":"app_launch","app_name":"YouTube"}\n'
      'open spotify->{"tool":"app_launch","app_name":"Spotify"}\n'
      'open instagram->{"tool":"app_launch","app_name":"Instagram"}\n'
      'open whatsapp->{"tool":"app_launch","app_name":"WhatsApp"}\n'
      'open maps->{"tool":"app_launch","app_name":"Google Maps"}\n'
      'open camera app->{"tool":"app_launch","app_name":"Camera"}\n'
      'open gmail->{"tool":"app_launch","app_name":"Gmail"}\n'
      'open telegram->{"tool":"app_launch","app_name":"Telegram"}\n'
      'open netflix->{"tool":"app_launch","app_name":"Netflix"}\n'
      'open facebook->{"tool":"app_launch","app_name":"Facebook"}\n'
      'open twitter->{"tool":"app_launch","app_name":"Twitter"}\n'
      'open chrome->{"tool":"app_launch","app_name":"Chrome"}\n'
      'open settings->{"tool":"settings"}\n'
      'screenshot->{"tool":"screenshot"}\n'
      'contacts->{"tool":"contacts"}\n'
      'calendar->{"tool":"calendar"}\n'
      'what time->{"tool":"get_datetime"}\n'
      'airplane mode on->{"tool":"airplane_mode","state":"on"}\n'
      'hotspot on->{"tool":"hotspot","state":"on"}\n'
      'do not disturb on->{"tool":"dnd","state":"on"}\n'
      'play music->{"tool":"play_music","action":"play"}\n'
      'next song->{"tool":"play_music","action":"next"}\n'
      'pause music->{"tool":"play_music","action":"pause"}\n'
      'share->{"tool":"share"}\n'
      'copy clipboard->{"tool":"clipboard","action":"copy"}\n'
      'remember parking->{"tool":"remember","note":"parking spot"}\n'
      'tap button->{"tool":"ui_automate","action":"tap"}\n'
      'selfie->{"tool":"camera","action":"front"}\n'
      'take photo->{"tool":"camera","action":"rear"}\n'
      'record->{"tool":"recording","state":"start"}\n'
      'stop recording->{"tool":"recording","state":"stop"}\n'
      'take note buy milk->{"tool":"take_note","note":"buy milk"}\n'
      'ring take photo->{"tool":"ring_take_photo"}\n'
      'hello->{"tool":"none","reply":"Hello! How can I help?"}\n'
      'how are you->{"tool":"none","reply":"I am doing great! What can I do for you?"}\n'
      'zero cowork search cheapest iphone->{"tool":"zero_cowork","task":"search cheapest iphone"}\n'
      'cowork buy me airpods->{"tool":"zero_cowork","task":"buy airpods on amazon"}\n'
      'cowork fill this form->{"tool":"zero_cowork","task":"fill this form"}';

  static const Set<String> _kValidTools = {
    'flashlight',
    'wifi',
    'bluetooth',
    'brightness',
    'volume',
    'timer',
    'alarm',
    'call',
    'sms',
    'whatsapp',
    'email',
    'maps',
    'search_web',
    'browser',
    'open_chrome',      // open Chrome with search query or URL
    'app_launch',
    'settings',
    'screenshot',
    'contacts',
    'calendar',
    'play_music',
    'share',
    'clipboard',
    'remember',
    'ui_automate',      // tap/scroll/type UI automation via accessibility
    'get_datetime',
    'hotspot',
    'airplane_mode',
    'dnd',
    'recording',        // audio recording start/stop
    'camera',           // phone camera front/rear
    'take_note',        // save text note
    'summarize',        // summarize screen/meeting
    'ring_take_photo',  // trigger ring camera via BLE
    'zero_cowork',      // cloud browser AI agent (zerolabs.live)
  };

  
  /// Fast deterministic rule matcher for instant (0ms) tool routing.
  /// Bypasses network/Fireworks API completely for common phone actions.
  AgentRoute? _fastLocalMatch(String message) {
    final lower = message.trim().toLowerCase();
    if (lower.isEmpty) return null;

    // 1. Flashlight / Torch
    if (RegExp(r'\b(turn\s+on\s+(the\s+)?(flash|flashlight|torch)|(flash|flashlight|torch)\s+on)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'flashlight', arguments: {'state': 'on'});
    }
    if (RegExp(r'\b(turn\s+off\s+(the\s+)?(flash|flashlight|torch)|(flash|flashlight|torch)\s+off)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'flashlight', arguments: {'state': 'off'});
    }

    // 1b. WhatsApp/SMS compound tasks (open whatsapp and send X to Y)
    final waCompound = RegExp(
      r'(?:open\s+whatsapp|whatsapp)\s+(?:and\s+)?(?:send|message|msg)\s+(.+?)\s+to\s+(.+)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (waCompound != null) {
      final msg = (waCompound.group(1) ?? '').trim();
      final contact = (waCompound.group(2) ?? '').trim();
      return AgentRoute(
        toolName: 'whatsapp',
        arguments: {'contact_name': contact, 'message_body': msg},
      );
    }
    // "send hi to sara on whatsapp" / "message sara hi on whatsapp"
    final waCompound2 = RegExp(
      r'(?:send|message|msg)\s+(.+?)\s+to\s+(.+?)\s+(?:on\s+)?(?:whatsapp|wa)',
      caseSensitive: false,
    ).firstMatch(lower);
    if (waCompound2 != null) {
      final msg = (waCompound2.group(1) ?? '').trim();
      final contact = (waCompound2.group(2) ?? '').trim();
      return AgentRoute(
        toolName: 'whatsapp',
        arguments: {'contact_name': contact, 'message_body': msg},
      );
    }
    // "call X" fast path
    final callMatch = RegExp(
      r'^(?:call|ring|dial)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (callMatch != null && !lower.contains('whatsapp')) {
      final contact = (callMatch.group(1) ?? '').trim();
      return AgentRoute(toolName: 'call', arguments: {'contact': contact});
    }

    // 2. YouTube – direct search/play video via YouTube deep link
    final ytComplex = RegExp(
      r'^(?:play|listen\s+to)\s+(.+?)\s+on\s+youtube$|^open\s+youtube\s+and\s+play\s+(.+)$|^play\s+(.+?)\s+in\s+youtube$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (ytComplex != null) {
      final song = ((ytComplex.group(1) ?? ytComplex.group(2) ?? ytComplex.group(3)) ?? '').trim();
      if (song.isNotEmpty) {
        final encoded = Uri.encodeComponent(song);
        return AgentRoute(
          toolName: 'browser',
          arguments: {'url': 'https://www.youtube.com/results?search_query=$encoded'},
        );
      }
    }
    // YouTube search (just search, not play)
    final ytSearch = RegExp(
      r'^(?:open\s+youtube\s+and\s+(?:search|seach)\s+(.+)|search\s+(.+?)\s+on\s+youtube)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (ytSearch != null) {
      var query = ((ytSearch.group(1) ?? ytSearch.group(2)) ?? '').trim();
      if (query.isEmpty) query = 'music';
      final encoded = Uri.encodeComponent(query);
      return AgentRoute(
        toolName: 'browser',
        arguments: {'url': 'https://www.youtube.com/results?search_query=$encoded'},
      );
    }
    if (lower.contains('youtube') && (lower.contains('play song') || lower.contains('play music'))) {
      return const AgentRoute(
        toolName: 'browser',
        arguments: {'url': 'https://www.youtube.com/results?search_query=trending+music'},
      );
    }

    // 3. Google & Web Search (supports "search", "seach", "find", "google")
    final webSearch = RegExp(
      r'^(?:open\s+google\s+and\s+(?:search|seach|find)(?:\s+for)?|search(?:\s+for)?\s+(.+?)\s+on\s+google|(?:search|seach)(?:\s+for)?|google)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (webSearch != null) {
      final q = (webSearch.group(1) ?? webSearch.group(2) ?? '').trim();
      if (q.isNotEmpty) {
        final encoded = Uri.encodeComponent(q);
        return AgentRoute(
          toolName: 'browser',
          arguments: {'url': 'https://www.google.com/search?q=$encoded'},
        );
      }
    }

    // 3b. Direct WhatsApp commands (e.g. "send hi to Sara on whatsapp", "whatsapp Mom I am home")
    final waOn = RegExp(
      r'^(?:send|sent|text|msg|message)\s+(.+?)\s+to\s+(.+?)\s+(?:on|via|through|in)\s+whatsapp$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (waOn != null) {
      return AgentRoute(
        toolName: 'whatsapp',
        arguments: {
          'contact_name': waOn.group(2)!.trim(),
          'message_body': waOn.group(1)!.trim(),
          'contact': waOn.group(2)!.trim(),
          'message': waOn.group(1)!.trim(),
        },
      );
    }
    final waDirect = RegExp(
      r'^(?:whatsapp|wa)\s+([a-zA-Z0-9_]+)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (waDirect != null) {
      return AgentRoute(
        toolName: 'whatsapp',
        arguments: {
          'contact_name': waDirect.group(1)!.trim(),
          'message_body': waDirect.group(2)!.trim(),
          'contact': waDirect.group(1)!.trim(),
          'message': waDirect.group(2)!.trim(),
        },
      );
    }

    // 4. Known Websites & Domains
    // "open flipkart website", "open youtube website"
    final openNamedWebsite = RegExp(
      r'^(?:open|go\s+to|visit)\s+(?:the\s+)?([a-zA-Z0-9\-]+)\s+website$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (openNamedWebsite != null) {
      final site = openNamedWebsite.group(1)!.trim().toLowerCase();
      final url = (site == 'google') ? 'https://google.com' :
                  (site == 'youtube') ? 'https://youtube.com' :
                  (site == 'leetcode') ? 'https://leetcode.com' :
                  'https://$site.com';
      return AgentRoute(
        toolName: 'browser',
        arguments: {'url': url},
      );
    }
    // "open website leetcode.com" or "open website flipkart"
    final openWebsitePrefix = RegExp(
      r'^(?:open|go\s+to|visit)\s+(?:the\s+)?website\s+([a-zA-Z0-9\-\.]+)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (openWebsitePrefix != null) {
      var target = openWebsitePrefix.group(1)!.trim();
      if (!target.contains('.')) target = '$target.com';
      return AgentRoute(
        toolName: 'browser',
        arguments: {'url': target.startsWith('http') ? target : 'https://$target'},
      );
    }
    // Direct "open X.com" or "go to X.com" → browser
    final openDomainDirect = RegExp(
      r'^(?:open|go\s+to|visit|navigate\s+to)\s+(?:the\s+)?(?:website\s+)?([a-zA-Z0-9\-]+\.[a-zA-Z]{2,6})(?:\s+website)?$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (openDomainDirect != null) {
      final domain = openDomainDirect.group(1)!;
      return AgentRoute(
        toolName: 'browser',
        arguments: {'url': 'https://$domain'},
      );
    }
    final domainMatch = RegExp(
      r'\b([a-z0-9-]+\.(?:com|org|net|io|in|co|gov|edu))\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (domainMatch != null) {
      return AgentRoute(
        toolName: 'browser',
        arguments: {'url': 'https://${domainMatch.group(1)}'},
      );
    }

    const knownSites = <String, String>{
      'leetcode': 'https://leetcode.com',
      'github': 'https://github.com',
      'reddit': 'https://reddit.com',
      'wikipedia': 'https://wikipedia.org',
      'amazon': 'https://amazon.com',
      'google': 'https://google.com',
      'chatgpt': 'https://chatgpt.com',
      'twitter': 'https://x.com',
      'stackoverflow': 'https://stackoverflow.com',
    };
    for (final entry in knownSites.entries) {
      if (RegExp('^(?:open|go\\s+to)\\s+(?:the\\s+)?${entry.key}(?:\\s+website)?\$', caseSensitive: false).hasMatch(lower)) {
        return AgentRoute(
          toolName: 'browser',
          arguments: {'url': entry.value},
        );
      }
    }

    // 4b. Complex compound app tasks → zero_cowork (e.g. "open spotify and play X")
    final complexTask = RegExp(
      r'^(?:open|launch|start)\s+(.+?)\s+and\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (complexTask != null) {
      final appPart = (complexTask.group(1) ?? '').trim();
      final action = (complexTask.group(2) ?? '').trim();
      // WhatsApp with message → parse directly
      if (appPart.contains('whatsapp') || appPart.contains('wa')) {
        final sendMatch = RegExp(
          r'^(?:send|sent|text|msg|message)\s+(.+?)\s+to\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(action);
        if (sendMatch != null) {
          return AgentRoute(
            toolName: 'whatsapp',
            arguments: {
              'contact_name': (sendMatch.group(2) ?? '').trim(),
              'message_body': (sendMatch.group(1) ?? '').trim(),
              'contact': (sendMatch.group(2) ?? '').trim(),
              'message': (sendMatch.group(1) ?? '').trim(),
            },
          );
        }
        final textMatch = RegExp(
          r'^(?:text|msg|message)\s+([a-zA-Z0-9_]+)\s+(.+)$',
          caseSensitive: false,
        ).firstMatch(action);
        if (textMatch != null) {
          return AgentRoute(
            toolName: 'whatsapp',
            arguments: {
              'contact_name': textMatch.group(1)!.trim(),
              'message_body': textMatch.group(2)!.trim(),
              'contact': textMatch.group(1)!.trim(),
              'message': textMatch.group(2)!.trim(),
            },
          );
        }
        return const AgentRoute(toolName: 'app_launch', arguments: {'app_name': 'WhatsApp'});
      }
      // YouTube → handled above; Spotify/Music → zero_cowork
      if (appPart.contains('spotify') || appPart.contains('gaana') || appPart.contains('music')) {
        return AgentRoute(
          toolName: 'zero_cowork',
          arguments: {'task': 'Open $appPart and $action'},
        );
      }
      // Generic compound → zero_cowork
      return AgentRoute(
        toolName: 'zero_cowork',
        arguments: {'task': 'Open $appPart app and $action'},
      );
    }

    // 5. Pure App Launch (Clean single app names ONLY, no "and", "then", "search", etc.)
    final appClean = RegExp(
      r'^(?:open|launch|start)\s+(?:the\s+)?([a-z0-9\s]+?)(?:\s+app)?$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (appClean != null) {
      final rawApp = appClean.group(1)!.trim();
      if (!RegExp(r'\b(and|then|with|for|play|search|seach)\b').hasMatch(rawApp)) {
        const appMap = <String, String>{
          'youtube': 'YouTube',
          'yt': 'YouTube',
          'whatsapp': 'WhatsApp',
          'spotify': 'Spotify',
          'instagram': 'Instagram',
          'insta': 'Instagram',
          'chrome': 'Chrome',
          'google chrome': 'Chrome',
          'browser': 'Chrome',
          'gmail': 'Gmail',
          'mail': 'Gmail',
          'maps': 'Google Maps',
          'google maps': 'Google Maps',
          'camera': 'Camera',
          'netflix': 'Netflix',
          'telegram': 'Telegram',
          'facebook': 'Facebook',
          'fb': 'Facebook',
          'settings': 'Settings',
          'calculator': 'Calculator',
          'clock': 'Clock',
          'alarm': 'Clock',
          'calendar': 'Calendar',
          'contacts': 'Contacts',
          'gallery': 'Gallery',
          'photos': 'Photos',
        };
        final appName = appMap[rawApp] ?? (rawApp.isNotEmpty ? rawApp[0].toUpperCase() + rawApp.substring(1) : rawApp);
        return AgentRoute(
          toolName: 'app_launch',
          arguments: {'app_name': appName},
        );
      }
    }

    // 6. WiFi & Bluetooth
    if (RegExp(r'\b(turn\s+on\s+(the\s+)?wi-?fi|wi-?fi\s+on)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'wifi', arguments: {'state': 'on'});
    }
    if (RegExp(r'\b(turn\s+off\s+(the\s+)?wi-?fi|wi-?fi\s+off)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'wifi', arguments: {'state': 'off'});
    }
    if (RegExp(r'\b(turn\s+on\s+(the\s+)?bluetooth|bluetooth\s+on)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'bluetooth', arguments: {'state': 'on'});
    }
    if (RegExp(r'\b(turn\s+off\s+(the\s+)?bluetooth|bluetooth\s+off)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'bluetooth', arguments: {'state': 'off'});
    }

    // 7. Camera / Photo
    if (RegExp(r'\b(take\s+(a\s+)?(selfie)|selfie)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'camera', arguments: {'action': 'front'});
    }
    if (RegExp(r'\b(take\s+(a\s+)?(photo|picture)|click\s+(a\s+)?(photo|picture))\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'camera', arguments: {'action': 'rear'});
    }

    // 8. Volume
    if (RegExp(r'\b(mute|mute\s+(the\s+)?phone|silence\s+(the\s+)?phone)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'volume', arguments: {'action': 'mute'});
    }
    if (RegExp(r'\b(volume\s+up|increase\s+(sound|volume))\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'volume', arguments: {'action': 'up'});
    }
    if (RegExp(r'\b(volume\s+down|decrease\s+(sound|volume)|lower\s+(sound|volume))\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'volume', arguments: {'action': 'down'});
    }

    // 9. Datetime
    if (RegExp(r'\b(what\s+time(\s+is\s+it)?|current\s+time|what\s+is\s+today(s)?\s+date)\b').hasMatch(lower)) {
      return const AgentRoute(toolName: 'get_datetime');
    }

    // 10. Zero Cowork
    if (lower.startsWith('zero cowork ') || lower.startsWith('cowork ')) {
      final task = lower.replaceFirst(RegExp(r'^(zero\s+)?cowork\s+'), '').trim();
      return AgentRoute(toolName: 'zero_cowork', arguments: {'task': task});
    }

    return null;
  }

    Future<AgentRoute> route(
    String userMessage, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_routing) {
      debugPrint('[AgentRouter] Re-entrant -- dropped');
      return const AgentRoute(toolName: '', isNone: true);
    }
    // 0. Fast local deterministic check (0ms — no network, never fails)
    final localRoute = _fastLocalMatch(userMessage);
    if (localRoute != null) {
      debugPrint('[AgentRouter] ⚡ Fast local match: ${localRoute.toolName} (${localRoute.arguments})');
      return localRoute;
    }

    _routing = true;

    try {
      // ── Primary: Fireworks GLM-5P3-Flash API directly (no regex bypass) ────
      final raw = await _callFireworksApi(userMessage, timeout);
      if (raw != null && raw.isNotEmpty) {
        return _parseJsonResponse(raw);
      }

      // ── Fallback: local llama.cpp (if model loaded) ───────────────────────
      if (ModelService().isReady) {
        debugPrint('[AgentRouter] Fireworks failed — using local llama.cpp');
        return await _routeLocal(userMessage, const Duration(seconds: 3));
      }

      return const AgentRoute(toolName: '', isNone: true, reason: 'api_failed_no_local');
    } catch (e) {
      debugPrint('[AgentRouter] Exception/Timeout: $e');
      return const AgentRoute(toolName: '', isNone: true);
    } finally {
      _routing = false;
    }
  }

  /// Call Fireworks GLM-5P3-Flash. Returns raw content string or null on failure.
  Future<String?> _callFireworksApi(String userMessage, Duration timeout) async {
    try {
      final body = jsonEncode({
        'model': _fireworksModel,
        'max_tokens': 1000,
        'top_k': 40,
        'presence_penalty': 0,
        'frequency_penalty': 0,
        'temperature': 0.0,
        'messages': [
          {'role': 'system', 'content': _sysPrompt},
          {'role': 'user', 'content': userMessage},
        ],
      });

      final response = await http
          .post(
            Uri.parse(_fireworksUrl),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_fireworksApiKey',
            },
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        var content =
            decoded['choices']?[0]?['message']?['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          final reasoning = decoded['choices']?[0]?['message']?['reasoning_content'] as String?;
          if (reasoning != null && reasoning.contains('{"tool"')) {
            content = reasoning;
          }
        }
        debugPrint('[AgentRouter/Fireworks] RAW: $content');
        return content?.trim();
      } else {
        debugPrint(
          '[AgentRouter/Fireworks] HTTP ${response.statusCode}: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[AgentRouter/Fireworks] error: $e');
      return null;
    }
  }

  /// Local llama.cpp fallback routing.
  Future<AgentRoute> _routeLocal(String userMessage, Duration timeout) async {
    if (!await ModelService().acquireLock()) {
      return const AgentRoute(toolName: '', isNone: true);
    }
    final engine = ModelService().engine;
    final messages = [
      const LlamaChatMessage.fromText(role: LlamaChatRole.system, text: _sysPrompt),
      LlamaChatMessage.fromText(role: LlamaChatRole.user, text: userMessage),
    ];
    final sb = StringBuffer();
    try {
      await for (final chunk in engine
          .create(
            messages,
            params: GenerationParams(
              maxTokens: 40,
              temp: 0.0,
              topK: 1,
              topP: 1.0,
              thinkingBudget: const ThinkingBudget(maxTokens: 0),
              stopSequences: ModelService.kStops,
            ),
          )
          .timeout(timeout)) {
        final delta = chunk.choices.firstOrNull?.delta;
        if ((delta?.thinking ?? '').isNotEmpty) continue;
        final c = delta?.content;
        if (c != null && c.isNotEmpty) sb.write(c);
        if (sb.toString().contains('}')) {
          try { engine.cancelGeneration(); } catch (_) {}
          break;
        }
        if (sb.length > 512) {
          try { engine.cancelGeneration(); } catch (_) {}
          break;
        }
      }
    } catch (e) {
      ModelService().cancelGeneration();
    } finally {
      ModelService().releaseLock();
    }
    return _parseJsonResponse(sb.toString().trim());
  }

  /// Parse a JSON string into an AgentRoute.
  AgentRoute _parseJsonResponse(String raw) {
    debugPrint('[AgentRouter] Parsing: $raw');
    if (raw.isEmpty) return const AgentRoute(toolName: '', isNone: true);

    if (raw.startsWith('[respond') || raw.contains('[respond normally')) {
      return const AgentRoute(toolName: '', isNone: true);
    }

    final j0 = raw.indexOf('{');
    final j1 = raw.lastIndexOf('}');
    if (j0 == -1 || j1 <= j0) {
      debugPrint('[AgentRouter] No JSON -> conversational');
      return const AgentRoute(toolName: '', isNone: true);
    }

    final jsonStr = raw.substring(j0, j1 + 1);
    late Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      debugPrint('[AgentRouter] JSON parse error: $jsonStr');
      return const AgentRoute(toolName: '', isNone: true);
    }

    String toolName = (parsed['tool'] as String?)?.toLowerCase().trim() ?? '';

    // Convert app_launch on a website/domain -> browser
    if (toolName == 'app_launch') {
      final app = ((parsed['app_name'] ?? parsed['app']) as String?) ?? '';
      if (app.contains('.') || app.startsWith('http://') || app.startsWith('https://')) {
        toolName = 'browser';
        parsed['url'] = app.startsWith('http') ? app : 'https://$app';
      }
    }

    // Fix hallucinated generic tools like "toggle"
    if (toolName == 'toggle' || toolName == 'feature') {
      final feature =
          (parsed['feature'] as String?)?.toLowerCase() ??
          (parsed['state'] as String?)?.toLowerCase() ??
          '';
      if (feature.contains('flash') || feature.contains('torch')) {
        toolName = 'flashlight';
        parsed['state'] = 'on';
      } else if (feature.contains('wifi')) {
        toolName = 'wifi';
      } else if (feature.contains('bluetooth')) {
        toolName = 'bluetooth';
      }
    }

    // Normalise aliases → canonical tool names
    if (toolName == 'browser') toolName = 'open_chrome';
    if (toolName == 'torch') toolName = 'flashlight';
    if (toolName == 'note' || toolName == 'save_note') toolName = 'take_note';
    if (toolName == 'photo' || toolName == 'selfie' || toolName == 'pic') toolName = 'camera';
    if (toolName == 'launch_app' || toolName == 'launch' || toolName == 'open_app') toolName = 'app_launch';
    if (toolName == 'navigate' || toolName == 'navigation' || toolName == 'directions') toolName = 'maps';
    if (toolName == 'sms_send' || toolName == 'text' || toolName == 'message') toolName = 'sms';
    if (toolName == 'web_search' || toolName == 'google') toolName = 'search_web';
    if (toolName == 'memo') toolName = 'remember';
    if (toolName == 'copy') toolName = 'clipboard';
    if (toolName == 'do_not_disturb') toolName = 'dnd';
    if (toolName == 'airplane' || toolName == 'flight_mode') toolName = 'airplane_mode';
    if (toolName == 'record') toolName = 'recording';
    if (toolName == 'ring_photo' || toolName == 'ring_camera') toolName = 'ring_take_photo';
    if (toolName == 'automate' || toolName == 'ui' || toolName == 'tap' || toolName == 'click') toolName = 'ui_automate';
    // Zero Co-work aliases
    if (toolName == 'cowork' || toolName == 'zero_cowork_agent' || toolName == 'cowork_agent') toolName = 'zero_cowork';

    if (toolName == 'none' || toolName.isEmpty) {
      final reply = (parsed['reply'] as String?)?.trim() ?? '';
      debugPrint('[AgentRouter] -> conversational reply: $reply');
      return AgentRoute(
        toolName: '',
        isNone: true,
        reply: reply.isNotEmpty ? reply : null,
      );
    }

    if (!_kValidTools.contains(toolName)) {
      debugPrint('[AgentRouter] Unknown tool: $toolName');
      final reply = (parsed['reply'] as String?)?.trim();
      return AgentRoute(toolName: '', isNone: true, reply: reply);
    }

    final args = Map<String, dynamic>.from(parsed)..remove('tool');
    debugPrint('[AgentRouter] -> tool=$toolName args=$args');
    return AgentRoute(toolName: toolName, arguments: args);
  }
}
