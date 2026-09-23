import sys

TARGET = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion\lib\services\ring_audio_pipeline.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    content = f.read()

# ── 1. Add missing imports (ToolExecutorService + SearchService) ──────────────
OLD_IMPORTS = """import 'agent_router_service.dart';
import 'phone_mic_stt_service.dart';
import 'ring_ble_service.dart';
import 'ring_reply_sender.dart';"""

NEW_IMPORTS = """import 'agent_router_service.dart';
import 'model_service.dart';
import 'phone_mic_stt_service.dart';
import 'ring_ble_service.dart';
import 'ring_reply_sender.dart';
import 'search_service.dart';
import 'tool_executor_service.dart';"""

if OLD_IMPORTS in content:
    content = content.replace(OLD_IMPORTS, NEW_IMPORTS, 1)
    print('[OK] Added imports')
else:
    print('[WARN] Old imports block not found - checking partial match...')
    # Try without phone_mic_stt_service if block differs
    ALT_IMPORTS = """import 'agent_router_service.dart';"""
    if ALT_IMPORTS in content and 'tool_executor_service.dart' not in content:
        content = content.replace(
            ALT_IMPORTS,
            ALT_IMPORTS + "\nimport 'model_service.dart';\nimport 'search_service.dart';\nimport 'tool_executor_service.dart';",
            1
        )
        print('[OK] Added imports via alt path')

# ── 2. Add _executor field after _initialized = false declaration ─────────────
OLD_FIELD = "  bool _initialized = false;"
NEW_FIELD = """  bool _initialized = false;

  // Agentic tool executor (shared singletons — same ModelService() factory)
  late final ToolExecutorService _executor =
      ToolExecutorService(ModelService(), SearchService());"""

if OLD_FIELD in content and '_executor' not in content:
    content = content.replace(OLD_FIELD, NEW_FIELD, 1)
    print('[OK] Added _executor field')
else:
    print('[WARN] _executor field: skipping (already present or field not found)')

# ── 3. Replace _processUtteranceWithTranscript with agentic version ───────────
OLD_PROCESS = '''  // ---------------------------------------------------------------------------
  // AI Processing - direct GLM chat
  // ---------------------------------------------------------------------------

  Future<void> _processUtteranceWithTranscript(String transcript) async {
    _setState(RingPipelineState.thinking);

    String chatReply = '';

    try {
      chatReply = await _fireworksChat(transcript);

      if (chatReply.trim().isEmpty) {
        chatReply = 'Sorry, could not get a response. Please try again!';
      }

      debugPrint('[RingPipeline] Final reply: "$chatReply"');
      _liveAiResponseController.add(chatReply);

      final result = RingPipelineResult(
        transcript: transcript,
        route: const AgentRoute(toolName: 'none', isNone: true),
        chatReply: chatReply,
        timestamp: DateTime.now(),
      );
      _resultController.add(result);
      await _sendReplyToRing(result);
    } catch (e, st) {
      debugPrint('[RingPipeline] Fatal error: $e\\n$st');
    } finally {
      _processingUtterance = false;
      _setState(RingPipelineState.idle);
    }
  }'''

