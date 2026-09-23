import 'dart:async';
// dart:math not used in live_voice_screen
import '../theme/zero_theme.dart';
import 'package:flutter/material.dart';
import '../voice_agent/services/audio_pipeline_controller.dart';
import '../widgets/mascot/zero_mascot.dart';

class LiveVoiceScreen extends StatefulWidget {
  const LiveVoiceScreen({super.key});

  @override
  State<LiveVoiceScreen> createState() => _LiveVoiceScreenState();
}

class _LiveVoiceScreenState extends State<LiveVoiceScreen>
    with TickerProviderStateMixin {
  String _liveTranscript = '';
  String _aiResponse = '';
  AudioPipelineState _pipeState = AudioPipelineState.idle;
  EmotionState _emotion = EmotionState.idle;

  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<String>? _responseSub;
  StreamSubscription<AudioPipelineState>? _stateSub;
  StreamSubscription<String>? _errorSub;

  // Mic pulse animation (when listening)
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Mic glow rings
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _ringAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));

    _subscribe();
    AudioPipelineController.instance.start();
  }

  void _subscribe() {
    _transcriptSub = AudioPipelineController.instance.liveTranscriptStream
        .listen((t) {
          if (mounted) setState(() => _liveTranscript = t);
        });

    _responseSub = AudioPipelineController.instance.liveLlmResponseStream
        .listen((r) {
          if (mounted) {
            setState(() {
              _aiResponse = r;
              if (r.isNotEmpty) _emotion = EmotionEngine.identify(r);
            });
          }
        });

    _stateSub = AudioPipelineController.instance.stateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _pipeState = s;
        switch (s) {
          case AudioPipelineState.listening:
            _emotion = EmotionState.idle;
            _liveTranscript = ''; // clear old transcript when listening again
            break;
          case AudioPipelineState.routing:
          case AudioPipelineState.generating:
            _emotion = EmotionState.thinking;
            break;
          case AudioPipelineState.speaking:
            // emotion already set from LLM text
            break;
          case AudioPipelineState.error:
            _emotion = EmotionState.sad;
            break;
          default:
            break;
        }
      });
    });

    _errorSub = AudioPipelineController.instance.errorStream.listen((err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _transcriptSub?.cancel();
    _responseSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    AudioPipelineController.instance.stop();
    super.dispose();
  }

  bool get _isListening => _pipeState == AudioPipelineState.listening;
  bool get _isSpeaking => _pipeState == AudioPipelineState.speaking;
  bool get _isProcessing =>
      _pipeState == AudioPipelineState.routing ||
      _pipeState == AudioPipelineState.generating;

  String get _stateLabel {
    if (AudioPipelineController.instance.isMicPaused) return 'Mic paused';
    switch (_pipeState) {
      case AudioPipelineState.listening:
        return 'Listening…';
      case AudioPipelineState.routing:
        return 'Understanding…';
      case AudioPipelineState.generating:
        return 'Thinking…';
      case AudioPipelineState.speaking:
        return 'Speaking…';
      case AudioPipelineState.initializing:
        return 'Starting up…';
      case AudioPipelineState.error:
        return 'Error — retrying…';
      default:
        return '';
    }
  }

  Color get _stateColor {
    if (AudioPipelineController.instance.isMicPaused) return Colors.grey;
    switch (_pipeState) {
      case AudioPipelineState.listening:
        return ZeroTheme.accent;
      case AudioPipelineState.generating:
      case AudioPipelineState.routing:
        return const Color(0xFFFFD740); // amber
      case AudioPipelineState.speaking:
        return Colors.green;
      case AudioPipelineState.error:
        return Colors.red;
      default:
        return ZeroTheme.dimText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMicPaused = AudioPipelineController.instance.isMicPaused;

    return Scaffold(
      backgroundColor: ZeroTheme.cream,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_isProcessing || _isSpeaking) {
            AudioPipelineController.instance.interrupt();
          }
        },
        child: SafeArea(
          child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: ZeroTheme.muted,
                      size: 28,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(_stateLabel),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _stateColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _stateColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isListening)
                            _PulsingDot(color: _stateColor)
                          else
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _stateColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            _stateLabel,
                            style: TextStyle(
                              color: _stateColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // balance back button
                ],
              ),
            ),

            // ── AI response text ───────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _aiResponse.isEmpty
                        ? Text(
                            isMicPaused
                                ? 'Tap the mic to resume'
                                : 'Hi, I\'m listening…',
                            key: const ValueKey('placeholder'),
                            style: TextStyle(
                              color: ZeroTheme.dimText.withValues(alpha: 0.5),
                              fontSize: 22,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : SingleChildScrollView(
                            reverse: true,
                            key: const ValueKey('response'),
                            child: Text(
                              _aiResponse,
                              style: const TextStyle(
                                color: ZeroTheme.ink,
                                fontSize: 24,
                                fontWeight: FontWeight.w300,
                                height: 1.45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // ── Mascot ─────────────────────────────────────────────────────
            Center(
              child: ZeroMascot(
                size: _isSpeaking ? 150 : (_isProcessing ? 140 : 120),
                state: _emotion,
              ),
            ),

            const SizedBox(height: 24),

            // ── Live transcript ────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _liveTranscript.isEmpty ? 0 : 72,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _liveTranscript.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      _liveTranscript,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ZeroTheme.accent.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // ── Mic button ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: GestureDetector(
                onTap: () async {
                  await AudioPipelineController.instance.toggleMic();
                  if (mounted) setState(() {});
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseCtrl, _ringCtrl]),
                  builder: (context, _) {
                    final listening = _isListening && !isMicPaused;
                    return SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Expanding ring (only when listening)
                          if (listening)
                            Transform.scale(
                              scale: 1.0 + _ringAnim.value * 0.6,
                              child: Opacity(
                                opacity: (1 - _ringAnim.value) * 0.25,
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ZeroTheme.accent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Pulsing glow (listening)
                          if (listening)
                            Transform.scale(
                              scale: _pulseAnim.value,
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ZeroTheme.accent.withValues(alpha: 0.12),
                                ),
                              ),
                            ),

                          // Core button
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isMicPaused
                                    ? [
                                        const Color(0xFF2A2A2A),
                                        const Color(0xFF1A1A1A),
                                      ]
                                    : listening
                                    ? [
                                        ZeroTheme.accent,
                                        ZeroTheme.accent.withValues(alpha: 0.5),
                                      ]
                                    : _isProcessing || _isSpeaking
                                    ? [
                                        const Color(0xFF1A237E),
                                        const Color(0xFF283593),
                                      ]
                                    : [
                                        const Color(0xFF1E1E2E),
                                        const Color(0xFF2D2D44),
                                      ],
                              ),
                              boxShadow: listening
                                  ? [
                                      BoxShadow(
                                        color: ZeroTheme.accent.withValues(alpha: 0.4),
                                        blurRadius: 24,
                                        spreadRadius: 4,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              isMicPaused ? Icons.mic_off : Icons.mic,
                              color: isMicPaused
                                  ? ZeroTheme.dimText
                                  : ZeroTheme.ink,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// Small pulsing dot for the status badge
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.4 + 0.6 * _c.value),
        ),
      ),
    );
  }
}
