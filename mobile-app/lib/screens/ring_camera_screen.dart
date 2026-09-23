// ring_camera_screen.dart — Zero Ring Camera Hub
// WHITE UI theme matching rest of app.
// Fixes: green image tint (gaplessPlayback + BoxFit.cover + white bg).
// AI Agent can trigger via ring_take_photo tool.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ring_ble_service.dart';
import '../services/ring_media_receiver.dart';
import '../services/ring_reply_sender.dart';
import '../services/model_service.dart';
import '../widgets/ring_scan_sheet.dart';
import '../theme/zero_theme.dart';

class RingCameraScreen extends StatefulWidget {
  final ModelService? modelService;
  const RingCameraScreen({super.key, this.modelService});

  @override
  State<RingCameraScreen> createState() => _RingCameraScreenState();
}

class _RingCameraScreenState extends State<RingCameraScreen>
    with SingleTickerProviderStateMixin {
  final _ble = RingBleService.instance;
  final _mediaReceiver = RingMediaReceiver.instance;

  StreamSubscription? _bleSub;
  StreamSubscription? _photoSub;
  StreamSubscription? _progressSub;

  RingConnectionState _connState = RingConnectionState.disconnected;
  double _photoProgress = 0.0;
  bool _isReceivingPhoto = false;
  RingPhoto? _selectedPhoto;
  String? _visionAnalysis;
  bool _isAnalyzingVision = false;

  // Agent control
  bool _agentRunning = false;
  String _agentStatus = '';

  late AnimationController _shutterAnimController;

  @override
  void initState() {
    super.initState();
    _shutterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _connState = _ble.connectionState;
    _selectedPhoto = _mediaReceiver.latestPhoto;

    _bleSub = _ble.events.listen((event) {
      if (mounted) setState(() => _connState = _ble.connectionState);
    });

    _photoSub = _mediaReceiver.onPhotoReceived.listen((photo) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _selectedPhoto = photo;
        _isReceivingPhoto = false;
        _photoProgress = 1.0;
        _visionAnalysis = null;
        _agentStatus = 'Photo received!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Saved: ${photo.filePath.split(Platform.pathSeparator).last}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    });

    _progressSub = _mediaReceiver.onProgress.listen((progress) {
      if (mounted) {
        setState(() {
          _photoProgress = progress;
          _isReceivingPhoto = progress < 1.0 && progress > 0.0;
        });
      }
    });

    _mediaReceiver.initialize();
  }

  @override
  void dispose() {
    _shutterAnimController.dispose();
    _bleSub?.cancel();
    _photoSub?.cancel();
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (!_ble.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Zero Ring not connected. Tap scan to connect.'),
          action: SnackBarAction(label: 'Scan', onPressed: () => RingScanSheet.show(context)),
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    _shutterAnimController.forward().then((_) => _shutterAnimController.reverse());

    setState(() {
      _isReceivingPhoto = true;
      _photoProgress = 0.02;
      _visionAnalysis = null;
    });

    try {
      await RingReplySender.instance.sendCommand('take_photo');
    } catch (e) {
      if (mounted) {
        setState(() => _isReceivingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  // AI Agent: analyze photo + optionally send caption to ring OLED
  Future<void> _analyzeWithVision(RingPhoto photo) async {
    setState(() {
      _isAnalyzingVision = true;
      _visionAnalysis = 'Analyzing…';
    });

    const prompt =
        'Describe this image captured by the Zero Ring camera concisely in 2 sentences. '
        'Highlight the main subject and key details.';
    final sb = StringBuffer();

    try {
      await for (final delta in ModelService().chatWithImage(prompt, photo.filePath)) {
        if (delta is ContentDelta) {
          sb.write(delta.text);
          if (mounted) setState(() => _visionAnalysis = sb.toString());
        }
      }
      final reply = sb.toString().trim();
      if (reply.isNotEmpty && _ble.isConnected) {
        await RingReplySender.instance.sendCaption(reply);
      }
    } catch (e) {
      if (mounted) setState(() => _visionAnalysis = 'Vision error: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzingVision = false);
    }
  }

  // AI Agent auto-trigger: fires camera then analyzes automatically
  Future<void> _agentCaptureAndAnalyze() async {
    if (!_ble.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect Zero Ring first.')),
      );
      return;
    }
    setState(() {
      _agentRunning = true;
      _agentStatus = 'Agent: triggering camera…';
    });

    await _capturePhoto();

    // Wait up to 15s for photo to arrive
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (_isReceivingPhoto || (_selectedPhoto == null)) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (DateTime.now().isAfter(deadline)) break;
      if (!mounted) return;
    }

    if (_selectedPhoto != null && mounted) {
      setState(() => _agentStatus = 'Agent: analyzing photo with AI…');
      await _analyzeWithVision(_selectedPhoto!);
    }

    if (mounted) setState(() { _agentRunning = false; _agentStatus = 'Done'; });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connState == RingConnectionState.connected;
    final photos = _mediaReceiver.savedPhotos;

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
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? const Color(0xFF10B981) : Colors.grey,
                boxShadow: isConnected
                    ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'RING CAMERA',
              style: ZeroTheme.mono.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        actions: [
          // Agent auto-capture button
          if (widget.modelService != null)
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                color: _agentRunning ? ZeroTheme.accent : ZeroTheme.ink,
              ),
              tooltip: 'AI: Capture & Analyze',
              onPressed: _agentRunning ? null : _agentCaptureAndAnalyze,
            ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: isConnected ? const Color(0xFF10B981) : ZeroTheme.muted,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isConnected ? 'Connected' : 'Disconnected',
              style: TextStyle(
                color: isConnected ? const Color(0xFF10B981) : ZeroTheme.muted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
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
          // Agent status bar
          if (_agentRunning || _agentStatus.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: ZeroTheme.accent.withValues(alpha: 0.08),
              child: Row(
                children: [
                  if (_agentRunning)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: ZeroTheme.accent),
                    ),
                  if (_agentRunning) const SizedBox(width: 10),
                  Text(
                    _agentStatus,
                    style: ZeroTheme.mono.copyWith(fontSize: 11, color: ZeroTheme.accent),
                  ),
                ],
              ),
            ),

          // Main viewfinder
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildViewfinder(isConnected),
            ),
          ),

          // Transfer progress bar
          if (_isReceivingPhoto)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Streaming photo over BLE…',
                        style: ZeroTheme.mono.copyWith(fontSize: 11, color: ZeroTheme.accent),
                      ),
                      Text(
                        '${(_photoProgress * 100).toInt()}%',
                        style: ZeroTheme.mono.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: ZeroTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _photoProgress,
                      backgroundColor: ZeroTheme.ink.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(ZeroTheme.accent),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),

          // Photo gallery strip
          if (photos.isNotEmpty)
            Container(
              height: 72,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final p = photos[photos.length - 1 - index]; // newest first
                  final isCur = _selectedPhoto?.filePath == p.filePath;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedPhoto = p;
                      _visionAnalysis = null;
                    }),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCur ? ZeroTheme.accent : ZeroTheme.ink.withValues(alpha: 0.2),
                          width: isCur ? 2.5 : 1,
                        ),
                        boxShadow: isCur
                            ? [BoxShadow(color: ZeroTheme.accent.withValues(alpha: 0.3), blurRadius: 8)]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(p.filePath),
                          fit: BoxFit.cover,
                          gaplessPlayback: true, // FIX: no green flash between frames
                          color: null,           // FIX: no color filter tint
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Shutter bar
          Container(
            decoration: const BoxDecoration(
              color: ZeroTheme.white,
              border: Border(top: BorderSide(color: ZeroTheme.ink, width: 2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Scan / Reconnect
                _actionBtn(
                  icon: Icons.radar,
                  label: 'Scan',
                  onTap: () => RingScanSheet.show(context),
                ),

                // Shutter
                GestureDetector(
                  onTap: _isReceivingPhoto ? null : _capturePhoto,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 0.88).animate(_shutterAnimController),
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isReceivingPhoto
                            ? ZeroTheme.ink.withValues(alpha: 0.1)
                            : ZeroTheme.ink,
                        border: Border.all(color: ZeroTheme.ink, width: 3),
                      ),
                      child: Center(
                        child: _isReceivingPhoto
                            ? SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  color: ZeroTheme.accent,
                                  strokeWidth: 3,
                                  value: _photoProgress,
                                ),
                              )
                            : const Icon(Icons.camera_alt, color: ZeroTheme.white, size: 32),
                      ),
                    ),
                  ),
                ),

                // AI Vision
                _actionBtn(
                  icon: Icons.auto_awesome,
                  label: 'Describe',
                  color: _selectedPhoto == null || _isAnalyzingVision ? ZeroTheme.muted : ZeroTheme.accent,
                  onTap: _selectedPhoto == null || _isAnalyzingVision
                      ? null
                      : () => _analyzeWithVision(_selectedPhoto!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    final c = color ?? ZeroTheme.ink;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 26),
          const SizedBox(height: 4),
          Text(label, style: ZeroTheme.mono.copyWith(fontSize: 10, color: c)),
        ],
      ),
    );
  }

  Widget _buildViewfinder(bool isConnected) {
    return Container(
      decoration: BoxDecoration(
        color: ZeroTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZeroTheme.ink, width: 2),
        boxShadow: [
          BoxShadow(
            color: ZeroTheme.ink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(4, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image or placeholder — white bg eliminates green fringe
            Container(color: ZeroTheme.white),
            if (_selectedPhoto != null)
              Image.file(
                File(_selectedPhoto!.filePath),
                fit: BoxFit.contain,
                gaplessPlayback: true,  // FIX green flash
                color: null,            // FIX color tint
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_enhance_outlined,
                      size: 64,
                      color: isConnected ? ZeroTheme.accent : ZeroTheme.muted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isConnected
                          ? 'Tap shutter to capture from ring'
                          : 'Connect Zero Ring to capture',
                      style: ZeroTheme.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: 8),
                      Text(
                        'or say "ring take photo"',
                        style: ZeroTheme.mono.copyWith(fontSize: 11, color: ZeroTheme.muted),
                      ),
                    ],
                  ],
                ),
              ),

            // Viewfinder corners
            CustomPaint(painter: _ViewfinderPainter()),

            // Photo metadata overlay
            if (_selectedPhoto != null)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _overlayPill(
                      icon: Icons.check_circle,
                      iconColor: const Color(0xFF10B981),
                      text: 'Saved to Gallery',
                      textColor: const Color(0xFF10B981),
                    ),
                    _overlayPill(
                      text: '${(_selectedPhoto!.byteSize / 1024).toStringAsFixed(1)} KB • OV2640',
                    ),
                  ],
                ),
              ),

            // Vision analysis overlay
            if (_visionAnalysis != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZeroTheme.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ZeroTheme.ink, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: ZeroTheme.ink.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (_isAnalyzingVision)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: ZeroTheme.accent),
                            )
                          else
                            const Icon(Icons.auto_awesome, color: ZeroTheme.accent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'ZERO AI VISION',
                            style: ZeroTheme.mono.copyWith(
                              color: ZeroTheme.accent,
                              fontSize: 10,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_visionAnalysis!, style: ZeroTheme.body.copyWith(fontSize: 12, height: 1.4)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _overlayPill({IconData? icon, Color? iconColor, required String text, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ZeroTheme.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZeroTheme.ink.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? ZeroTheme.ink, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: ZeroTheme.mono.copyWith(
              fontSize: 10,
              color: textColor ?? ZeroTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Viewfinder corner painter — ink color for white theme
class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E).withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const cornerLen = 22.0;
    const m = 16.0;

    canvas.drawLine(const Offset(m, m), const Offset(m + cornerLen, m), paint);
    canvas.drawLine(const Offset(m, m), const Offset(m, m + cornerLen), paint);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m - cornerLen, m), paint);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + cornerLen), paint);
    canvas.drawLine(Offset(m, size.height - m), Offset(m + cornerLen, size.height - m), paint);
    canvas.drawLine(Offset(m, size.height - m), Offset(m, size.height - m - cornerLen), paint);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m - cornerLen, size.height - m), paint);
    canvas.drawLine(Offset(size.width - m, size.height - m), Offset(size.width - m, size.height - m - cornerLen), paint);

    // Center dot
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      3,
      Paint()..color = const Color(0xFF1A1A2E).withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
