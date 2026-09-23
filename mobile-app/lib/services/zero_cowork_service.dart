// zero_cowork_service.dart
// Integrates the Zero Co-work cloud browser agent via zerolabs.live API.
// API spec: app_integration_guide.md  (all endpoints verified working)
//
// Flow: start session → run agent → stream SSE events → yield strings to UI

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ZeroCoworkEvent {
  final String type;
  final Map<String, dynamic> data;
  final String? timestamp;
  final int? modelCallCount;

  const ZeroCoworkEvent({
    required this.type,
    this.data = const {},
    this.timestamp,
    this.modelCallCount,
  });

  factory ZeroCoworkEvent.fromJson(Map<String, dynamic> j) => ZeroCoworkEvent(
        type: (j['type'] as String?) ?? 'unknown',
        data: (j['data'] as Map<String, dynamic>?) ?? {},
        timestamp: j['timestamp'] as String?,
        modelCallCount: j['modelCallCount'] as int?,
      );
}

class ZeroCoworkService {
  ZeroCoworkService._();
  static final ZeroCoworkService instance = ZeroCoworkService._();

  static const String _server = 'https://zerolabs.live';
  static const Duration _httpTimeout = Duration(seconds: 15);

  String? _sessionId;
  String? _taskId;
  bool _running = false;

  bool get isRunning => _running;
  String? get sessionId => _sessionId;
  String? get taskId => _taskId;

