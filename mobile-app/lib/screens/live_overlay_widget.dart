import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../theme/zero_theme.dart';
import '../voice_agent/services/audio_pipeline_controller.dart';
import '../services/model_service.dart';

class LiveOverlayWidget extends StatefulWidget {
  const LiveOverlayWidget({super.key});

  @override
  State<LiveOverlayWidget> createState() => _LiveOverlayWidgetState();
}

class _LiveOverlayWidgetState extends State<LiveOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _currentTranscript = "";
  String _currentResponse = "";
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initAgent();
  }

  Future<void> _initAgent() async {
    // ModelService needs initialization in the overlay isolate
    await ModelService().initialize();

    AudioPipelineController.instance.start();

    AudioPipelineController.instance.liveTranscriptStream.listen((text) {
      if (mounted) setState(() => _currentTranscript = text);
    });

    AudioPipelineController.instance.liveLlmResponseStream.listen((text) {
      if (mounted) setState(() => _currentResponse = text);
    });
    setState(() {
      _isInit = true;
    });
  }

  @override
  void dispose() {
    AudioPipelineController.instance.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Material(
        color: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Material(
      color: ZeroTheme.cream.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      child: SafeArea(
        child: Stack(
          children: [
            // Close Button
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: ZeroTheme.ink),
                onPressed: () {
                  FlutterOverlayWindow.closeOverlay();
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LLM Response Text
                  Expanded(
                    child: SingleChildScrollView(
                      reverse: true, // Auto-scroll to bottom
                      child: Text(
                        _currentResponse.isEmpty
                            ? "Hi, I'm listening..."
                            : _currentResponse,
                        style: const TextStyle(
                          color: ZeroTheme.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),

                  // Visualizer Orb
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                                center: Alignment.center,
                                radius: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF8E2DE2,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 40 * _pulseAnimation.value,
                                  spreadRadius: 10 * _pulseAnimation.value,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // User Transcript Text
                  Container(
                    height: 60,
                    alignment: Alignment.center,
                    child: Text(
                      _currentTranscript,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ZeroTheme.muted,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
