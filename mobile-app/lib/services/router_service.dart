// router_service.dart — Pure LLM Router
// Every message goes through the model. No hardcoded regex shortcuts.

class RouteResult {
  final RouteType type;
  final String? hardcodedResponse;
  final String? detectedTool;
  const RouteResult(this.type, {this.hardcodedResponse, this.detectedTool});
}

enum RouteType {
  identity,
  greeting,
  systemAction,
  search,
  dateTime,
  multiAction,
  memory,
  chat,
}

class RouterService {
  static bool bypassesLLM(RouteResult result) => false;

  static bool requiresPlanner(RouteResult result) {
    return result.type == RouteType.multiAction;
  }

  static Future<RouteResult> determineRoute(
    String input,
    dynamic modelService,
  ) async {
    try {
      const sysPrompt =
          'You are a strict system router. Pick exactly ONE tool for the user command.\n'
          'TOOLS: flashlight, wifi, bluetooth, hotspot, airplane_mode, dnd, brightness, volume, screenshot, camera, timer, alarm, email, whatsapp, call, sms, calendar, contacts, clipboard, share, settings, app_launch, play_music, browser, ui_automate\n'
          'If conversational, reply NONE. If multiple tasks, reply MULTI.\n'
          'Rules: Reply with ONLY the exact tool name from the list, or MULTI, or NONE. NO extra words.';

      final userPrompt = 'USER: "$input" →';

      final raw = await modelService.generateOneShot(
        sysPrompt,
        userPrompt,
        maxTokens: 15,
      );
      final rawStr = raw.toString().trim();
      final rawLower = rawStr.toLowerCase();

      if (rawLower.isEmpty || rawLower == 'none' || rawLower == 'chat') {
        return const RouteResult(RouteType.chat);
      }

      if (rawLower.startsWith('multi')) {
        return const RouteResult(RouteType.multiAction);
      }

      const validTools = [
        'flashlight',
        'wifi',
        'hotspot',
        'bluetooth',
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
        'browser',
        'ui_automate',
        'play_music',
      ];

      for (final tool in validTools) {
        if (rawLower.contains(tool)) {
          return RouteResult(RouteType.systemAction, detectedTool: tool);
        }
      }
    } catch (_) {}

    return const RouteResult(RouteType.chat);
  }
}
