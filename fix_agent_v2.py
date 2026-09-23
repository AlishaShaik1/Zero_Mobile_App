import sys

TARGET = r'C:\Users\Alisha\Downloads\zero ring companion\zero ring companion\lib\services\ring_audio_pipeline.dart'

with open(TARGET, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Replace lines 325-400 (the AI processing block) with simpler version
# Find the start of the AI Processing section
start_line = None
end_line = None

for i, l in enumerate(lines):
    if '// AI Processing' in l and start_line is None:
        start_line = i
    if start_line is not None and i > start_line + 5:
        # find end of _processUtteranceWithTranscript method (the closing })
        # it ends at the line with just '  }' after the finally block
        if l.strip() == '}' and 'finally' not in lines[i-1]:
            if i > start_line + 40:  # ensure we've gone past the method
                end_line = i
                break

print(f'AI Processing section: lines {start_line+1} to {end_line+1}')

# Replace with clean simple version
NEW_SECTION = '''  // ==========================================================================
  // AI Processing — direct GLM chat (no agent complexity)
  // ==========================================================================

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
  }

'''

new_lines = lines[:start_line] + [NEW_SECTION] + lines[end_line+1:]

# Also fix imports — remove unused ones
result = ''.join(new_lines)
for unused in [
    "import 'agent_scratchpad_runner.dart';\n",
    "import 'model_service.dart';\n",
    "import 'tool_executor_service.dart';\n",
]:
    if unused in result:
        result = result.replace(unused, '', 1)
        print(f'Removed: {unused.strip()}')

with open(TARGET, 'w', encoding='utf-8') as f:
    f.write(result)

print(f'Done. Written {len(result)} chars')
