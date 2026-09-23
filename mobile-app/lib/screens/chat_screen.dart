import 'dart:async';

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../services/model_service.dart';
import '../services/search_service.dart';
import '../services/agent_router_service.dart';
import '../services/pipeline_service.dart';
import '../widgets/model_selector_sheet.dart';
import '../widgets/glass_container.dart';
// live_overlay_widget.dart — imported on-demand via Navigator.push
import '../widgets/status_orb.dart';
import '../widgets/mascot/zero_mascot.dart';
import '../widgets/tool_card.dart';

import '../theme/zero_theme.dart';
import 'computer_screen.dart';
import 'settings_screen.dart';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

import '../deep_search/deep_search_agent.dart';
import '../deep_search/deep_search_events.dart';
import '../voice_agent/services/model_manager.dart';
import '../voice_agent/services/audio_service.dart';
import 'live_voice_screen.dart';
import 'markdown_viewer_screen.dart';
import 'ring_companion_screen.dart';
import 'ring_camera_screen.dart';
import '../services/ring_ble_service.dart';
import '../services/ring_audio_pipeline.dart';
// ring_scan_sheet.dart — imported on-demand via showModalBottomSheet

class Message {
  final String text;
  final bool isUser;
  Message(this.text, this.isUser);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  bool get showExperimentalFace => true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  final ModelService _modelService = ModelService();
  final SearchService _searchService = SearchService();
  // Lazy — only created once Needle is ready, null if Needle not loaded yet
  OrchestrationPipeline? _pipeline;

  final List<Message> _messages = [];
  bool _isGenerating = false;
  String _userName = 'User';
  String _mode = 'chat'; // chat, computer, agent
  List<String> _recentChats = [];
  OrbState _orbState = OrbState.idle;
  bool _isIncognito = false;
  String? _pendingImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isModelReady = false;
  bool _hasModelError = false;
  String _modelStatus = 'loading';
  double _downloadProgress = 0.0;
  bool _thinkingEnabled = false;
  String _thinkingEffort = 'Low';
  bool _deepSearchEnabled = false;
  // ignore: unused_field
  String _lastUserMessage = ''; // for emotion blending — assigned in _sendMessage
  late AnimationController _pulseController;
  bool _isListening = false;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<String>? _commandSub;
  StreamSubscription? _bleSub;
  RingConnectionState _ringConnState = RingConnectionState.disconnected;

  // ── Ring hardware pipeline (double-click ring → shows here) ──────────────
  StreamSubscription? _ringTranscriptSub;
  StreamSubscription? _ringAiReplySub;
  StreamSubscription? _ringResultSub;
  StreamSubscription? _ringStateSub;
  // ignore: unused_field
  bool _ringIsActive = false; // true when ring is listening/processing