NEW_PROCESS = '''  // ---------------------------------------------------------------------------
  // AI Processing — AgentRouter → ToolExecutor (agentic) OR GLM chat
  // ---------------------------------------------------------------------------

  Future<void> _processUtteranceWithTranscript(String transcript) async {
    _setState(RingPipelineState.thinking);
    _liveTranscriptController.add('Searching AI...');

    String chatReply = '';
    AgentRoute route = const AgentRoute(toolName: 'none', isNone: true);

    try {
      // ── Step 1: Route via AgentRouterService (fast local + Fireworks GLM) ──
      debugPrint('[RingPipeline] Routing: "$transcript"');
      route = await AgentRouterService.instance.route(transcript);
      debugPrint('[RingPipeline] Route: ${route.toolName} | args: ${route.arguments}');

      if (route.isNone) {
        // ── Conversational reply ─────────────────────────────────────────────
        final quickReply = route.reply;
        if (quickReply != null && quickReply.isNotEmpty) {
          chatReply = quickReply;
        } else {
          chatReply = await _fireworksChat(transcript);
        }
        if (chatReply.trim().isEmpty) {
          chatReply = 'How can I help you?';
        }
        debugPrint('[RingPipeline] Chat reply: "$chatReply"');
        _liveAiResponseController.add(chatReply);

      } else {
        // ── Execute agentic tool via ToolExecutorService ─────────────────────
        _liveTranscriptController.add('Doing: ${route.toolName}...');
        debugPrint('[RingPipeline] Executing tool: ${route.toolName}');

        final sb = StringBuffer();
        await for (final chunk in _executor.execute(
          transcript,
          detectedTool: route.toolName,
          preExtractedParam: route.param,
        )) {
          sb.write(chunk);
        }
        chatReply = sb.toString().trim();
        if (chatReply.isEmpty) chatReply = 'Done!';
        debugPrint('[RingPipeline] Tool result: "$chatReply"');
        _liveAiResponseController.add(chatReply);
      }

      final result = RingPipelineResult(
        transcript: transcript,
        route: route,
        chatReply: chatReply,
        timestamp: DateTime.now(),
      );
      _resultController.add(result);
      await _sendReplyToRing(result);

    } catch (e, st) {
      debugPrint('[RingPipeline] Fatal error: $e\\n$st');
      chatReply = 'Sorry, something went wrong.';
      _liveAiResponseController.add(chatReply);
    } finally {
      _processingUtterance = false;
      _setState(RingPipelineState.idle);
    }
  }'''

if OLD_PROCESS in content:
    content = content.replace(OLD_PROCESS, NEW_PROCESS, 1)
    print('[OK] Replaced _processUtteranceWithTranscript with agentic version')
else:
    print('[FAIL] Could not find old _processUtteranceWithTranscript block!')
    # Count matching lines for debug
    old_lines = OLD_PROCESS.split('\n')
    for i, l in enumerate(old_lines[:5]):
        found = l.strip() in content
        print(f'  Line {i} match={found}: {l[:80]}')
    sys.exit(1)

# ── 4. Also update processTextQuery to use agentic routing ───────────────────
OLD_TEXT_QUERY = '''  /// Process direct text query (typed in chat screen)
  Future<void> processTextQuery(String text) async {
    if (text.trim().isEmpty) return;
    _processingUtterance = true;
    _liveTranscriptController.add(text);
    _setState(RingPipelineState.thinking);
    try {
      final reply = await _fireworksChat(text);
      final result = RingPipelineResult(
        transcript: text,
        route: const AgentRoute(toolName: 'none', isNone: true),
        chatReply: reply.isNotEmpty ? reply : 'No response.',
        timestamp: DateTime.now(),
      );
      _resultController.add(result);
      _liveAiResponseController.add(result.chatReply!);
      await _sendReplyToRing(result);
    } finally {
      _processingUtterance = false;
      _setState(RingPipelineState.idle);
    }
  }'''

NEW_TEXT_QUERY = '''  /// Process direct text query (typed in chat screen) — also uses AgentRouter
  Future<void> processTextQuery(String text) async {
    if (text.trim().isEmpty) return;
    _processingUtterance = true;
    _liveTranscriptController.add(text);
    await _processUtteranceWithTranscript(text);
  }'''

if OLD_TEXT_QUERY in content:
    content = content.replace(OLD_TEXT_QUERY, NEW_TEXT_QUERY, 1)
    print('[OK] Updated processTextQuery to use agentic routing')
else:
    print('[WARN] processTextQuery block not found - leaving as is')

# ── 5. Write the fixed file ───────────────────────────────────────────────────
with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(content)

print()
print('=== Done! ring_audio_pipeline.dart updated ===')

# Quick sanity: count braces
opens = content.count('{')
closes = content.count('}')
print(f'Brace check: {{ = {opens}, }} = {closes}, match = {opens == closes}')
print(f'File size: {len(content)} bytes')
