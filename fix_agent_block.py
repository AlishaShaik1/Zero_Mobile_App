import sys

TARGET = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion\lib\services\ring_audio_pipeline.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the broken agent processing block and replace with a simple direct GLM call
# Find and replace the _processUtteranceWithTranscript method

OLD = '''  // === AI Processing (unchanged — agent → GLM → reply) ========================

  Future<void> _processUtteranceWithTranscript(String transcript) async {
    _setState(RingPipelineState.thinking);

    String chatReply   = '';
    bool agentSucceeded = false;

    try {
      // Try agent (tool-use) path
      try {
        final route = await AgentRouterService.instance.route(transcript);
        if (!route.isNone) {
          final executor  = ToolExecutorService.instance;
          final scratchpad = AgentScratchpadRunner(
            modelService: ModelService.instance,
            toolExecutor: executor,
          );
          await for (final event in scratchpad.execute(transcript)) {
            if (event is AgentThoughtEvent) {
              _liveAiResponseController.add('⚡ ${event.thought}');
            } else if (event is AgentActionEvent) {
              _liveAiResponseController.add('🔧 Running ${event.tool}…');
            } else if (event is AgentCompleteEvent) {
              chatReply = event.finalAnswer;
              agentSucceeded = chatReply.isNotEmpty &&
                  chatReply != 'Done.' &&
                  chatReply != 'Done'  &&
                  chatReply != 'Task completed.';
              if (agentSucceeded) _liveAiResponseController.add(chatReply);
            }
          }
        }
      } catch (agentErr) {
        debugPrint('[RingPipeline] Agent error: $agentErr');
      }

      // Fallback to direct GLM
      if (!agentSucceeded || chatReply.trim().isEmpty) {
        chatReply = await _fireworksChat(transcript);
        if (chatReply.isNotEmpty) {
          _liveAiResponseController.add(chatReply);
        }
      }

      if (chatReply.trim().isEmpty) {
        chatReply = 'Sorry, could not get a response. Please try again!';
      }

      debugPrint('[RingPipeline] Final reply: "$chatReply"');

      final result = RingPipelineResult(
        transcript: transcript,
        route: const AgentRoute(toolName: 'agent_react', isNone: false),
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

NEW = '''  // === AI Processing ============================================================

  Future<void> _processUtteranceWithTranscript(String transcript) async {
    _setState(RingPipelineState.thinking);

    String chatReply = '';

    try {
      // Direct GLM chat — fast and reliable
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

if OLD in content:
    content = content.replace(OLD, NEW, 1)
    print('Replaced agent processing block')
else:
    print('ERROR: block not found, doing line-by-line search...')
    # Try to find approximate location
    lines = content.splitlines()
    for i, l in enumerate(lines):
        if 'AI Processing' in l or 'AgentScratchpad' in l or 'ToolExecutorService' in l:
            print(f'  line {i+1}: {l[:80]}')

# Also remove unused imports
OLD2 = "import 'agent_scratchpad_runner.dart';\nimport 'model_service.dart';\n"
NEW2 = ""
if OLD2 in content:
    content = content.replace(OLD2, NEW2, 1)
    print('Removed unused imports')

OLD3 = "import 'tool_executor_service.dart';\n"
NEW3 = ""
if OLD3 in content:
    content = content.replace(OLD3, NEW3, 1)
    print('Removed tool_executor_service import')

with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(content)
print('File written successfully')
