// ring_companion_screen.dart — Zero Ring Companion Dashboard
// Premium investor-ready UI: real-time BLE ring control, live audio visualizer,
// voice AI pipeline, camera, and OLED mirror.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/ring_ble_service.dart';
import '../services/ring_audio_pipeline.dart';
import '../services/phone_mic_stt_service.dart';
import '../services/ring_media_receiver.dart';
import '../services/ring_reply_sender.dart';
import '../services/model_service.dart';
import '../widgets/ring_scan_sheet.dart';
import 'ring_camera_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF060818);
const _surface = Color(0xFF0D1128);
const _card = Color(0xFF111830);
const _border = Color(0xFF1E2A50);
const _accent = Color(0xFF5B8EFF);
const _accentB = Color(0xFF9B5BFF);
const _green = Color(0xFF00E5A0);
const _red = Color(0xFFFF4D6A);
const _amber = Color(0xFFFFB347);
const _white = Color(0xFFEEF2FF);
const _sub = Color(0xFF6B7BB8);

class RingCompanionScreen extends StatefulWidget {
  const RingCompanionScreen({super.key});

  @override
  State<RingCompanionScreen> createState() => _RingCompanionScreenState();
}

class _RingCompanionScreenState extends State<RingCompanionScreen>
    with TickerProviderStateMixin {
  final _ble = RingBleService.instance;
  final _audioPipeline = RingAudioPipeline.instance;
  final _mediaReceiver = RingMediaReceiver.instance;

  // subscriptions
  StreamSubscription? _bleSub,
      _photoSub,
      _progressSub,
      _transcriptSub,
      _aiResponseSub,
      _energySub,
      _stateSub,
      _diagSub;

  RingConnectionState _connState = RingConnectionState.disconnected;
  String _latestTranscript = 'Hold ring button 2s to speak…';
  String _ringAudioDiag = ''; // live proof that ring audio is arriving
  String _latestAiResponse = 'AI response will appear here.';
  String _currentCaption = '';
  double _audioEnergy = 0.0;
  double _photoProgress = 0.0;
  bool _isReceivingPhoto = false;
  RingPhoto? _latestPhoto;
  String? _visionResponse;
  bool _isAnalyzingVision = false;
  // ignore: unused_field
  bool _isListening = false; // true while transcript is live, false when AI responds

  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  // animations
  late AnimationController _pulseCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _gradCtrl;

  // wave bars
  final List<double> _waveBars = List.generate(28, (i) => 0.15);
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _waveCtrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 60),
          )
          ..addListener(_updateWaveBars)
          ..repeat();
    _gradCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _initServices();
  }

  void _updateWaveBars() {
    if (!mounted) return;
    final isActive = _audioPipeline.isStreamingFromRing;
    setState(() {
      for (int i = 0; i < _waveBars.length; i++) {
        if (isActive) {
          final target =
              0.1 +
              _audioEnergy *
                  0.9 *
                  (0.5 +
                      0.5 * math.sin(i * 0.7 + _waveCtrl.value * math.pi * 2));
          _waveBars[i] =
              _waveBars[i] * 0.7 + target * 0.3 + _rng.nextDouble() * 0.08;
        } else {
          _waveBars[i] = _waveBars[i] * 0.9 + 0.08 * 0.1;
        }
        _waveBars[i] = _waveBars[i].clamp(0.05, 1.0);
      }
    });
  }

  void _initServices() {
    _connState = _ble.connectionState;

    _bleSub = _ble.events.listen((e) {
      if (mounted) {
        setState(() {
          _connState = _ble.connectionState;
        });
      }
    });

    _photoSub = _mediaReceiver.onPhotoReceived.listen((photo) {
      if (!mounted) return;
      setState(() {
        _latestPhoto = photo;
        _isReceivingPhoto = false;
        _photoProgress = 1.0;
      });
      _autoAnalyzePhoto(photo);
    });

    _progressSub = _mediaReceiver.onProgress.listen((p) {
      if (mounted) {
        setState(() {
          _photoProgress = p;
          _isReceivingPhoto = p < 1.0 && p > 0;
        });
      }
    });

    _transcriptSub = _audioPipeline.liveTranscript.listen((t) {
      if (mounted && t.isNotEmpty) {
        setState(() {
          _latestTranscript = t;
          _isListening = true;
        });
      }
    });

    _aiResponseSub = _audioPipeline.liveAiResponse.listen((r) {
      if (mounted && r.isNotEmpty) {
        setState(() {
          _latestAiResponse = r;
          _currentCaption = r;
          _isListening = false;
        });
      }
    });

    _energySub = _audioPipeline.energyStream.listen((e) {
      if (mounted) {
        setState(() {
          _audioEnergy = e;
        });
      }
    });

    _stateSub = _audioPipeline.stateStream.listen((s) {
      if (mounted) {
        setState(() {
          _isListening = s == RingPipelineState.listening;
          // Clear the live audio counter once a session is done.
          if (s == RingPipelineState.idle) _ringAudioDiag = '';
        });
      }
    });

    // Live proof that ring audio is actually arriving (seconds + KB).
    _diagSub = _audioPipeline.diagnostics.listen((d) {
      if (mounted && d.isNotEmpty) {
        setState(() => _ringAudioDiag = d);
      }
    });

    // Subscribe to phone mic live transcript so UI shows what user is saying
    PhoneMicSTT.instance.transcript.listen((t) {
      if (mounted && t.isNotEmpty) {
        setState(() => _latestTranscript = t);
      }
    });

    _ble.initialize();
    // Small delay so native EventChannel listener is ready before connecting
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _ble.connect();
    });
    _audioPipeline.initialize(); // initialize() already calls start() internally
    _mediaReceiver.initialize();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();
    _gradCtrl.dispose();
    _bleSub?.cancel();
    _photoSub?.cancel();
    _progressSub?.cancel();
    _transcriptSub?.cancel();
    _aiResponseSub?.cancel();
    _energySub?.cancel();
    _stateSub?.cancel();
    _diagSub?.cancel();
    _textCtrl.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    if (_connState == RingConnectionState.connected) {
      await _ble.disconnect();
    } else {
      await _ble.connect();
    }
  }

  Future<void> _takePhoto() async {
    if (!_ble.isConnected) {
      _snack('Connect Zero Ring first');
      return;
    }
    setState(() {
      _isReceivingPhoto = true;
      _photoProgress = 0.05;
      _visionResponse = null;
    });
    await RingReplySender.instance.sendCommand('take_photo');
  }

  Future<void> _autoAnalyzePhoto(RingPhoto photo) async {
    setState(() {
      _isAnalyzingVision = true;
      _visionResponse = 'AI analyzing image…';
    });
    const prompt =
        'Describe what you see in this photo from the smart ring in 2 short sentences.';
    final sb = StringBuffer();
    try {
      await for (final delta in ModelService().chatWithImage(
        prompt,
        photo.filePath,
      )) {
        if (delta is ContentDelta) {
          sb.write(delta.text);
          if (mounted) {
            setState(() {
              _visionResponse = sb.toString();
            });
          }
        }
      }
      final txt = sb.toString().trim();
      if (txt.isNotEmpty) {
        await RingReplySender.instance.sendCaption(txt);
        if (mounted) {
          setState(() {
            _currentCaption = txt;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _visionResponse = 'Image captured and ready.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingVision = false;
        });
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: _white)),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isConn = _connState == RingConnectionState.connected;
    final isScan =
        _connState == RingConnectionState.scanning ||
        _connState == RingConnectionState.connecting;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            floating: false,
            pinned: true,
            backgroundColor: _bg,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accent, _accentB],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.trip_origin,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Zero Ring',
                    style: TextStyle(
                      color: _white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accent.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A1040), _bg],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.radar, color: _accent),
                tooltip: 'Scan for Ring',
                onPressed: () => RingScanSheet.show(context),
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Connection hero card ─────────────────────────────────
                _buildConnectionHero(isConn, isScan),
                const SizedBox(height: 8),

                // ── Voice link diagnostics (which stage is broken?) ─────
                _buildVoiceLinkDiagnostics(isConn),
                const SizedBox(height: 16),

                // ── OLED mirror + quick stats row ────────────────────────
                Row(
                  children: [
                    Expanded(child: _buildOledMirror(isConn)),
                    const SizedBox(width: 12),
                    _buildQuickStats(),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Voice AI card ────────────────────────────────────────
                _buildVoiceCard(isConn),
                const SizedBox(height: 16),

                // ── Camera / Vision card ─────────────────────────────────
                _buildCameraCard(isConn),
                const SizedBox(height: 16),

                // ── Text query card ──────────────────────────────────────
                _buildTextCard(isConn),
                const SizedBox(height: 16),

                // ── Gesture guide ────────────────────────────────────────
                _buildGestureGuide(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Connection hero ───────────────────────────────────────────────────────
  Widget _buildConnectionHero(bool isConn, bool isScan) {
    final color = isConn ? _green : (isScan ? _amber : _sub);
    final label = isConn
        ? 'Connected'
        : (isScan ? 'Scanning…' : 'Disconnected');

    return AnimatedBuilder(
      animation: _gradCtrl,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isConn
                  ? [const Color(0xFF0D2040), const Color(0xFF0A1830)]
                  : [const Color(0xFF130D20), const Color(0xFF0D1128)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: color.withValues(alpha: 0.3 + 0.1 * _gradCtrl.value),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              // Ring icon with pulse
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(
                          alpha: 0.08 + 0.06 * _pulseCtrl.value,
                        ),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.3),
                            color.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: color.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isConn ? Icons.sensors : Icons.sensors_off,
                        color: color,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            boxShadow: [BoxShadow(color: color, blurRadius: 6)],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConn
                          ? 'Zero Ring · XIAO ESP32S3 · BLE 5.0'
                          : 'Seeed XIAO ESP32S3 Sense · NimBLE',
                      style: const TextStyle(color: _sub, fontSize: 12),
                    ),
                    if (isConn) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _pill('16kHz Mic', _accent),
                          const SizedBox(width: 6),
                          _pill('AI Ready', _green),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _glowButton(
                label: isConn
                    ? 'Disconnect'
                    : (isScan ? 'Scanning' : 'Connect'),
                color: isConn ? _red : _accent,
                onTap: _toggleConnection,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Voice link diagnostics ────────────────────────────────────────────────
  // Shows exactly which stage of the ring→phone voice link is broken, so
  // failures are never a silent black box again:
  //   • not connected            → connection problem (see error text)
  //   • connected, mic not armed → BLE notifications not enabled
  //   • connected, MTU too small → ring audio (240B) cannot pass
  //   • everything green         → speak, double-tap, done
  Widget _buildVoiceLinkDiagnostics(bool isConn) {
    final mtu = _ble.mtu;
    final micArmed = _ble.micNotifyArmed;
    final err = _ble.lastConnectionError;

    String status;
    Color color;
    IconData icon;

    if (!isConn) {
      icon = Icons.error_outline;
      if (err != null && err.isNotEmpty) {
        color = _red;
        status = 'Not connected — error: $err';
      } else if (_connState == RingConnectionState.scanning ||
          _connState == RingConnectionState.connecting) {
        color = _amber;
        status = 'Looking for the ring… (is it awake & not paired to another phone?)';
      } else {
        color = _amber;
        status = 'Disconnected — tap Connect';
      }
    } else if (!micArmed) {
      icon = Icons.error_outline;
      color = _red;
      status = 'Connected — but mic NOT enabled (voice will not work yet)';
    } else if (mtu > 0 && mtu < 250) {
      icon = Icons.warning_amber;
      color = _red;
        status =
            'Connected — MTU $mtu is too small for voice (needs ~517). '
            'Retrying MTU…';
    } else {
      icon = Icons.check_circle;
      color = _green;
      status = mtu > 0
          ? 'Voice link ready — MTU $mtu · mic ON'
          : 'Connected · mic ON';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── OLED mirror (left card) ───────────────────────────────────────────────
  Widget _buildOledMirror(bool isConn) {
    return _card_(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.crop_portrait, color: _accent, size: 14),
              SizedBox(width: 6),
              Text(
                'OLED Mirror',
                style: TextStyle(
                  color: _sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _accent.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'ZERO',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (isConn) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _green,
                          boxShadow: [BoxShadow(color: _green, blurRadius: 4)],
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Icon(
                      Icons.smart_toy,
                      color: Colors.white38,
                      size: 12,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    _currentCaption.isNotEmpty
                        ? _currentCaption
                        : '2x: speak',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick stats (right side, vertical) ───────────────────────────────────
  Widget _buildQuickStats() {
    final isConn = _connState == RingConnectionState.connected;
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          _statTile('16 kHz', 'Mic Rate', Icons.graphic_eq, _accent),
          const SizedBox(height: 10),
          _statTile(
            isConn ? 'BLE 5' : 'OFF',
            'Radio',
            Icons.bluetooth,
            isConn ? _green : _sub,
          ),
          const SizedBox(height: 10),
          _statTile('AI', 'On-Device', Icons.memory, _accentB),
        ],
      ),
    );
  }

  Widget _statTile(String val, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(label, style: const TextStyle(color: _sub, fontSize: 9)),
        ],
      ),
    );
  }

  // ── Voice AI card ─────────────────────────────────────────────────────────
  Widget _buildVoiceCard(bool isConn) {
    final isStreaming = _audioPipeline.isStreamingFromRing || _audioPipeline.isPhoneMicListening || _isListening;

    return _card_(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accent.withValues(alpha: 0.2),
                      _accentB.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic, color: _accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice AI Pipeline',
                      style: TextStyle(
                        color: _white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Ring mic → STT → Zero AI → OLED',
                      style: TextStyle(color: _sub, fontSize: 11),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isStreaming
                      ? _green.withValues(alpha: 0.15)
                      : _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isStreaming
                        ? _green.withValues(alpha: 0.5)
                        : _border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isStreaming)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _green,
                          boxShadow: [BoxShadow(color: _green, blurRadius: 6)],
                        ),
                      ),
                    if (isStreaming) const SizedBox(width: 5),
                    Text(
                      isStreaming ? 'LIVE' : 'READY',
                      style: TextStyle(
                        color: isStreaming ? _green : _sub,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Waveform visualizer
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_waveBars.length, (i) {
                final h = ((_waveBars[i]).clamp(0.05, 1.0) * 38).toDouble();
                final hue = 220.0 + i * 2.5;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: isStreaming
                          ? [
                              HSLColor.fromAHSL(1, hue, 0.9, 0.5).toColor(),
                              HSLColor.fromAHSL(
                                1,
                                hue + 40,
                                0.9,
                                0.7,
                              ).toColor(),
                            ]
                          : [_border, _surface],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

          // Live ring-audio link status — proves the ring's mic audio is
          // physically reaching the phone (fixes the "is it even receiving?"
          // black box that made every earlier fix unverifiable).
          if (_audioPipeline.isStreamingFromRing || _ringAudioDiag.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.graphic_eq,
                    size: 12,
                    color: _green,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _ringAudioDiag.isNotEmpty
                          ? _ringAudioDiag
                          : 'Waiting for ring audio…',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Transcript → AI response
          _transcriptRow(
            'You',
            _latestTranscript,
            Icons.record_voice_over,
            _accent,
          ),
          const SizedBox(height: 8),
          _transcriptRow(
            'Zero',
            _latestAiResponse,
            Icons.auto_awesome,
            _accentB,
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: isStreaming ? 'Stop & Send' : 'Start Listen',
                  icon: isStreaming ? Icons.stop_circle : Icons.mic_none,
                  color: isStreaming ? _red : _green,
                  onTap: () async {
                    // ── RING mic (preferred — this is ring→phone voice) ──────
                    if (isConn && !isStreaming) {
                      setState(() {
                        _latestTranscript = 'Starting ring mic…';
                        _ringAudioDiag = '';
                      });
                      final started =
                          await _audioPipeline.startRingMicFromPhone();
                      if (!started) {
                        // Ring dropped mid-way → fall back to phone mic.
                        setState(() => _latestTranscript = 'Listening...');
                        _audioPipeline.triggerManualSpeechStart();
                      }
                      return;
                    }
                    // ── Stop a running ring-mic session: send to STT now ────
                    if (isConn && isStreaming) {
                      _audioPipeline.finalizeNow();
                      await _audioPipeline.stopRingMicFromPhone();
                      return;
                    }
                    // ── Phone-mic fallback (ring not connected) ──────────────
                    if (_audioPipeline.isPhoneMicListening || isStreaming) {
                      _audioPipeline.triggerManualSpeechEnd();
                    } else {
                      setState(() => _latestTranscript = 'Listening...');
                      _audioPipeline.triggerManualSpeechStart();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transcriptRow(String label, String text, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: _white, fontSize: 12, height: 1.4),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Camera / Vision card ──────────────────────────────────────────────────
  Widget _buildCameraCard(bool isConn) {
    return _card_(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accentB.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: _accentB, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ring Camera + Vision AI',
                      style: TextStyle(
                        color: _white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'OV2640 → BLE JPEG → Llama Vision',
                      style: TextStyle(color: _sub, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, color: _sub, size: 18),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RingCameraScreen()),
                ),
              ),
              _actionButton(
                label: 'Snap',
                icon: Icons.camera,
                color: _accentB,
                onTap: (isConn && !_isReceivingPhoto) ? _takePhoto : null,
                compact: true,
              ),
            ],
          ),

          if (_isReceivingPhoto) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.download, color: _accentB, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _photoProgress,
                      backgroundColor: _border,
                      valueColor: const AlwaysStoppedAnimation<Color>(_accentB),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(_photoProgress * 100).toInt()}%',
                  style: const TextStyle(color: _sub, fontSize: 11),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          if (_latestPhoto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.file(
                    File(_latestPhoto!.filePath),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: _green, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'OV2640',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_outlined,
                    color: _sub.withValues(alpha: 0.5),
                    size: 30,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Triple-tap ring or tap Snap',
                    style: TextStyle(color: _sub, fontSize: 12),
                  ),
                ],
              ),
            ),

          if (_visionResponse != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accentB.withValues(alpha: 0.08),
                    _accent.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accentB.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: _accentB, size: 13),
                      const SizedBox(width: 6),
                      Text(
                        _isAnalyzingVision
                            ? 'AI analyzing…'
                            : 'Vision AI result:',
                        style: const TextStyle(
                          color: _accentB,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _visionResponse!,
                    style: const TextStyle(
                      color: _white,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Text query card ───────────────────────────────────────────────────────
  Widget _buildTextCard(bool isConn) {
    return _card_(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.keyboard, color: _accent, size: 16),
              SizedBox(width: 8),
              Text(
                'Send Query to Ring AI',
                style: TextStyle(
                  color: _white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textCtrl,
                  focusNode: _queryFocus,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (val) {
                    final text = val.trim();
                    if (text.isNotEmpty) {
                      _audioPipeline.processTextQuery(text);
                      _textCtrl.clear();
                      _snack('Sent to AI${isConn ? ' + Ring' : ''}');
                    }
                  },
                  onTap: () {
                    FocusScope.of(context).requestFocus(_queryFocus);
                  },
                  style: const TextStyle(color: _white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ask anything…',
                    hintStyle: const TextStyle(color: _sub, fontSize: 13),
                    filled: true,
                    fillColor: _bg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                        final text = _textCtrl.text.trim();
                        if (text.isNotEmpty) {
                          _audioPipeline.processTextQuery(text);
                          _textCtrl.clear();
                          _snack('Sent to AI${isConn ? ' + Ring' : ''}');
                        }
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_accent, _accentB]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.4),
                              blurRadius: 12,
                            ),
                          ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Gesture guide ─────────────────────────────────────────────────────────
  Widget _buildGestureGuide() {
    // Matches the firmware button map (XIAO ESP32S3, single button D1):
    //   Home, double tap → start/stop ring mic (voice → phone)
    //   Home, hold  >2s  → push-to-talk alternative (hold & speak, release = send)
    //   Home, single tap → next screen
    //   2.5s silence     → auto-stops the mic and sends what you said
    final gestures = [
      ('Double Tap', 'Start/stop ring mic → AI', Icons.multitrack_audio),
      ('Hold 2s', 'Push-to-talk (release = send)', Icons.mic),
      ('Single Tap', 'Next screen', Icons.touch_app),
      ('Silence 2.5s', 'Auto-sends what you said', Icons.send_to_mobile),
    ];
    return _card_(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gesture, color: _accent, size: 16),
              SizedBox(width: 8),
              Text(
                'Ring Gesture Guide',
                style: TextStyle(
                  color: _white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...gestures.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(g.$3, color: _accent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.$1,
                        style: const TextStyle(
                          color: _white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        g.$2,
                        style: const TextStyle(color: _sub, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable widgets ──────────────────────────────────────────────────────

  Widget _card_({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _glowButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            gradient: onTap != null
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.9),
                      color.withValues(alpha: 0.7),
                    ],
                  )
                : null,
            color: onTap == null ? _surface : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: onTap != null
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: compact ? 14 : 16),
              SizedBox(width: compact ? 4 : 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