  // ── 1. Start browser session ────────────────────────────────────────────────
  Future<String?> _startSession({String url = 'https://google.com'}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_server/api/session/start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(_httpTimeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final sid = body['sessionId'] as String?;
        debugPrint('[ZeroCowork] Session: $sid');
        return sid;
      }
      debugPrint('[ZeroCowork] session/start ${res.statusCode}: ${res.body}');
      return null;
    } catch (e) {
      debugPrint('[ZeroCowork] session/start error: $e');
      return null;
    }
  }

  // ── 2. Run agent on task ────────────────────────────────────────────────────
  Future<String?> _runAgent(String sessionId, String task) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_server/api/agent/run'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'sessionId': sessionId, 'task': task}),
          )
          .timeout(_httpTimeout);

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final tid = body['taskId'] as String?;
        debugPrint('[ZeroCowork] Task: $tid');
        return tid;
      }
      debugPrint('[ZeroCowork] agent/run ${res.statusCode}: ${res.body}');
      return null;
    } catch (e) {
      debugPrint('[ZeroCowork] agent/run error: $e');
      return null;
    }
  }

  // ── 3. Send prompt to running agent ─────────────────────────────────────────
  Future<bool> sendPrompt(String message) async {
    if (_taskId == null || _sessionId == null) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$_server/api/agent/message'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'taskId': _taskId,
              'sessionId': _sessionId,
              'message': message,
            }),
          )
          .timeout(_httpTimeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        debugPrint('[ZeroCowork] Prompt injected: ${body['injected']}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[ZeroCowork] agent/message error: $e');
      return false;
    }
  }

  // ── 4. Unblock paused agent ─────────────────────────────────────────────────
  Future<void> unblock([String instruction = 'continue']) async {
    if (_taskId == null || _sessionId == null) return;
    try {
      await http
          .post(
            Uri.parse('$_server/api/agent/unblock'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sessionId': _sessionId,
              'taskId': _taskId,
              'instruction': instruction,
            }),
          )
          .timeout(_httpTimeout);
      debugPrint('[ZeroCowork] Unblocked');
    } catch (e) {
      debugPrint('[ZeroCowork] agent/unblock error: $e');
    }
  }

  // ── 5. Session status ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getStatus() async {
    if (_sessionId == null) return null;
    try {
      final res = await http
          .get(Uri.parse('$_server/api/session/status?sessionId=$_sessionId'))
          .timeout(_httpTimeout);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── MAIN ENTRY: execute task, stream UI lines ───────────────────────────────
  Stream<String> execute(String task) async* {
    if (_running) {
      yield 'A Zero Co-work task is already running. Send a follow-up prompt instead.';
      return;
    }
    _running = true;

    try {
      yield 'Starting browser session…';
      final sid = await _startSession();
      if (sid == null) {
        yield 'Failed to start browser session. Check connection to zerolabs.live.';
        return;
      }
      _sessionId = sid;
      yield 'Session ready (${sid.length > 12 ? sid.substring(0, 12) : sid}…)';

      yield 'Launching AI agent on task: "$task"…';
      final tid = await _runAgent(sid, task);
      if (tid == null) {
        yield 'Failed to launch agent. Server may be busy — try again.';
        return;
      }
      _taskId = tid;
      yield 'Agent running (${tid.length > 12 ? tid.substring(0, 12) : tid}…)';
      yield 'Streaming live events…\n';

      yield* _streamEvents(tid);
    } finally {
      _running = false;
    }
  }

  // ── SSE streaming ───────────────────────────────────────────────────────────
  Stream<String> _streamEvents(String taskId) async* {
    final uri = Uri.parse('$_server/api/agent/subscribe?taskId=$taskId');
    final client = http.Client();
    try {
      final req = http.Request('GET', uri);
      req.headers['Accept'] = 'text/event-stream';
      req.headers['Cache-Control'] = 'no-cache';

      final response = await client.send(req).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException('SSE connect timeout'),
      );

      if (response.statusCode != 200) {
        yield 'Could not connect to live events (HTTP ${response.statusCode})';
        return;
      }

      final buf = StringBuffer();
      await for (final chunk in response.stream
          .timeout(const Duration(minutes: 5))
          .transform(utf8.decoder)) {
        buf.write(chunk);
        String raw = buf.toString();

        while (raw.contains('\n\n')) {
          final idx = raw.indexOf('\n\n');
          final block = raw.substring(0, idx).trim();
          raw = raw.substring(idx + 2);
          buf.clear();
          buf.write(raw);

          if (block.isEmpty || block.startsWith(':')) continue;

          final dataLine = block
              .split('\n')
              .firstWhere((l) => l.startsWith('data:'), orElse: () => '');
          if (dataLine.isEmpty) continue;

          final jsonStr = dataLine.substring(5).trim();
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

          ZeroCoworkEvent? ev;
          try {
            ev = ZeroCoworkEvent.fromJson(
              jsonDecode(jsonStr) as Map<String, dynamic>,
            );
          } catch (_) {
            continue;
          }

          debugPrint('[ZeroCowork/SSE] ${ev.type}: ${ev.data}');
          final text = _formatEvent(ev);
          if (text != null) yield text;

          if (ev.type == 'task_done' || ev.type == 'error') return;
        }
      }
    } on TimeoutException {
      yield 'Connection timed out waiting for agent.';
    } catch (e) {
      yield 'Stream error: $e';
    } finally {
      client.close();
    }
  }

  String? _formatEvent(ZeroCoworkEvent ev) {
    switch (ev.type) {
      case 'action':
        final action = ev.data['action'] ?? '';
        final url = ev.data['url'] ?? '';
        final text = ev.data['text'] ?? '';
        final ref = ev.data['ref']?.toString() ?? '';
        if (text.isNotEmpty) return '$action: "$text"';
        if (url.isNotEmpty) return '$action → $url';
        if (ref.isNotEmpty) return '$action [ref:$ref]';
        return ev.data.toString();
      case 'navigate':
        return 'Navigate → ${ev.data['url'] ?? ''}';
      case 'think':
        return 'Thinking: ${ev.data['thought'] ?? ev.data}';
      case 'task_done':
        final s = ev.data['summary'] ?? ev.data['result'] ?? 'Task complete';
        return '\nDone: $s';
      case 'blocked':
        final r = ev.data['reason'] ?? 'needs input';
        return '\nAgent blocked: $r\n(Reply with "continue" or a new instruction)';
      case 'error':
        return '\nAgent error: ${ev.data['message'] ?? ev.data}';
      case 'ping':
      case 'heartbeat':
        return null;
      default:
        return ev.data.isNotEmpty ? '${ev.type}: ${ev.data}' : null;
    }
  }
}
