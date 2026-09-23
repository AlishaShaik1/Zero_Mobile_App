import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/pipeline_service.dart';
import '../services/tool_executor_service.dart';
import '../services/agent_router_service.dart';
import '../theme/zero_theme.dart';
import '../widgets/status_orb.dart';
import 'splash_screen.dart';

// ─── Agent step log entry ────────────────────────────────────────────────────
class AgentStep {
  final String label;
  final String? result;
  final bool isRunning;
  final bool isError;
  AgentStep({
    required this.label,
    this.result,
    this.isRunning = false,
    this.isError = false,
  });
  AgentStep copyWith({String? result, bool? isRunning, bool? isError}) =>
      AgentStep(
        label: label,
        result: result ?? this.result,
        isRunning: isRunning ?? this.isRunning,
        isError: isError ?? this.isError,
      );
}

class AgentScreen extends StatefulWidget {
  final ModelService modelService;
  final SearchService searchService;
  final String? initialTask;
  const AgentScreen({
    super.key,
    required this.modelService,
    required this.searchService,
    this.initialTask,
  });

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  late final OrchestrationPipeline _pipeline;
  late final ToolExecutorService _executor;

  bool _isRunning = false;
  OrbState _orbState = OrbState.idle;
  final List<AgentStep> _steps = [];
  String _finalAnswer = '';

  @override
  void initState() {
    super.initState();
    _pipeline = OrchestrationPipeline(
      widget.modelService,
      widget.searchService,
    );
    _executor = ToolExecutorService(widget.modelService, widget.searchService);

    // Boot OS Kernel in the background
    AgentRouterService.instance.initialize();

    if (widget.initialTask != null && widget.initialTask!.isNotEmpty) {
      _ctrl.text = widget.initialTask!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runAgent(widget.initialTask!);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addStep(String label) {
    setState(() {
      if (_steps.isNotEmpty && _steps.last.isRunning) {
        _steps[_steps.length - 1] = _steps.last.copyWith(isRunning: false);
      }
      _steps.add(AgentStep(label: label, isRunning: true));
    });
    _scrollDown();
  }

  void _completeLastStep(String result, {bool isError = false}) {
    if (_steps.isEmpty || !mounted) return;
    setState(() {
      _steps[_steps.length - 1] = _steps.last.copyWith(
        result: result,
        isRunning: false,
        isError: isError,
      );
    });
  }

  Future<void> _runAgent(String input) async {
    if (input.trim().isEmpty) return;
    if (!widget.modelService.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model is still loading, please wait…')),
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _orbState = OrbState.thinking;
      _steps.clear();
      _finalAnswer = '';
    });
    _ctrl.clear();
    HapticFeedback.lightImpact();

    try {
      // ── Step 1: Needle 26M routes the request ─────────────────────────────
      // Wait for Needle to finish initializing (first-run download can take ~10s).
      // This fixes the race condition where initialize() isn't awaited in initState.
      _addStep('Routing with OS Kernel…');
      if (!AgentRouterService.instance.isReady) {
        _completeLastStep('Waiting for router to load…');
        _addStep('Loading OS Kernel router…');
        // Poll until ready or timeout (15 seconds)
        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (!AgentRouterService.instance.isReady &&
            DateTime.now().isBefore(deadline)) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
        }
        if (!AgentRouterService.instance.isReady) {
          _completeLastStep('Router unavailable');
        } else {
          _completeLastStep('Router ready');
          _addStep('Routing with OS Kernel…');
        }
      }
      final route = await AgentRouterService.instance.route(input);
      if (!mounted) return;

      debugPrint('[AgentScreen] $route');

      // ── Step 2: Dispatch based on Needle's structured output ───────────────
      if (route.isNone) {
        _completeLastStep('Agent Mode handles commands only.');
        setState(
          () => _finalAnswer =
              'No OS command detected for "$input".\nAgent Mode only executes system controls and actions. Switch to Chat Mode for conversational AI.',
        );
        return;
      }

      if (route.isMulti) {
        _completeLastStep('Multi-step task');
        setState(() => _orbState = OrbState.executing);
        _addStep('Executing pipeline…');
        final sb = StringBuffer();
        await for (final chunk in _pipeline.run(input)) {
          if (!mounted) return;
          sb.write(chunk);
          setState(() => _finalAnswer = sb.toString());
          _scrollDown();
        }
        _completeLastStep('Pipeline complete');
        return;
      }

      // ── Single tool — Needle already extracted the param cleanly ─────────
      _completeLastStep('Tool: ${route.toolName}');
      setState(() => _orbState = OrbState.executing);
      _addStep('Executing ${route.toolName}…');
      final sb = StringBuffer();
      await for (final chunk in _executor.execute(
        input,
        detectedTool: route.toolName,
        preExtractedParam: route.param,
      )) {
        if (!mounted) return;
        sb.write(chunk);
        setState(() => _finalAnswer = sb.toString());
        _scrollDown();
      }
      _completeLastStep('Done');
    } catch (e) {
      _completeLastStep('Error: $e', isError: true);
      setState(() => _finalAnswer = 'Error: $e');
    } finally {
      setState(() {
        _isRunning = false;
        _orbState = OrbState.idle;
      });
    }
  }