  // ── Live thinking panel ───────────────────────────────────────────────────
  String _liveThinkingText = '';    // raw thinking tokens, streamed live
  bool _thinkingPanelExpanded = true; // auto-collapses after generation

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadUserData();
    _loadRecents();
    _initModel();
    _loadThinkingPrefs();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveData);

    _ringConnState = RingBleService.instance.connectionState;
    _bleSub = RingBleService.instance.events.listen((event) {
      if (mounted) {
        setState(() {
          _ringConnState = RingBleService.instance.connectionState;
        });
      }
    });

    // Auto-connect to ring on app launch if disconnected
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && RingBleService.instance.connectionState == RingConnectionState.disconnected) {
        RingBleService.instance.connect();
      }
    });

    // ── Subscribe to ring hardware button pipeline ─────────────────────────
    // When user double-clicks ring button, entire interaction shows in chat
    _ringStateSub = RingAudioPipeline.instance.stateStream.listen((state) {
      if (!mounted) return;
      switch (state) {
        case RingPipelineState.listening:
          setState(() {
            _ringIsActive = true;
            _orbState = OrbState.listening;
            // Show live listening indicator as a pending AI message
            if (_messages.isEmpty || _messages.last.isUser) {
              _messages.add(Message('🎤 Ring listening…', false));
            } else {
              _messages[_messages.length - 1] = Message('🎤 Ring listening…', false);
            }
          });
          _scrollToBottom();
          break;
        case RingPipelineState.transcribing:
          setState(() {
            _orbState = OrbState.thinking;
            if (_messages.isNotEmpty && !_messages.last.isUser) {
              _messages[_messages.length - 1] = Message('💬 Transcribing…', false);
            }
          });
          break;
        case RingPipelineState.thinking:
          setState(() {
            _isGenerating = true;
            _orbState = OrbState.thinking;
            if (_messages.isNotEmpty && !_messages.last.isUser) {
              _messages[_messages.length - 1] = Message('⚡ Zero is thinking…', false);
            }
          });
          break;
        case RingPipelineState.replying:
          setState(() => _orbState = OrbState.thinking);
          break;
        case RingPipelineState.idle:
          setState(() {
            _ringIsActive = false;
            _isGenerating = false;
            _orbState = OrbState.idle;
            // Clean up any remaining placeholder message if still listening/transcribing
            if (_messages.isNotEmpty && !_messages.last.isUser) {
              if (_messages.last.text.contains('Ring listening') ||
                  _messages.last.text.contains('Transcribing') ||
                  _messages.last.text.isEmpty) {
                _messages.removeLast();
              }
            }
          });
          _pulseController.stop();
          _pulseController.reset();
          break;
      }
    });

    // Live partial transcript — update user message bubble as ring speaks
    _ringTranscriptSub = RingAudioPipeline.instance.liveTranscript.listen((text) {
      if (!mounted || text.isEmpty) return;
      setState(() {
        // Insert/update user bubble with live transcript
        if (_messages.isNotEmpty && !_messages.last.isUser) {
          // Insert user message just before AI placeholder
          _messages.insert(_messages.length - 1, Message(text, true));
        } else if (_messages.isEmpty || _messages.last.isUser) {
          _messages.add(Message(text, true));
        } else {
          // Update the last user message
          final lastUserIdx = _messages.lastIndexWhere((m) => m.isUser);
          if (lastUserIdx >= 0) {
            _messages[lastUserIdx] = Message(text, true);
          }
        }
      });
      _scrollToBottom();
    });

    // Live AI streaming reply — update AI bubble token by token
    _ringAiReplySub = RingAudioPipeline.instance.liveAiResponse.listen((text) {
      if (!mounted || text.isEmpty) return;
      _updateLastMessage(text);
    });

    // Final result — clean up and finalize the conversation
    _ringResultSub = RingAudioPipeline.instance.results.listen((result) {
      if (!mounted) return;
      final reply = result.chatReply ?? '';
      if (reply.isNotEmpty) _updateLastMessage(reply);
      // Save to recents
      if (result.transcript.isNotEmpty) {
        _saveToRecents(result.transcript);
      }
      _scrollToBottom();
    });
  }

  Future<void> _toggleMicListening() async {
    // Guard: if already listening, cancel and return to idle
    if (_isListening) {
      await _transcriptSub?.cancel();
      await _commandSub?.cancel();
      _transcriptSub = null;
      _commandSub = null;
      ZeroAudioService.instance.resetToKwsMode();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    // Request mic permission first — bails out silently if denied
    final status = await Permission.microphone.request();
    if (!mounted || status != PermissionStatus.granted) return;

    // If the audio isolate is not yet up, trigger init now and wait for it.
    if (!ZeroAudioService.instance.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Starting audio engine, please wait…'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      try {
        final kwsPath = await ModelManager.instance.ensureKeywordsFile();
        await ZeroAudioService.instance.initKeywordSpotter(kwsPath);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Audio init failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Listen to explicit Isolate errors (e.g watchdog timeout)
    StreamSubscription<String>? errorSub;
    errorSub = ZeroAudioService.instance.errorStream.listen((err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mic Error: $err'), backgroundColor: Colors.red),
      );
      _transcriptSub?.cancel();
      _commandSub?.cancel();
      errorSub?.cancel();
      ZeroAudioService.instance.resetToKwsMode();
      if (mounted) setState(() => _isListening = false);
    });

    _transcriptSub = ZeroAudioService.instance.transcriptStream.listen((text) {
      if (!mounted) return;
      setState(() {
        _textController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      });
    });

    _commandSub = ZeroAudioService.instance.commandStream.listen((text) {
      if (!mounted) return;
      // Ignore empty commands (silent ASR endpoint with no speech detected)
      if (text.trim().isEmpty) return;
      _transcriptSub?.cancel();
      _commandSub?.cancel();
      errorSub?.cancel();
      _transcriptSub = null;
      _commandSub = null;
      ZeroAudioService.instance.resetToKwsMode();
      if (mounted) setState(() => _isListening = false);
      // Auto-send: runs through Needle → device tool OR MiniCPM
      _textController.clear();
      _sendMessage(text.trim());
    });

    try {
      await ZeroAudioService.instance.startDirectListening();
      // Only set the button red AFTER the mic actually started
      if (mounted) setState(() => _isListening = true);
    } catch (e) {
      await _transcriptSub?.cancel();
      await _commandSub?.cancel();
      _transcriptSub = null;
      _commandSub = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mic error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onReceiveData(dynamic data) {
    if (!mounted || data is! String) return;
    try {
      final json = jsonDecode(data);
      if (json['type'] == 'transcript') {
        final text = json['text'] as String?;
        if (text != null && text.isNotEmpty) {
          setState(() {
            _textController.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadThinkingPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _thinkingEnabled = prefs.getBool('thinkmode_enabled') ?? false;
        _thinkingEffort = prefs.getString('thinkmode_effort') ?? 'Low';
      });
    }
  }

  Future<void> _saveThinkingPref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  Future<void> _initModel() async {
    // Fireworks GLM mode: zero local model download needed
    if (mounted) {
      setState(() {
        _isModelReady = true;
        _hasModelError = false;
        _modelStatus = 'ready';
        _downloadProgress = 0.0;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveData);
    _transcriptSub?.cancel();
    _commandSub?.cancel();
    _bleSub?.cancel();
    _ringTranscriptSub?.cancel();
    _ringAiReplySub?.cancel();
    _ringResultSub?.cancel();
    _ringStateSub?.cancel();
    ZeroAudioService.instance.resetToKwsMode();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
    });
  }

  Future<void> _loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentChats = prefs.getStringList('recent_chats') ?? [];
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveToRecents(String text) async {
    if (_isIncognito) return; // Don't save in incognito mode
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('recent_chats') ?? [];
    final title = text.length > 40 ? '${text.substring(0, 40)}...' : text;
    existing.remove(title);
    existing.insert(0, title);
    if (existing.length > 20) existing.removeLast();
    await prefs.setStringList('recent_chats', existing);
    if (mounted) setState(() => _recentChats = existing);
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
      );
      if (picked == null) return;
      setState(() => _pendingImagePath = picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
      }
    }
  }

  Future<void> _sendMessageWithPendingImage(String text) async {
    final imagePath = _pendingImagePath;
    setState(() => _pendingImagePath = null);
    if (imagePath != null) {
      // Route to vision pipeline
      if (text.trim().isEmpty) return;
      if (!_isModelReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Model is loading, please wait...')),
        );
        return;
      }
      setState(() {
        _messages.add(Message('[Image attached] $text', true));
        _messages.add(Message('', false));
        _isGenerating = true;
        _orbState = OrbState.thinking;
      });
      _pulseController.repeat(reverse: true);
      _textController.clear();
      _scrollToBottom();
      _saveToRecents(text);
      try {
        String response = '';
        await for (final delta in _modelService.chatWithImage(
          text,
          imagePath,
        )) {
          if (delta is ContentDelta) {
            response += delta.text;
            _updateLastMessage(response);
          } else if (delta is ThinkingDelta) {
            if (_thinkingEnabled) {
              response += '> ${delta.text.replaceAll('\n', '\n> ')}';
              _updateLastMessage(response);
            } else if (response.isEmpty) {
              response += '[Analyzing image...]\n';
            }
          }
        }
      } catch (e) {
        _updateLastMessage('Error: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isGenerating = false;
            _orbState = OrbState.idle;
          });
        }
        _pulseController.stop();
        _pulseController.reset();
        _scrollToBottom();
      }
    } else {
      _sendMessage(text);
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    if (!_isModelReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hasModelError
                  ? 'Model failed to load. Tap to retry.'
                  : 'Model is loading, please wait...',
            ),
            action: _hasModelError
                ? SnackBarAction(label: 'Retry', onPressed: _initModel)
                : null,
          ),
        );
      }
      return;
    }

    _lastUserMessage = text; // for emotion blending
    setState(() {
      _messages.add(Message(text, true));
      _messages.add(Message("", false));
      _isGenerating = true;
      _orbState = _deepSearchEnabled ? OrbState.searching : OrbState.thinking;
    });

    _pulseController.repeat(reverse: true);
    _textController.clear();
    _scrollToBottom();
    _saveToRecents(text);

    try {
      if (_deepSearchEnabled) {
        // --- DEEP SEARCH FLOW ---
        final deepAgent = DeepSearchAgent(_modelService, _searchService);
        String response = '';
        List<String> stepSources = [];
        String stepQuery = '';
        await for (final event in deepAgent.execute(text)) {
          if (event is SearchPlanningEvent) {
            response = '🔍 Planning research for "${event.query}"...\n';
          } else if (event is SearchPlanReadyEvent) {
            response += 'Research plan (${event.steps.length} steps):\n';
            for (int i = 0; i < event.steps.length; i++) {
              response += '${i + 1}. ${event.steps[i]}\n';
            }
            response += '\n';
          } else if (event is StepStartedEvent) {
            stepSources = [];
            stepQuery = event.query;
            response +=
                '\n<search-step-header>${event.index}|${event.total}|${event.query}</search-step-header>\n';
            _updateLastMessage(response);
          } else if (event is StepSourcesFoundEvent) {
            stepSources = event.sources;
          } else if (event is StepSuccessEvent) {
            final payload = jsonEncode({
              'url': event.url ?? '',
              'title': event.title ?? stepQuery,
              'summary': event.summary,
              'query': stepQuery,
              'sources': stepSources,
            });
            final encoded = base64Encode(utf8.encode(payload));
            response += '<deep-search-card>$encoded</deep-search-card>\n\n';
            _updateLastMessage(response);
          } else if (event is StepFailedEvent) {
            response += '> **Error:** ${event.error}\n';
            _updateLastMessage(response);
          } else if (event is FinalizingReportEvent) {
            response += '\n> Synthesizing combined research... ';
            _updateLastMessage(response);
          } else if (event is SearchCompleteEvent) {
            response += '\n\n[DEEP_SEARCH_FILE:${event.filePath}]';
          } else if (event is SearchErrorEvent) {
            response += '\nError: ${event.error}';
          }
          _updateLastMessage(response);
        }
      } else {
        // ── STANDARD AI FLOW: OS Kernel routes first, MiniCPM only for conversation ──
        // Get or lazily create the pipeline (safe: called once ModelService is ready)
        _pipeline ??= OrchestrationPipeline(_modelService, _searchService);
        final pipeline = _pipeline!;

        // 1. OS Kernel routing (~50-200ms)
        setState(() => _orbState = OrbState.thinking);
        AgentRoute agentRoute;
        try {
          agentRoute = await AgentRouterService.instance.route(text);
        } catch (_) {
          agentRoute = const AgentRoute(toolName: '', isNone: true);
        }

        if (!agentRoute.isNone && agentRoute.toolName != 'multi') {
          // 2a. Device / action tool → OrchestrationPipeline (bypasses MiniCPM routing phase)
          setState(() => _orbState = OrbState.executing);
          String response = '';
          await for (final chunk in pipeline.run(
            text,
            presetTools: [agentRoute.toolName],
            presetParam: agentRoute.param,
            injectedArgs: agentRoute.arguments.isNotEmpty
                ? agentRoute.arguments
                : null,
          )) {
            response += chunk;
            _updateLastMessage(response);
          }
        } else if (agentRoute.toolName == 'multi') {
          // 2b. Multi-tool: OrchestrationPipeline plans itself
          setState(() => _orbState = OrbState.executing);
          String response = '';
          await for (final chunk in pipeline.run(text)) {
            response += chunk;
            _updateLastMessage(response);
          }
        } else {
          // 2c. Conversational — use the reply pre-generated by the router JSON in
          // the same model call, avoiding a re-entrant lock on ModelService.
          setState(() => _orbState = OrbState.thinking);
          final preReply = agentRoute.reply;
          if (preReply != null && preReply.isNotEmpty) {
            // Router already generated a conversational reply — use it directly
            _updateLastMessage(preReply);
          } else {
            // Fallback: fire a separate chat() call (e.g. complex/long queries)
            // Thinking tokens → live panel. Content tokens → message bubble.
            // They are NEVER mixed so content appears as fast as possible.
            String response = '';
            // Reset thinking panel for this new generation
            if (mounted) setState(() { _liveThinkingText = ''; _thinkingPanelExpanded = true; });
            await for (final delta in _modelService.chat(text)) {
              if (delta is ContentDelta) {
                response += delta.text;
                _updateLastMessage(response);
              } else if (delta is ThinkingDelta) {
                // Stream to live panel — never pollute the response text
                if (mounted) setState(() => _liveThinkingText += delta.text);
              }
            }
            // Auto-collapse thinking panel once generation is done
            if (mounted) setState(() => _thinkingPanelExpanded = false);
          }
        }
      }
    } catch (e) {
      _updateLastMessage("Error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _orbState = OrbState.idle;
        });
      }
      _pulseController.stop();
      _pulseController.reset();
      _scrollToBottom();
    }
  }

  void _updateLastMessage(String text) {
    if (!mounted) return;
    setState(() {
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages[_messages.length - 1] = Message(text, false);
      } else {
        _messages.add(Message(text, false));
      }
    });
    _scrollToBottom();
  }

  void _stopGeneration() {
    _modelService.cancelGeneration();
    if (mounted) {
      setState(() {
        _isGenerating = false;
        _orbState = OrbState.idle;
      });
    }
    _pulseController.stop();
    _pulseController.reset();
  }

  String _getStatusText() {
    switch (_orbState) {
      case OrbState.searching:
        return 'Zero is searching the web...';
      case OrbState.executing:
        return 'Zero is executing tools...';
      case OrbState.listening:
        return 'Zero is listening...';
      case OrbState.thinking:
      default:
        return 'Zero is thinking...';
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, // Avoid material 3 purple tint
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Branding & New Chat ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'ZERO',
                    style: TextStyle(
                      color: ZeroTheme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() => _messages.clear());
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: ZeroTheme.ink.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ZeroTheme.ink.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: ZeroTheme.ink.withValues(alpha: 0.8),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New chat',
                        style: TextStyle(
                          color: ZeroTheme.ink.withValues(alpha: 0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Zero Ring Companion Hub & Radar Scanner ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RingCompanionScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF38BDF8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        ),
                        child: const Icon(
                          Icons.trip_origin,
                          color: Color(0xFF38BDF8),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Zero Ring Hub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              _ringConnState == RingConnectionState.connected
                                  ? 'Connected — Ready'
                                  : 'Scan & Connect Ring',
                              style: TextStyle(
                                color: _ringConnState == RingConnectionState.connected
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFF94A3B8),
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white54,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Zero Ring Dedicated Camera & Lens ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RingCameraScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: ZeroTheme.ink.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ZeroTheme.ink.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Color(0xFF0284C7),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zero Camera & Lens',
                              style: TextStyle(
                                color: ZeroTheme.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              'Single-click photo & save to phone',
                              style: TextStyle(
                                color: ZeroTheme.muted,
                                fontSize: 11,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: ZeroTheme.muted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Recents List ────────────────────────────────────────────────
            if (_recentChats.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'RECENTS',
                  style: TextStyle(
                    color: ZeroTheme.ink.withValues(alpha: 0.3),
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _recentChats.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      leading: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: ZeroTheme.ink.withValues(alpha: 0.4),
                        size: 18,
                      ),
                      title: Text(
                        _recentChats[index],
                        style: TextStyle(
                          color: ZeroTheme.ink.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(child: SizedBox()),

            // ── System & Tools ──────────────────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: ZeroTheme.ink.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 8),

            _buildDrawerItem(
              icon: Icons.mic_none_rounded,
              title: 'Always-On "Hey Zero"',
              subtitle: 'Keeps mic open when screen is off',
              trailing: Switch(
                value: false, // UI placeholder
                activeTrackColor: ZeroTheme.accent,
                onChanged: (val) async {
                  if (val) {
                    FlutterForegroundTask.init(
                      androidNotificationOptions: AndroidNotificationOptions(
                        channelId: 'zero_assistant',
                        channelName: 'Zero Assistant',
                        channelDescription: 'Listening for Hey Zero...',
                        channelImportance: NotificationChannelImportance.MIN,
                        priority: NotificationPriority.MIN,
                      ),
                      iosNotificationOptions: const IOSNotificationOptions(),
                      foregroundTaskOptions: ForegroundTaskOptions(
                        eventAction: ForegroundTaskEventAction.nothing(),
                        allowWakeLock: true,
                        allowWifiLock: true,
                      ),
                    );
                    bool reqResult =
                        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
                    if (reqResult) {
                      await FlutterForegroundTask.startService(
                        notificationTitle: 'Zero Air is Listening',
                        notificationText: 'Say "Hey Zero" to wake up',
                      );
                    }
                  } else {
                    await FlutterForegroundTask.stopService();
                  }
                  setState(() {});
                },
              ),
            ),

            _buildDrawerItem(
              icon: Icons.settings_rounded,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),

            const SizedBox(height: 8),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: ZeroTheme.ink.withValues(alpha: 0.06),
            ),

            // ── User Profile ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: ZeroTheme.accent.withValues(alpha: 0.15),
                    radius: 18,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: ZeroTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _userName,
                      style: const TextStyle(
                        color: ZeroTheme.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  // Just a subtle privacy indicator, no duplicate settings button
                  Icon(
                    Icons.shield_rounded,
                    color: ZeroTheme.ink.withValues(alpha: 0.2),
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      leading: Icon(
        icon,
        color: ZeroTheme.ink.withValues(alpha: 0.6),
        size: 22,
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: ZeroTheme.ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: ZeroTheme.ink.withValues(alpha: 0.4),
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AIGenerationLoader(size: 48, spinning: true),
            const SizedBox(height: 24),
            Text('${_getGreeting()}, $_userName', style: ZeroTheme.display),
            const SizedBox(height: 48),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildModeButton('Chat', Icons.chat_bubble_outline, 'chat'),
                _buildModeButton('Computer', Icons.computer, 'computer'),
                _buildModeButton('Zero Ring', Icons.trip_origin, 'ring'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(String title, IconData icon, String mode) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        if (mode == 'computer') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComputerScreen(
                modelService: _modelService,
                searchService: _searchService,
              ),
            ),
          );
          return;
        } else if (mode == 'ring') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RingCompanionScreen()),
          );
          return;
        }
        setState(() => _mode = mode);
        _focusNode.requestFocus();
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: isSelected
            ? ZeroTheme.accentCard(fill: ZeroTheme.white, radius: 14)
            : ZeroTheme.hardCard(fill: ZeroTheme.white, radius: 14),
        child: Column(
          children: [
            Icon(icon, color: ZeroTheme.ink, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: ZeroTheme.body.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 140,
        top: kToolbarHeight + 40,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLast = index == _messages.length - 1;
        return _buildMessageBubble(
          message,
          isLast && _isGenerating && !message.isUser,
        );
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isCurrentlyGenerating) {
    if (message.isUser) {
      // ── User bubble: right-aligned pill ─────────────────────────────────
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 64),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ZeroTheme.accent,
                ZeroTheme.accent.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: ZeroTheme.accent.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Text(
            message.text,
            style: ZeroTheme.body.copyWith(color: Colors.white),
          ),
        ),
      );
    } else {
      // ── AI bubble: left-aligned ────────────────
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16, right: 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? ZeroTheme.ink
                        : ZeroTheme.white,
                    border: Border.all(color: ZeroTheme.ink, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: ZeroTheme.ink.withValues(alpha: 1.0),
                        offset: const Offset(3, 3),
                      ),
                    ],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCurrentlyGenerating && message.text.isEmpty && _liveThinkingText.isEmpty)
                        _ThinkingRow(statusText: _getStatusText())
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Live Thinking Panel ──────────────────────
                            if (_liveThinkingText.isNotEmpty) ...[  
                              _LiveThinkingPanel(
                                thinkingText: _liveThinkingText,
                                isGenerating: isCurrentlyGenerating,
                                expanded: _thinkingPanelExpanded,
                                onToggle: () => setState(() =>
                                    _thinkingPanelExpanded = !_thinkingPanelExpanded),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // ── Status row (compact, while still streaming) ──
                            if (isCurrentlyGenerating && message.text.isEmpty)
                              _ThinkingRow(statusText: _getStatusText(), compact: _liveThinkingText.isNotEmpty)
                            else if (message.text.isNotEmpty)
                              _buildParsedText(message.text),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildParsedText(String text) {
    final List<Widget> widgets = [];

    // No global text replacements so we can maintain all tokens and parse them individually
    String currentText = text;

    while (currentText.isNotEmpty) {
      final fileMatch = RegExp(
        r'\[DEEP_SEARCH_FILE:([^\]]+)\]',
      ).firstMatch(currentText);

      final cardMatch = RegExp(
        r'<deep-search-card>(.*?)</deep-search-card>',
        dotAll: true,
      ).firstMatch(currentText);

      final stepMatch = RegExp(
        r'<search-step-header>(\d+)\|(\d+)\|(.*?)</search-step-header>',
        dotAll: true,
      ).firstMatch(currentText);

      final executingMatch = RegExp(
        r'// Executing: (.*?)(?=\n|$)',
      ).firstMatch(currentText);

      Match? earliestMatch;
      int type = 0; // 0=none, 1=file, 2=card, 3=step, 4=executing

      for (var match in [
        {'m': fileMatch, 't': 1},
        {'m': cardMatch, 't': 2},
        {'m': stepMatch, 't': 3},
        {'m': executingMatch, 't': 4},
      ]) {
        final m = match['m'] as Match?;
        final t = match['t'] as int;
        if (m != null) {
          if (earliestMatch == null || m.start < earliestMatch.start) {
            earliestMatch = m;
            type = t;
          }
        }
      }

      if (earliestMatch == null) {
        if (currentText.trim().isNotEmpty) {
          widgets.add(
            Text(
              currentText.trim(),
              style: ZeroTheme.body.copyWith(height: 1.5),
            ),
          );
        }
        break;
      }

      final before = currentText.substring(0, earliestMatch.start).trim();
      if (before.isNotEmpty) {
        widgets.add(Text(before, style: ZeroTheme.body.copyWith(height: 1.5)));
        widgets.add(const SizedBox(height: 12));
      }

      if (type == 1) {
        final path = earliestMatch.group(1)!;
        widgets.add(_buildFileCard(path));
      } else if (type == 2) {
        final payload = earliestMatch.group(1)!;
        try {
          final decodedPayload = utf8.decode(base64Decode(payload));
          final data = jsonDecode(decodedPayload) as Map<String, dynamic>;
          final url = data['url']?.toString();
          final title = data['title']?.toString();

          final List<Map<String, dynamic>> sourcesList = [];
          if (url != null && url.isNotEmpty) {
            sourcesList.add({'url': url, 'title': title});
          }
          final rawSources = data['sources'];
          if (rawSources is List) {
            for (final s in rawSources) {
              if (s != url && s.toString().isNotEmpty) {
                sourcesList.add({
                  'url': s.toString(),
                  'title': 'Secondary Source',
                });
              }
            }
          }

          if (sourcesList.isNotEmpty) {
            widgets.add(_buildSourcesClusterWidget(sourcesList));
          }

          final summary = data['summary']?.toString();
          if (summary != null && summary.isNotEmpty) {
            widgets.add(
              Text(summary, style: ZeroTheme.body.copyWith(height: 1.5)),
            );
          }
        } catch (_) {}
      } else if (type == 3) {
        final currentStep = earliestMatch.group(1)!;
        final totalSteps = earliestMatch.group(2)!;
        final query = earliestMatch.group(3)!;

        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ZeroTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ZeroTheme.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ZeroTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Step $currentStep of $totalSteps: $query...',
                    style: ZeroTheme.body.copyWith(
                      color: ZeroTheme.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (type == 4) {
        final tools = earliestMatch.group(1)!;
        widgets.add(
          ToolCard(
            title: 'Executing Action',
            subtitle: tools,
            icon: Icons.build_circle_outlined,
            isActive: true,
          ),
        );
      }

      widgets.add(const SizedBox(height: 12));
      currentText = currentText.substring(earliestMatch.end);
    }

    if (widgets.isEmpty) return const SizedBox.shrink();
    if (widgets.length == 1) return widgets.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSourcesClusterWidget(List<Map<String, dynamic>> sources) {
    if (sources.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 90,
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sources.length,
        clipBehavior: Clip.none,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final source = sources[index];
          final url = source['url']?.toString() ?? '';
          final title = source['title']?.toString() ?? 'Source';

          final domain =
              Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url;
          final faviconUrl =
              'https://www.google.com/s2/favicons?domain=$domain&sz=64';

          return Container(
            width: 156,
            padding: const EdgeInsets.all(12),
            decoration: ZeroTheme.hardCard(fill: ZeroTheme.white, radius: 12)
                .copyWith(
                  boxShadow: const [
                    BoxShadow(color: ZeroTheme.ink, offset: Offset(2, 2)),
                  ],
                ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        faviconUrl,
                        width: 16,
                        height: 16,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.public,
                          size: 16,
                          color: ZeroTheme.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        domain,
                        style: ZeroTheme.mono.copyWith(
                          fontSize: 10,
                          color: ZeroTheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: ZeroTheme.heading.copyWith(fontSize: 12, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFileCard(String path) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarkdownViewerScreen(filePath: path),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: ZeroTheme.hardCard(fill: ZeroTheme.white, radius: 8),
        child: Row(
          children: [
            const Icon(Icons.description, color: ZeroTheme.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deep Search Report',
                    style: ZeroTheme.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    path.split('/').last,
                    style: ZeroTheme.mono.copyWith(
                      fontSize: 10,
                      color: ZeroTheme.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: ZeroTheme.muted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _effortButton(String label) {
    final selected = _thinkingEffort == label;
    return GestureDetector(
      onTap: () async {
        setState(() => _thinkingEffort = label);
        await _saveThinkingPref('thinkmode_effort', label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? ZeroTheme.accent : ZeroTheme.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? ZeroTheme.accent : ZeroTheme.ink,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: ZeroTheme.mono.copyWith(
            fontSize: 11,
            color: selected ? ZeroTheme.white : ZeroTheme.muted,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Thinking toggle row ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () async {
                  final next = !_thinkingEnabled;
                  setState(() => _thinkingEnabled = next);
                  await _saveThinkingPref('thinkmode_enabled', next);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _thinkingEnabled ? ZeroTheme.ink : ZeroTheme.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZeroTheme.ink, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        size: 13,
                        color: _thinkingEnabled
                            ? ZeroTheme.white
                            : ZeroTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Think',
                        style: ZeroTheme.mono.copyWith(
                          fontSize: 11,
                          color: _thinkingEnabled
                              ? ZeroTheme.white
                              : ZeroTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_thinkingEnabled) ...[
                const SizedBox(width: 6),
                _effortButton('Low'),
                const SizedBox(width: 4),
                _effortButton('Max'),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() => _deepSearchEnabled = !_deepSearchEnabled);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _deepSearchEnabled ? ZeroTheme.ink : ZeroTheme.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZeroTheme.ink, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.travel_explore,
                        size: 13,
                        color: _deepSearchEnabled
                            ? ZeroTheme.white
                            : ZeroTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Deep Search',
                        style: ZeroTheme.mono.copyWith(
                          fontSize: 11,
                          color: _deepSearchEnabled
                              ? ZeroTheme.white
                              : ZeroTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Model selector pill ───────────────────────────────────────────────
        GestureDetector(
          onTap: () => ModelSelectorSheet.show(context),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ZeroTheme.borderLight, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isModelReady)
                  Text(
                    _downloadProgress > 0
                        ? 'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%'
                        : _modelStatus,
                    style: ZeroTheme.mono.copyWith(color: ZeroTheme.muted),
                  )
                else ...[
                  const Text('Titan-Small', style: ZeroTheme.mono),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: ZeroTheme.ink,
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return GlassContainer(
              margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              borderRadius: BorderRadius.circular(30),
              color: Colors.white,
              opacity: Theme.of(context).brightness == Brightness.dark
                  ? 0.9
                  : 1.0,
              border: Border.all(color: ZeroTheme.ink, width: 2.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: ZeroTheme.muted),
                    onPressed: _pickAndSendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: ZeroTheme.body,
                      decoration: const InputDecoration(
                        hintText: 'Message Zero...',
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: _sendMessageWithPendingImage,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : ZeroTheme.accent,
                    ),
                    onPressed: _toggleMicListening,
                  ),
                  IconButton(
                    icon: const Icon(Icons.trip_origin, color: ZeroTheme.accent),
                    tooltip: 'Zero Ring Hub',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RingCompanionScreen(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.graphic_eq, color: ZeroTheme.accent),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LiveVoiceScreen(),
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (_isGenerating) {
                          _stopGeneration();
                        } else {
                          _sendMessageWithPendingImage(_textController.text);
                        }
                      },
                      child: Container(
                        width:
                            36, // Slightly larger touch target for premium feel
                        height: 36,
                        decoration: BoxDecoration(
                          color: _isGenerating ? Colors.red : ZeroTheme.ink,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_isGenerating ? Colors.red : ZeroTheme.ink)
                                      .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isGenerating
                            ? Center(
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                ],
              ), // closes Row
            ); // closes return Container
          }, // closes builder
        ), // closes AnimatedBuilder
      ], // closes Column children
    ); // closes return Column
  }

  Widget _buildRingConnectionStatusChip() {
    final isConnected = _ringConnState == RingConnectionState.connected;
    final isScanning = _ringConnState == RingConnectionState.scanning ||
        _ringConnState == RingConnectionState.connecting;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RingCompanionScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isConnected ? const Color(0xFFE6F4EA) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConnected ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isConnected ? const Color(0xFF10B981) : const Color(0xFF38BDF8))
                  .withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.trip_origin,
              size: 14,
              color: isConnected ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
            ),
            const SizedBox(width: 5),
            Text(
              isConnected ? 'Ring' : (isScanning ? 'Scanning...' : 'Connect Ring'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isConnected ? const Color(0xFF065F46) : const Color(0xFF38BDF8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: ZeroTheme.cream.withValues(alpha: 0.85),
                border: const Border(
                  bottom: BorderSide(color: ZeroTheme.ink, width: 2.0),
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu, color: ZeroTheme.ink),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                title: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ModelSelectorSheet.show(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ZeroTheme.borderLight, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AIGenerationLoader(
                          size: 16,
                          spinning:
                              _orbState == OrbState.thinking ||
                              _orbState == OrbState.executing,
                        ),
                        const SizedBox(width: 6),
                        const Text('Titan-Small', style: ZeroTheme.mono),
                      ],
                    ),
                  ),
                ),
                actions: [
                  _buildRingConnectionStatusChip(),
                  IconButton(
                    icon: Icon(
                      Icons.no_photography_outlined,
                      color: _isIncognito ? ZeroTheme.accent : ZeroTheme.muted,
                    ),
                    tooltip: _isIncognito
                        ? 'Incognito ON — chats not saved'
                        : 'Tap to go incognito',
                    onPressed: () {
                      setState(() => _isIncognito = !_isIncognito);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isIncognito
                                ? 'Incognito ON — this chat will not be saved'
                                : 'Incognito OFF — chats will be saved',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isIncognito)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: kToolbarHeight,
                    bottom: 6,
                  ),
                  color: ZeroTheme.accent.withValues(alpha: 0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.no_photography_outlined,
                        size: 14,
                        color: ZeroTheme.accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Incognito — this chat is not being saved',
                        style: ZeroTheme.mono.copyWith(
                          color: ZeroTheme.accent,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessageList(),
              ),
            ],
          ),
          // Floating Pill Input
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    ZeroTheme.cream,
                    ZeroTheme.cream.withValues(alpha: 0.8),
                    ZeroTheme.cream.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
              padding: const EdgeInsets.only(top: 24),
              child: _buildInputBar(),
            ),
          ),
          // ── Model loading overlay ──────────────────────────────────────
          if (!_isModelReady)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.96),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AIGenerationLoader(size: 80, spinning: true),
                        const SizedBox(height: 32),
                        Text(
                          _hasModelError
                              ? 'Load Failed'
                              : _downloadProgress > 0
                              ? 'Downloading...'
                              : _modelStatus == 'loading'
                              ? 'Loading model...'
                              : 'Setting up Zero...',
                          style: ZeroTheme.heading,
                        ),
                        const SizedBox(height: 16),
                        if (_downloadProgress > 0 && !_hasModelError) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _downloadProgress,
                              backgroundColor: ZeroTheme.cream,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                ZeroTheme.accent,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                            style: ZeroTheme.mono.copyWith(
                              color: ZeroTheme.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ] else if (_hasModelError) ...[
                          Text(
                            _modelStatus,
                            style: ZeroTheme.bodyMuted.copyWith(
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _hasModelError = false;
                                _modelStatus = 'Retrying...';
                              });
                              _initModel();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              decoration: ZeroTheme.hardCard(
                                fill: ZeroTheme.ink,
                                shadowColor: ZeroTheme.accent,
                                radius: 12,
                              ),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ] else
                          Text(
                            _modelStatus,
                            style: ZeroTheme.bodyMuted,
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'by Zero Tech',
                          style: ZeroTheme.mono.copyWith(
                            color: ZeroTheme.muted,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Live Thinking Panel ────────────────────────────────────────────────────────
// Shows raw model reasoning tokens in real-time.
// Collapsible, auto-scrolls, auto-collapses when generation ends.
class _LiveThinkingPanel extends StatefulWidget {
  final String thinkingText;
  final bool isGenerating;
  final bool expanded;
  final VoidCallback onToggle;

  const _LiveThinkingPanel({
    required this.thinkingText,
    required this.isGenerating,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<_LiveThinkingPanel> createState() => _LiveThinkingPanelState();
}

class _LiveThinkingPanelState extends State<_LiveThinkingPanel> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(_LiveThinkingPanel old) {
    super.didUpdateWidget(old);
    // Auto-scroll to bottom as new tokens arrive
    if (widget.expanded && widget.thinkingText != old.thinkingText) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenCount = widget.thinkingText.split(' ').where((w) => w.isNotEmpty).length;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.isGenerating
              ? const Color(0xFF7C3AED).withValues(alpha: 0.7)
              : const Color(0xFF374151),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — tap to expand/collapse
          GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(9),
                  bottom: widget.expanded ? Radius.zero : const Radius.circular(9),
                ),
              ),
              child: Row(
                children: [
                  // Pulsing brain icon while generating
                  widget.isGenerating
                      ? const _PulsingIcon(
                          icon: Icons.psychology_rounded,
                          color: Color(0xFF7C3AED),
                          size: 15,
                        )
                      : const Icon(Icons.psychology_rounded,
                          color: Color(0xFF6B7280), size: 15),
                  const SizedBox(width: 6),
                  Text(
                    widget.isGenerating
                        ? 'Thinking... ($tokenCount tokens)'
                        : 'Thought ($tokenCount tokens)',
                    style: TextStyle(
                      color: widget.isGenerating
                          ? const Color(0xFFA78BFA)
                          : const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    widget.expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF6B7280),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          // Scrollable thinking text
          if (widget.expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    widget.thinkingText,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11.5,
                      height: 1.55,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _PulsingIcon({required this.icon, required this.color, required this.size});
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Opacity(
        opacity: 0.4 + 0.6 * _ctrl.value,
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      ),
    );
  }
}

class _ThinkingRow extends StatefulWidget {
  final String statusText;
  final bool compact;
  const _ThinkingRow({required this.statusText, this.compact = false});

  @override
  State<_ThinkingRow> createState() => _ThinkingRowState();
}

class _ThinkingRowState extends State<_ThinkingRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      // Inline compact: just mascot + pulsing text
      return AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.statusText,
              style: ZeroTheme.mono.copyWith(
                fontSize: 11,
                color: ZeroTheme.muted,
              ),
            ),
          ],
        ),
      );
    }
    // Full thinking state: status text + dots
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.statusText,
                  style: ZeroTheme.mono.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ZeroTheme.accent.withValues(
                          alpha: 0.3 + 0.7 * _ctrl.value,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: ZeroTheme.accent.withValues(
                              alpha: 0.2 * _ctrl.value,
                            ),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DeepSearchResultCard — Gemini-style search result card with Zero Air theme
// Shows: query header → favicon + domain source rows (collapsible) → summary
// ─────────────────────────────────────────────────────────────────────────────
class _DeepSearchResultCard extends StatefulWidget {
  final String query;
  final String topUrl;
  final String title;
  final String summary;
  final List<String> sources;

  const _DeepSearchResultCard({
    required this.query,
    required this.topUrl,
    required this.title,
    required this.summary,
    required this.sources,
  });

  @override
  State<_DeepSearchResultCard> createState() => _DeepSearchResultCardState();
}

class _DeepSearchResultCardState extends State<_DeepSearchResultCard>
    with SingleTickerProviderStateMixin {
  bool _sourcesExpanded = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggleSources() {
    setState(() => _sourcesExpanded = !_sourcesExpanded);
    if (_sourcesExpanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allSources = widget.sources.isEmpty && widget.topUrl.isNotEmpty
        ? [widget.topUrl]
        : widget.sources;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ZeroTheme.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ZeroTheme.ink.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: globe icon + query + result count ────────────────────
          InkWell(
            onTap: allSources.isNotEmpty ? _toggleSources : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: ZeroTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.travel_explore,
                      size: 16,
                      color: ZeroTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.query,
                      style: ZeroTheme.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (allSources.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ZeroTheme.ink.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${allSources.length} results',
                        style: ZeroTheme.mono.copyWith(
                          fontSize: 10,
                          color: ZeroTheme.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _sourcesExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: ZeroTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expandable Sources List ────────────────────────────────────
          if (allSources.isNotEmpty)
            SizeTransition(
              sizeFactor: _expandAnim,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Divider(
                    color: Color(0x1A0D0D0D),
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                  ),
                  ...allSources.take(8).map((url) => _SourceRow(url: url)),
                ],
              ),
            ),

          // ── Summary ──────────────────────────────────────────────────
          if (widget.summary.isNotEmpty) ...[
            const Divider(
              color: Color(0x1A0D0D0D),
              height: 1,
              indent: 14,
              endIndent: 14,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Text(
                widget.summary,
                style: ZeroTheme.body.copyWith(fontSize: 13, height: 1.5),
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SourceRow — Single source result row: favicon + domain + truncated title
// ─────────────────────────────────────────────────────────────────────────────
class _SourceRow extends StatelessWidget {
  final String url;
  const _SourceRow({required this.url});

  @override
  Widget build(BuildContext context) {
    final parsed = Uri.tryParse(url);
    final domain = parsed?.host.replaceFirst('www.', '') ?? url;
    final faviconUrl =
        'https://www.google.com/s2/favicons?domain=$domain&sz=32';

    return InkWell(
      onTap: () {
        try {
          const channel = MethodChannel('com.example.zero_air/tools');
          channel.invokeMethod('open_browser', {'url': url});
        } catch (_) {}
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            // Favicon
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                faviconUrl,
                width: 18,
                height: 18,
                errorBuilder: (_, __, ___) => Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: ZeroTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.public,
                    size: 12,
                    color: ZeroTheme.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    domain,
                    style: ZeroTheme.mono.copyWith(
                      fontSize: 11,
                      color: ZeroTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    url,
                    style: ZeroTheme.mono.copyWith(
                      fontSize: 10,
                      color: ZeroTheme.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 13, color: ZeroTheme.dimText),
          ],
        ),
      ),
    );
  }
}
