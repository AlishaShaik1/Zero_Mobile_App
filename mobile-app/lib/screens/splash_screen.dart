import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/permissions_service.dart';
import '../theme/zero_theme.dart';
import 'chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AIGenerationLoader — kept for reuse across the app (chat screen, agent screen)
// ─────────────────────────────────────────────────────────────────────────────
class AIGenerationLoader extends StatefulWidget {
  final double size;
  final bool spinning;
  const AIGenerationLoader({
    super.key,
    this.size = 100.0,
    this.spinning = true,
  });

  @override
  State<AIGenerationLoader> createState() => _AIGenerationLoaderState();
}

class _AIGenerationLoaderState extends State<AIGenerationLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    if (widget.spinning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AIGenerationLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !oldWidget.spinning) {
      _controller.repeat();
    } else if (!widget.spinning && oldWidget.spinning) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double pulse = widget.spinning
            ? 1.0 + 0.05 * math.sin(_controller.value * 2 * math.pi)
            : 1.0;
        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image.asset(
              'assets/images/icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.radio_button_checked,
                color: ZeroTheme.accent,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SplashScreen — premium animated, no video dependency
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), _navigate);
  }

  Future<void> _navigate() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool permissionsRequested =
          prefs.getBool('permissions_requested') ?? false;

      if (!permissionsRequested && mounted) {
        await PermissionsService.requestAllAtStartup(context);
        await prefs.setBool('permissions_requested', true);
      }

      if (!mounted) return;
      final bool setupDone = prefs.getBool('setup_done') ?? false;

      final Widget targetScreen = setupDone
          ? const ChatScreen()
          : const SetupScreen();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 250,
          height: 250,
          child: Image.asset(
            'assets/videos/splash.gif',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: ZeroTheme.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.radio_button_checked,
                size: 64,
                color: ZeroTheme.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _BreathingDots — 3 pulsing dots at the bottom
// ─────────────────────────────────────────────────────────────────────────────
class _BreathingDots extends StatefulWidget {
  @override
  State<_BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<_BreathingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i * 0.25) % 1.0;
            final scale = 0.6 + 0.6 * math.sin(phase * math.pi).clamp(0.0, 1.0);
            final opacity =
                0.25 + 0.55 * math.sin(phase * math.pi).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: ZeroTheme.accent.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SetupScreen — upgraded multi-step onboarding with PageView + animations
// ─────────────────────────────────────────────────────────────────────────────
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Rebuild when name changes so the button enables/disables reactively
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'user_name',
      _nameController.text.trim().isEmpty
          ? 'User'
          : _nameController.text.trim(),
    );
    await prefs.setBool('setup_done', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ChatScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _nextPage() {
    // Only block on page 1 (name entry) when name is empty
    if (_currentPage == 1 && _nameController.text.trim().isEmpty) return;
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZeroTheme.background,
      body: Stack(
        children: [
          // Ambient glow top-left
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ZeroTheme.accent.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Ambient glow bottom-right
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar: logo + step dots ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mini logo — no border, just icon + text
                      Row(
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Image.asset(
                              'assets/images/icon.png',
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.radio_button_checked,
                                size: 24,
                                color: ZeroTheme.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'ZERO',
                            style: TextStyle(
                              color: ZeroTheme.ink.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      // Step indicator dots
                      Row(
                        children: List.generate(3, (i) {
                          final active = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 24 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? ZeroTheme.accent
                                  : ZeroTheme.ink.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // ── Pages ─────────────────────────────────────────────────
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      _WelcomePage(),
                      _NamePage(controller: _nameController),
                    ],
                  ),
                ),

                // ── CTA Button ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                  child: _SetupButton(
                    label: _currentPage == 1 ? 'Get Started' : 'Continue',
                    onTap: _nextPage,
                    // Page 0 is always enabled; page 1 requires name
                    enabled:
                        _currentPage == 0 ||
                        _nameController.text.trim().isNotEmpty,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 1 — Welcome (redesigned)
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero icon — visible rounded card so icon shows on white bg
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/images/icon.png', fit: BoxFit.contain),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Meet Zero.',
            style: TextStyle(
              color: ZeroTheme.ink.withValues(alpha: 0.95),
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -1.2,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your personal AI that runs completely on your device.',
            style: TextStyle(
              color: ZeroTheme.ink.withValues(alpha: 0.42),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.5,
              fontFamily: 'Inter',
            ),
          ),

          const SizedBox(height: 40),

          // Feature rows — Material icons, consistent cyan color, no emoji
          const _FeatureRow(
            icon: Icons.memory_rounded,
            title: 'On-Device Intelligence',
            subtitle: 'No cloud. Full privacy.',
          ),
          const SizedBox(height: 22),
          const _FeatureRow(
            icon: Icons.mic_rounded,
            title: 'Voice-First',
            subtitle: '"Hey Zero" hands-free control',
          ),
          const SizedBox(height: 22),
          const _FeatureRow(
            icon: Icons.auto_awesome_rounded,
            title: 'Agentic Actions',
            subtitle: 'Controls your phone & computer',
          ),
        ],
      ),
    );
  }
}

/// Consistent feature row: cyan icon badge + title + subtitle
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: ZeroTheme.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: ZeroTheme.accent, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ZeroTheme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: ZeroTheme.ink.withValues(alpha: 0.40),
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page 2 — Name Entry (redesigned)
// ─────────────────────────────────────────────────────────────────────────────
class _NamePage extends StatelessWidget {
  final TextEditingController controller;
  const _NamePage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge — matching welcome page style, consistent design
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ZeroTheme.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: ZeroTheme.accent,
              size: 26,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'What should\nI call you?',
            style: TextStyle(
              color: ZeroTheme.ink.withValues(alpha: 0.95),
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.8,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Zero will greet you personally.',
            style: TextStyle(
              color: ZeroTheme.ink.withValues(alpha: 0.38),
              fontSize: 15,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 40),

          // Clean text field — NO container wrapper, just the field
          TextField(
            controller: controller,
            autofocus: false,
            style: const TextStyle(
              color: ZeroTheme.ink,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            cursorColor: ZeroTheme.accent,
            cursorWidth: 2.5,
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: ZeroTheme.ink.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: ZeroTheme.accent, width: 2.5),
              ),
              hintText: 'Enter your name...',
              hintStyle: TextStyle(
                color: ZeroTheme.ink.withValues(alpha: 0.18),
                fontSize: 24,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
              ),
              contentPadding: const EdgeInsets.only(bottom: 12),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'SUGGESTIONS',
            style: TextStyle(
              color: ZeroTheme.ink.withValues(alpha: 0.25),
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Alex', 'Jordan', 'Sam', 'Taylor', 'Robin'].map((name) {
              return GestureDetector(
                onTap: () {
                  controller.text = name;
                  controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: name.length),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: ZeroTheme.ink.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: ZeroTheme.ink.withValues(alpha: 0.65),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SetupButton — primary CTA with animated press feedback
// ─────────────────────────────────────────────────────────────────────────────
class _SetupButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _SetupButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  State<_SetupButton> createState() => _SetupButtonState();
}

class _SetupButtonState extends State<_SetupButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.enabled) _pressCtrl.forward();
      },
      onTapUp: (_) async {
        await _pressCtrl.reverse();
        if (widget.enabled) widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? LinearGradient(
                    colors: [
                      ZeroTheme.accent,
                      ZeroTheme.accent.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.enabled ? null : Colors.white12,
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: ZeroTheme.accent.withValues(alpha: 0.40),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  fontFamily: 'Inter',
                ),
              ),
              if (widget.enabled) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
