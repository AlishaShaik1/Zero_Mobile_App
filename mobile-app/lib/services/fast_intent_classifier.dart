// fast_intent_classifier.dart
// Zero-latency keyword pre-classifier — handles ~95 % of voice commands
// without ANY LLM call. Falls through to null for ambiguous inputs so the
// AgentRouterService can do an LLM classification.
//
// Intent is matched by scanning tokenised words against ranked keyword sets.
// Order matters: more-specific checks come FIRST.

class FastIntentClassifier {
  FastIntentClassifier._();

  /// Returns a pre-built [AgentRouteResult] or null if the intent is ambiguous.
  /// [words] should be the lowercased, split tokens of the user utterance.
  static Map<String, dynamic>? classify(String utterance) {
    final q = utterance.toLowerCase().trim();
    final words = q.split(RegExp(r'\s+'));

    // ── Flashlight ──────────────────────────────────────────────────────────
    if (_has(words, ['flashlight', 'torch', 'flash'])) {
      final off = _has(words, ['off', 'disable', 'turn off', 'stop']);
      return {'tool': 'flashlight', 'state': off ? 'off' : 'on'};
    }

    // ── Wi-Fi ───────────────────────────────────────────────────────────────
    if (_has(words, ['wifi', 'wi-fi', 'wireless', 'internet'])) {
      final off = _has(words, ['off', 'disable', 'turn off', 'disconnect']);
      return {'tool': 'wifi', 'state': off ? 'off' : 'on'};
    }

    // ── Bluetooth ───────────────────────────────────────────────────────────
    if (_has(words, ['bluetooth', 'bt'])) {
      final off = _has(words, ['off', 'disable', 'turn off']);
      return {'tool': 'bluetooth', 'state': off ? 'off' : 'on'};
    }

    // ── Airplane mode ───────────────────────────────────────────────────────
    if (_has(words, ['airplane', 'flight', 'plane mode'])) {
      final off = _has(words, ['off', 'disable', 'turn off']);
      return {'tool': 'airplane_mode', 'state': off ? 'off' : 'on'};
    }

    // ── Hotspot ─────────────────────────────────────────────────────────────
    if (_has(words, ['hotspot', 'tethering', 'personal hotspot'])) {
      final off = _has(words, ['off', 'disable', 'turn off', 'stop']);
      return {'tool': 'hotspot', 'state': off ? 'off' : 'on'};
    }

    // ── Do Not Disturb ──────────────────────────────────────────────────────
    if (_has(words, ['do not disturb', 'dnd', 'silent mode', 'quiet'])) {
      final off = _has(words, ['off', 'disable', 'turn off']);
      return {'tool': 'dnd', 'state': off ? 'off' : 'on'};
    }

    // ── Brightness ──────────────────────────────────────────────────────────
    if (_has(words, ['brightness', 'screen brightness', 'dim', 'brighten'])) {
      final num = _extractNumber(q);
      if (num != null) return {'tool': 'brightness', 'value': num};
      final max = _has(words, ['max', 'full', 'maximum', '100']);
      final min = _has(words, ['min', 'minimum', 'low', 'lowest', '0']);
      if (max) return {'tool': 'brightness', 'value': 100};
      if (min) return {'tool': 'brightness', 'value': 0};
      return {'tool': 'brightness', 'value': 50};
    }

    // ── Volume ──────────────────────────────────────────────────────────────
    if (_has(words, ['volume', 'sound', 'ringer'])) {
      if (_has(words, ['mute', 'silence', 'silent'])) {
        return {'tool': 'volume', 'action': 'mute'};
      }
      if (_has(words, ['up', 'increase', 'raise', 'louder', 'higher'])) {
        return {'tool': 'volume', 'action': 'up'};
      }
      if (_has(words, ['down', 'decrease', 'lower', 'quieter'])) {
        return {'tool': 'volume', 'action': 'down'};
      }
      final num = _extractNumber(q);
      if (num != null) return {'tool': 'volume', 'value': num};
    }

    // ── Timer ───────────────────────────────────────────────────────────────
    if (_has(words, ['timer', 'countdown'])) {
      final dur = _extractDuration(q);
      return {'tool': 'timer', 'duration': dur ?? '1 minute'};
    }

    // ── Alarm ───────────────────────────────────────────────────────────────
    if (_has(words, ['alarm', 'wake me', 'wake me up', 'remind me'])) {
      final time = _extractTime(q);
      return {'tool': 'alarm', 'time': time ?? '07:00'};
    }

    // ── Time / Date ──────────────────────────────────────────────────────────
    if (_has(words, ['time', 'what time', "what's the time", 'current time'])) {
      return {'tool': 'get_datetime'};
    }
    if (_has(words, ['date', 'today', "what's today", 'what day'])) {
      return {'tool': 'get_datetime'};
    }

    // ── Screenshot ──────────────────────────────────────────────────────────
    if (_has(words, ['screenshot', 'screen capture', 'capture screen'])) {
      return {'tool': 'screenshot'};
    }

    // ── Ring Camera / Photo ────────────────────────────────────────────────
    if (_has(words, [
      'ring pic',
      'ring photo',
      'take pic',
      'take photo',
      'ring camera',
      'photo with ring',
      'picture with ring',
      'pic with ring',
      'camera on ring',
      'take a picture',
      'take picture',
    ])) {
      return {'tool': 'ring_take_photo'};
    }

    // ── Take Note ────────────────────────────────────────────────────────────
    if (_has(words, [
      'take note',
      'save note',
      'write note',
      'create note',
      'note that',
      'add note',
      'take a note',
      'jot down',
    ])) {
      final note = _extractNote(q);
      return {'tool': 'take_note', 'note': note ?? q};
    }

    // ── Camera ──────────────────────────────────────────────────────────────
    if (_has(words, ['selfie', 'front camera', 'front photo'])) {
      return {'tool': 'camera', 'action': 'front'};
    }
    if (_has(words, [
      'rear camera',
    ])) {
      return {'tool': 'camera', 'action': 'rear'};
    }

    // ── Call ────────────────────────────────────────────────────────────────
    if (_has(words, ['call', 'phone', 'ring', 'dial'])) {
      final contact = _extractContact(q, ['call', 'phone', 'ring', 'dial']);
      if (contact != null) return {'tool': 'call', 'contact': contact};
    }

    // ── SMS ─────────────────────────────────────────────────────────────────
    if (_has(words, ['text', 'message', 'sms', 'send message', 'send text'])) {
      // Extract contact after "text/message/sms to" and message after "saying"
      final contactAndMsg = _extractSms(q);
      if (contactAndMsg != null) return {'tool': 'sms', ...contactAndMsg};
    }

    // ── WhatsApp ────────────────────────────────────────────────────────────
    if (_has(words, ['whatsapp', 'whats app'])) {
      final contact = _extractContact(q, [
        'whatsapp',
        'whats app',
        'message on',
      ]);
      if (contact != null) return {'tool': 'whatsapp', 'contact': contact};
    }

    // ── Maps / Navigate ──────────────────────────────────────────────────────
    if (_has(words, [
      'navigate',
      'directions',
      'maps',
      'go to',
      'take me to',
      'route to',
    ])) {
      final dest = _extractDestination(q);
      if (dest != null) return {'tool': 'maps', 'destination': dest};
    }

    // ── Web Search ──────────────────────────────────────────────────────────
    if (_has(words, [
      'search',
      'google',
      'look up',
      'find',
      'who is',
      'what is',
      'how to',
      'when is',
    ])) {
      // Only route as web search if it's clearly an external knowledge query
      if (_has(words, ['search for', 'search', 'google', 'look up'])) {
        final query = _extractSearchQuery(q);
        if (query != null) return {'tool': 'search_web', 'query': query};
      }
    }

    // ── Browser ─────────────────────────────────────────────────────────────
    if (_has(words, [
      'browser',
      'open browser',
      'open chrome',
      'chrome',
      'safari',
    ])) {
      final url = _extractUrl(q);
      if (url != null) return {'tool': 'browser', 'url': url};
      return {'tool': 'browser'};
    }
    if (q.contains('.com') ||
        q.contains('.in') ||
        q.contains('.org') ||
        q.contains('.net')) {
      final url = _extractUrl(q);
      if (url != null) return {'tool': 'browser', 'url': url};
    }

    // ── App Launch ──────────────────────────────────────────────────────────
    if (_has(words, ['open', 'launch', 'start'])) {
      final app = _extractAppName(q, words);
      if (app != null) return {'tool': 'app_launch', 'app': app};
    }

    // ── Settings ────────────────────────────────────────────────────────────
    if (_has(words, ['settings', 'setting', 'preferences', 'setup'])) {
      return {'tool': 'settings'};
    }

    // ── Contacts ────────────────────────────────────────────────────────────
    if (_has(words, ['contacts', 'contact list', 'phone book'])) {
      return {'tool': 'contacts'};
    }

    // ── Calendar ────────────────────────────────────────────────────────────
    if (_has(words, ['calendar', 'schedule', 'events', 'agenda'])) {
      return {'tool': 'calendar'};
    }

    // ── Music ────────────────────────────────────────────────────────────────
    if (_has(words, ['play music', 'play song', 'music', 'spotify', 'play'])) {
      if (_has(words, ['next', 'skip'])) {
        return {'tool': 'play_music', 'action': 'next'};
      }
      if (_has(words, ['previous', 'back', 'prev'])) {
        return {'tool': 'play_music', 'action': 'previous'};
      }
      if (_has(words, ['pause', 'stop music'])) {
        return {'tool': 'play_music', 'action': 'pause'};
      }
      return {'tool': 'play_music', 'action': 'play'};
    }

    // ── Recording ───────────────────────────────────────────────────────────
    if (_has(words, ['record', 'voice recorder', 'voice note', 'recording'])) {
      final stop = _has(words, ['stop', 'end', 'finish']);
      return {'tool': 'recording', 'state': stop ? 'stop' : 'start'};
    }

    // ── Clipboard ───────────────────────────────────────────────────────────
    if (_has(words, ['clipboard', 'copy', 'paste'])) {
      return {
        'tool': 'clipboard',
        'action': _has(words, ['paste']) ? 'paste' : 'copy',
      };
    }

    // ── Share ───────────────────────────────────────────────────────────────
    if (_has(words, ['share', 'send this', 'share this'])) {
      return {'tool': 'share'};
    }

    // ── Memory ──────────────────────────────────────────────────────────────
    if (_has(words, ['remember', 'note', 'save', 'keep in mind'])) {
      final note = _extractNote(q);
      return {'tool': 'remember', 'note': note ?? q};
    }

    // Ambiguous — fall through to LLM
    return null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static bool _has(List<String> words, List<String> targets) {
    for (final t in targets) {
      if (t.contains(' ')) {
        // Multi-word: check raw utterance via join
        if (words.join(' ').contains(t)) return true;
      } else {
        if (words.contains(t)) return true;
      }
    }
    return false;
  }

  static int? _extractNumber(String q) {
    final m = RegExp(r'\b(\d+)\b').firstMatch(q);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  static String? _extractDuration(String q) {
    final m = RegExp(
      r'(\d+)\s*(hour|hr|minute|min|second|sec)s?',
      caseSensitive: false,
    ).firstMatch(q);
    if (m != null) return '${m.group(1)} ${m.group(2)}s';
    return null;
  }

  static String? _extractTime(String q) {
    // HH:MM or H AM/PM patterns
    final m1 = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(q);
    if (m1 != null) return '${m1.group(1)!.padLeft(2, '0')}:${m1.group(2)}';
    final m2 = RegExp(
      r'(\d{1,2})\s*(am|pm)',
      caseSensitive: false,
    ).firstMatch(q);
    if (m2 != null) {
      int hour = int.parse(m2.group(1)!);
      if (m2.group(2)!.toLowerCase() == 'pm' && hour != 12) hour += 12;
      if (m2.group(2)!.toLowerCase() == 'am' && hour == 12) hour = 0;
      return '${hour.toString().padLeft(2, '0')}:00';
    }
    return null;
  }

  static String? _extractContact(String q, List<String> skipWords) {
    var result = q;
    for (final w in skipWords) {
      result = result.replaceAll(RegExp(w, caseSensitive: false), '').trim();
    }
    result = result
        .replaceAll(
          RegExp(r'\b(my|the|to|please|and|now)\b', caseSensitive: false),
          '',
        )
        .trim();
    return result.isEmpty ? null : result;
  }

  static Map<String, String>? _extractSms(String q) {
    final contactMatch = RegExp(
      r'(?:text|message|sms)\s+(\w+)',
      caseSensitive: false,
    ).firstMatch(q);
    final msgMatch = RegExp(
      r'saying\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(q);
    if (contactMatch != null) {
      return {
        'contact': contactMatch.group(1)!,
        'message': msgMatch?.group(1) ?? '',
      };
    }
    return null;
  }

  static String? _extractDestination(String q) {
    final m = RegExp(
      r'(?:navigate|directions|go|take me|route)\s+to\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(q);
    return m?.group(1)?.trim();
  }

  static String? _extractSearchQuery(String q) {
    final m = RegExp(
      r'(?:search for|search|google|look up)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(q);
    return m?.group(1)?.trim();
  }

  static String? _extractUrl(String q) {
    final m = RegExp(
      r'([\w-]+\.(?:com|org|net|in|io|co|gov|edu)[^\s]*)',
      caseSensitive: false,
    ).firstMatch(q);
    return m?.group(1);
  }

  static String? _extractAppName(String q, List<String> words) {
    // Blocklist: don't treat these as app names
    const blocklist = {'settings', 'browser', 'contacts', 'calendar'};
    var result = q;
    for (final w in [
      'open',
      'launch',
      'start',
      'app',
      'the',
      'please',
      'now',
    ]) {
      result = result
          .replaceAll(RegExp(r'\b' + w + r'\b', caseSensitive: false), '')
          .trim();
    }
    result = result.trim();
    if (result.isEmpty || blocklist.contains(result.toLowerCase())) return null;
    // Capitalize properly
    return result
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String? _extractNote(String q) {
    final m = RegExp(
      r'(?:remember|note|save|keep in mind)\s+(?:that\s+)?(.+)$',
      caseSensitive: false,
    ).firstMatch(q);
    return m?.group(1)?.trim();
  }
}