  Color _stepColor(AgentStep s) {
    if (s.isError) return Colors.red;
    if (s.isRunning) return ZeroTheme.accent;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZeroTheme.cream,
      appBar: AppBar(
        backgroundColor: ZeroTheme.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ZeroTheme.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            StatusOrb(state: _orbState, size: 10),
            const SizedBox(width: 8),
            Text(
              'AGENT MODE',
              style: ZeroTheme.mono.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        actions: [
          if (_isRunning)
            TextButton(
              onPressed: () {
                widget.modelService.cancelGeneration();
                setState(() {
                  _isRunning = false;
                  _orbState = OrbState.idle;
                });
              },
              child: const Text(
                'STOP',
                style: TextStyle(color: Colors.red, fontFamily: 'monospace'),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: ZeroTheme.ink, thickness: 2),
        ),
      ),
      body: Column(
        children: [
          // ── Step log ──────────────────────────────────────────────────────
          Expanded(
            child: _steps.isEmpty && _finalAnswer.isEmpty
                ? _buildEmptyState()
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._steps.map((s) => _buildStepTile(s)),
                      if (_finalAnswer.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: ZeroTheme.hardCard(
                            fill: ZeroTheme.white,
                            shadowColor: ZeroTheme.accent,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RESULT',
                                style: ZeroTheme.mono.copyWith(
                                  color: ZeroTheme.accent,
                                  fontSize: 10,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(_finalAnswer, style: ZeroTheme.body),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          // ── Input ─────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: ZeroTheme.white,
              border: Border(top: BorderSide(color: ZeroTheme.ink, width: 2)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: ZeroTheme.hardCard(
                      fill: ZeroTheme.white,
                      radius: 12,
                    ),
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: ZeroTheme.body,
                      decoration: const InputDecoration(
                        hintText: '> Enter task for Zero Agent…',
                        hintStyle: ZeroTheme.bodyMuted,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _runAgent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _isRunning ? null : _runAgent(_ctrl.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: ZeroTheme.hardCard(
                      fill: _isRunning
                          ? Colors.red.withValues(alpha: 0.1)
                          : ZeroTheme.accent,
                      shadowColor: ZeroTheme.ink,
                      radius: 12,
                    ),
                    child: _isRunning
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.red,
                            ),
                          )
                        : const Icon(Icons.arrow_upward, color: ZeroTheme.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(AgentStep s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: s.isRunning 
                  ? _stepColor(s).withValues(alpha: 0.2) 
                  : (s.isError ? Colors.red.withValues(alpha: 0.2) : ZeroTheme.ink.withValues(alpha: 0.1)),
              shape: BoxShape.circle,
              border: Border.all(color: _stepColor(s), width: 2),
            ),
            child: s.isRunning
                ? Padding(
                    padding: const EdgeInsets.all(4),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _stepColor(s),
                    ),
                  )
                : Icon(
                    s.isError ? Icons.close : Icons.check,
                    color: _stepColor(s),
                    size: 14,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  style: ZeroTheme.mono.copyWith(
                    color: _stepColor(s),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (s.result != null && s.result!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      s.result!,
                      style: ZeroTheme.mono.copyWith(
                        color: ZeroTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AIGenerationLoader(size: 64, spinning: true),
          const SizedBox(height: 24),
          Text(
            'ZERO AGENT',
            style: ZeroTheme.mono.copyWith(
              color: ZeroTheme.accent,
              fontSize: 18,
              letterSpacing: 6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Multi-step task execution', style: ZeroTheme.bodyMuted),
          const SizedBox(height: 32),
          _chip('Send WhatsApp to Priya then search weather'),
          const SizedBox(height: 8),
          _chip('Set brightness to 50% and open Spotify'),
          const SizedBox(height: 8),
          _chip('Search AI news and email it to me'),
          const SizedBox(height: 8),
          _chip('Zero cowork: find cheapest iPhone 16 on Amazon'),
          const SizedBox(height: 8),
          _chip('Cowork: book a table at a restaurant in Delhi'),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return GestureDetector(
      onTap: () {
        _ctrl.text = text;
        _runAgent(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: ZeroTheme.hardCard(fill: ZeroTheme.white, radius: 20),
        child: Text(text, style: ZeroTheme.mono.copyWith(fontSize: 11)),
      ),
    );
  }
}
