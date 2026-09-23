import 'package:flutter/services.dart';
import 'memory_store.dart';
import 'ring_ble_service.dart';
import 'ring_reply_sender.dart';

class ToolDefinition {
  final String name;
  final String description;
  final List<String> requiredParams;
  final bool isIrreversible;
  final Future<String> Function(Map<String, dynamic> args) handler;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.requiredParams,
    this.isIrreversible = false,
    required this.handler,
  });
}

class ToolRegistry {
  static const MethodChannel _channel = MethodChannel(
    'com.example.zero_air/tools',
  );

  static final Map<String, ToolDefinition> tools = {
    // ── 1. FLASHLIGHT ─────────────────────────────────────────────────────────
    'flashlight': ToolDefinition(
      name: 'flashlight',
      description: 'Turn flashlight on or off.',
      requiredParams: ['state'],
      handler: (args) async {
        try {
          final bool state = args['state']?.toString().toLowerCase() == 'on';
          await _channel.invokeMethod('toggle_torch', {'state': state});
          return 'Torch turned ${state ? 'on' : 'off'}.';
        } catch (e) {
          return 'Failed to toggle torch: $e';
        }
      },
    ),

    // ── 2. WIFI ────────────────────────────────────────────────────────────────
    'wifi': ToolDefinition(
      name: 'wifi',
      description: 'Open WiFi settings panel.',
      requiredParams: [],
      handler: (args) async {
        try {
          await _channel.invokeMethod('toggle_wifi');
          return 'Opened WiFi settings panel.';
        } catch (e) {
          return 'Failed to open WiFi settings: $e';
        }
      },
    ),

    // ── 3. BLUETOOTH ───────────────────────────────────────────────────────────
    'bluetooth': ToolDefinition(
      name: 'bluetooth',
      description: 'Open Bluetooth settings.',
      requiredParams: [],
      handler: (args) async {
        try {
          await _channel.invokeMethod('toggle_bluetooth');
          return 'Opened Bluetooth settings.';
        } catch (e) {
          return 'Failed to open Bluetooth settings: $e';
        }
      },
    ),

    // ── 4. BRIGHTNESS ──────────────────────────────────────────────────────────
    'brightness': ToolDefinition(
      name: 'brightness',
      description: 'Set screen brightness (0-255).',
      requiredParams: ['level'],
      handler: (args) async {
        try {
          final level = int.tryParse(args['level'].toString()) ?? 128;
          await _channel.invokeMethod('set_brightness', {
            'level': level.clamp(0, 255),
          });
          return 'Brightness set to $level.';
        } catch (e) {
          return 'Failed to set brightness: $e';
        }
      },
    ),

    // ── 5. VOLUME ──────────────────────────────────────────────────────────────
    'volume': ToolDefinition(
      name: 'volume',
      description: 'Set media volume (0-15).',
      requiredParams: ['level'],
      handler: (args) async {
        try {
          final level = int.tryParse(args['level'].toString()) ?? 7;
          await _channel.invokeMethod('set_volume', {
            'level': level.clamp(0, 15),
          });
          return 'Volume set to $level.';
        } catch (e) {
          return 'Failed to set volume: $e';
        }
      },
    ),

    // ── 6. SCREENSHOT ──────────────────────────────────────────────────────────
    'screenshot': ToolDefinition(
      name: 'screenshot',
      description: 'Take a screenshot.',
      requiredParams: [],
      handler: (args) async {
        try {
          await _channel.invokeMethod('take_screenshot');
          return 'Screenshot captured.';
        } catch (e) {
          return 'Failed to take screenshot: $e';
        }
      },
    ),

    // ── 7. TIMER ───────────────────────────────────────────────────────────────
    'timer': ToolDefinition(
      name: 'timer',
      description: 'Set a countdown timer.',
      requiredParams: ['duration_minutes'],
      handler: (args) async {
        try {
          final duration =
              int.tryParse(args['duration_minutes'].toString()) ?? 1;
          await _channel.invokeMethod('set_timer', {
            'duration_minutes': duration,
          });
          return 'Timer set for $duration minute${duration == 1 ? '' : 's'}.';
        } catch (e) {
          return 'Failed to set timer: $e';
        }
      },
    ),

    // ── 8. ALARM ───────────────────────────────────────────────────────────────
    'alarm': ToolDefinition(
      name: 'alarm',
      description: 'Set an alarm/reminder.',
      requiredParams: ['title', 'time_offset_minutes'],
      handler: (args) async {
        try {
          final offset =
              int.tryParse(args['time_offset_minutes'].toString()) ?? 10;
          await _channel.invokeMethod('set_reminder', {
            'title': args['title'] ?? 'Reminder',
            'time_offset_minutes': offset,
          });
          return 'Alarm set: "${args['title']}".';
        } catch (e) {
          return 'Failed to set alarm: $e';
        }
      },
    ),

    // ── 9. EMAIL ───────────────────────────────────────────────────────────────
    'email': ToolDefinition(
      name: 'email',
      description: 'Compose email with pre-filled fields.',
      requiredParams: ['to', 'subject', 'body'],
      isIrreversible: true,
      handler: (args) async {
        try {
          await _channel.invokeMethod('send_email', {
            'to': args['to'] ?? '',
            'subject': args['subject'] ?? '',
            'body': args['body'] ?? '',
          });
          return 'Email composed for ${args['to']}.';
        } catch (e) {
          return 'Failed to open email: $e';
        }
      },
    ),

    // ── 10. WHATSAPP ───────────────────────────────────────────────────────────
    'whatsapp': ToolDefinition(
      name: 'whatsapp',
      description: 'Open WhatsApp with pre-filled message.',
      requiredParams: ['contact_name', 'message_body'],
      isIrreversible: true,
      handler: (args) async {
        try {
          await _channel.invokeMethod('send_whatsapp_message', {
            'contact_name': args['contact_name'] ?? '',
            'message_body': args['message_body'] ?? '',
          });
          return 'WhatsApp opened for ${args['contact_name']}. Tap send.';
        } catch (e) {
          return 'Failed to open WhatsApp: $e';
        }
      },
    ),

    // ── 11. CALL ───────────────────────────────────────────────────────────────
    'call': ToolDefinition(
      name: 'call',
      description: 'Dial a contact or phone number.',
      requiredParams: ['contact'],
      isIrreversible: true,
      handler: (args) async {
        try {
          await _channel.invokeMethod('make_call', {
            'contact': args['contact'] ?? '',
          });
          return 'Dialing ${args['contact']}…';
        } catch (e) {
          return 'Failed to make call: $e';
        }
      },
    ),

    // ── 12. SMS ────────────────────────────────────────────────────────────────
    'sms': ToolDefinition(
      name: 'sms',
      description: 'Open SMS composer with pre-filled message.',
      requiredParams: ['contact', 'message'],
      isIrreversible: true,
      handler: (args) async {
        try {
          await _channel.invokeMethod('send_sms', {
            'contact': args['contact'] ?? '',
            'message': args['message'] ?? '',
          });
          return 'SMS composer opened for ${args['contact']}.';
        } catch (e) {
          return 'Failed to open SMS: $e';
        }
      },
    ),

    // ── 13. BROWSER ────────────────────────────────────────────────────────────
    'browser': ToolDefinition(
      name: 'browser',
      description: 'Open a URL or search query in browser.',
      requiredParams: ['url'],
      handler: (args) async {
        try {
          String url = args['url']?.toString() ?? '';
          if (!url.startsWith('http')) url = 'https://$url';
          await _channel.invokeMethod('open_browser', {'url': url});
          return 'Opened $url in browser.';
        } catch (e) {
          return 'Failed to open browser: $e';
        }
      },
    ),

    // ── 14. MAPS ───────────────────────────────────────────────────────────────
    'maps': ToolDefinition(
      name: 'maps',
      description: 'Open Google Maps for a destination.',
      requiredParams: ['query'],
      handler: (args) async {
        try {
          await _channel.invokeMethod('open_maps', {
            'query': args['query'] ?? '',
          });
          return 'Maps opened for "${args['query']}".';
        } catch (e) {
          return 'Failed to open Maps: $e';
        }
      },
    ),

    // ── 15. APP LAUNCH ─────────────────────────────────────────────────────────
    'app_launch': ToolDefinition(
      name: 'app_launch',
      description: 'Launch an installed app by name.',
      requiredParams: ['app_name'],
      handler: (args) async {
        try {
          await _channel.invokeMethod('launch_app', {
            'app_name': args['app_name'] ?? '',
          });
          return 'Launching ${args['app_name']}…';
        } catch (e) {
          return 'Failed to launch app: $e';
        }
      },
    ),

    // ── 16. SETTINGS ───────────────────────────────────────────────────────────
    'settings': ToolDefinition(
      name: 'settings',
      description: 'Open a specific Android settings screen.',
      requiredParams: ['setting'],
      handler: (args) async {
        try {
          await _channel.invokeMethod('open_settings', {
            'setting': args['setting'] ?? 'main',
          });
          return 'Opened ${args['setting']} settings.';
        } catch (e) {
          return 'Failed to open settings: $e';
        }
      },
    ),

    // ── 17. SHARE ──────────────────────────────────────────────────────────────
    'share': ToolDefinition(
      name: 'share',
      description: 'Share text via Android share sheet.',
      requiredParams: ['text'],
      handler: (args) async {
        try {
          await _channel.invokeMethod('share_text', {
            'text': args['text'] ?? '',
          });
          return 'Share sheet opened.';
        } catch (e) {
          return 'Failed to share: $e';
        }
      },
    ),

    // ── 18. CLIPBOARD ──────────────────────────────────────────────────────────
    'clipboard': ToolDefinition(
      name: 'clipboard',
      description: 'Copy text to clipboard.',
      requiredParams: ['text'],
      handler: (args) async {
        try {
          await Clipboard.setData(ClipboardData(text: args['text'] ?? ''));
          return 'Copied to clipboard.';
        } catch (e) {
          return 'Failed to copy: $e';
        }
      },
    ),

    // ── 19. CALENDAR ───────────────────────────────────────────────────────────
    'calendar': ToolDefinition(
      name: 'calendar',
      description: 'Open calendar or create an event.',
      requiredParams: [],
      handler: (args) async {
        try {
          await _channel.invokeMethod('open_calendar', {
            'title': args['title'] ?? '',
            'time': args['time'] ?? '',
          });
          return 'Calendar opened${args['title']?.isNotEmpty == true ? ' for "${args['title']}"' : ''}.';
        } catch (e) {
          return 'Failed to open calendar: $e';
        }
      },
    ),

    // ── 20. CONTACTS ───────────────────────────────────────────────────────────
    'contacts': ToolDefinition(
      name: 'contacts',
      description: 'Open the contacts app.',
      requiredParams: [],
      handler: (args) async {
        try {
          await _channel.invokeMethod('open_contacts');
          return 'Contacts opened.';
        } catch (e) {
          return 'Failed to open contacts: $e';
        }
      },
    ),

    // ── 21. UI_AUTOMATE ────────────────────────────────────────────────────────
    'ui_automate': ToolDefinition(
      name: 'ui_automate',
      description:
          'Automate UI interactions in any app (tap, scroll, type, back) via AccessibilityService.',
      requiredParams: ['action'],
      handler: (args) async {
        try {
          final action = (args['action'] ?? args['goal'] ?? '').toString();
          if (action.isEmpty) return 'No UI action specified.';
          final success = await _channel.invokeMethod<bool>('ui_automate_perform_action', {
            'action': action,
          });
          return success == true ? 'Action performed: $action' : 'Failed to perform: $action';
        } catch (e) {
          return 'UI Automate error: $e';
        }
      },
    ),

    // ── 21b. CHROME AUTOMISER ─────────────────────────────────────────────────
    'open_chrome': ToolDefinition(
      name: 'open_chrome',
      description: 'Open Google Chrome with a search query or URL.',
      requiredParams: ['query'],
      handler: (args) async {
        try {
          final query = (args['query'] ?? args['url'] ?? args['target'] ?? '').toString();
          final url = query.startsWith('http') ? query : 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
          await _channel.invokeMethod('open_browser', {'url': url});
          return 'Chrome opened for "$query".';
        } catch (e) {
          return 'Failed to open Chrome: $e';
        }
      },
    ),

    // ── 22. REMEMBER (memory tool) ─────────────────────────────────────────────
    'remember': ToolDefinition(
      name: 'remember',
      description: 'Persist a note or fact to long-term memory.',
      requiredParams: ['note'],
      handler: (args) async {
        try {
          final note = args['note']?.toString() ?? '';
          if (note.isEmpty) return 'Nothing to remember.';
          await MemoryStore.instance.storeNote(note);
          return 'Remembered: "$note"';
        } catch (e) {
          return 'Failed to store memory: $e';
        }
      },
    ),

    // ── SEARCH / DATETIME (internal tools) ─────────────────────────────────────
    'search_web': ToolDefinition(
      name: 'search_web',
      description: 'Search the web for information.',
      requiredParams: ['query'],
      handler: (args) async => 'Search completed.',
    ),

    'get_datetime': ToolDefinition(
      name: 'get_datetime',
      description: 'Get the current date and time.',
      requiredParams: [],
      handler: (args) async => 'Current date/time: ${DateTime.now()}',
    ),

    // ── 23. PLAY MUSIC ─────────────────────────────────────────────────────────
    'play_music': ToolDefinition(
      name: 'play_music',
      description: 'Resolve a song/artist/playlist and play it in Spotify.',
      requiredParams: ['query'],
      handler: (args) async {
        return 'play_music_delegated';
      },
    ),

    // ── 24. RING TAKE PHOTO ───────────────────────────────────────────────────
    'ring_take_photo': ToolDefinition(
      name: 'ring_take_photo',
      description: 'Trigger smart ring onboard camera to take a photo.',
      requiredParams: [],
      handler: (args) async {
        try {
          if (!RingBleService.instance.isConnected) return 'Ring is not connected.';
          await RingReplySender.instance.sendCommand('take_photo');
          return 'Ring camera photo capture triggered.';
        } catch (e) {
          return 'Failed to trigger ring camera: $e';
        }
      },
    ),

    // ── 25. TAKE NOTE ─────────────────────────────────────────────────────────
    'take_note': ToolDefinition(
      name: 'take_note',
      description: 'Save a text note or reminder to user storage.',
      requiredParams: ['note'],
      handler: (args) async {
        try {
          final note = args['note']?.toString() ?? '';
          if (note.isEmpty) return 'No note text provided.';
          await MemoryStore.instance.storeNote(note);
          return 'Note saved: "$note"';
        } catch (e) {
          return 'Failed to save note: $e';
        }
      },
    ),
  };

  /// All canonical tool names used by the planner (21 tools + remember).
  static const List<String> allPlannerTools = [
    'toggle_torch',
    'toggle_wifi',
    'toggle_bluetooth',
    'set_brightness',
    'set_volume',
    'take_screenshot',
    'set_timer',
    'set_reminder',
    'send_email',
    'send_whatsapp_message',
    'make_call',
    'send_sms',
    'open_browser',
    'open_maps',
    'launch_app',
    'open_settings',
    'share_text',
    'copy_to_clipboard',
    'open_calendar',
    'open_contacts',
    'ui_automate',
    'remember',
    'play_music',
  ];

  static String getClassifierRegistrySchema() =>
      tools.entries.map((e) => '${e.key}: ${e.value.description}').join('\n');
}
