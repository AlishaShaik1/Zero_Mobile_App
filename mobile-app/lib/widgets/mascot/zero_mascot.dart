import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';

// ============================================================================
// BLOCK 1 — EMOTION / GESTURE DETECTION
// ============================================================================

enum EmotionState {
  idle,
  greet,
  thinking,
  happy,
  sad,
  angry,
  curious,
  celebrate,
  sleepy,
  // ── Story states ──
  walking,
  dancing,
  satelliteHit,
  wakeUp,
  blush,
}

class EmotionEngine {
  static final _negation = RegExp(
    r"\b(not|no|never|n't|isn't|aren't|wasn't|weren't|don't|doesn't|didn't|"
    r"can't|cannot|won't|wouldn't|hardly|barely|ain't)\b",
    caseSensitive: false,
  );
  static final _greetWords = RegExp(
    r"\b(hello|hi|hey|heya|hiya|howdy|greetings|sup|yo|what'?s up|"
    r"good morning|good afternoon|good evening|good night|"
    r"morning|evening|afternoon|namaste|welcome|nice to meet|how are you)\b",
    caseSensitive: false,
  );
  static final _happyWords = RegExp(
    r"\b(happy|great|awesome|love|loved|excellent|amazing|yay+|woohoo|nice|"
    r"glad|excited|perfect|wonderful|fantastic|brilliant|superb|"
    r"congrat\w*|thanks|thank you|thx|ty|cheers|appreciate|good job|well done)\b",
    caseSensitive: false,
  );
  static final _celebrateWords = RegExp(
    r"\b(celebrat\w*|congrats|congratulations|won|winner|champion|"
    r"victory|milestone|achievement|accomplish\w*|done!|finished!|nailed it|"
    r"completed|success|succeeded)\b",
    caseSensitive: false,
  );
  static final _sadWords = RegExp(
    r"\b(sad|sorry|apologize|error|fail\w*|broken|crash\w*|bad|unhappy|"
    r"upset|hurt|disappoint\w*|sucks?|unfortunately|regret\w*|lost|"
    r"worried|ashamed|embarrass\w*|oops|mistake|wrong)\b",
    caseSensitive: false,
  );
  static final _angryWords = RegExp(
    r"\b(angry|anger|mad|furious|rage|frustrat\w*|hate|stupid|dumb|"
    r"annoy\w*|irritat\w*|pissed|ugh+|damn|fed up|screw this|ridiculous|"
    r"absurd|terrible|horrible|worst|useless)\b",
    caseSensitive: false,
  );
  static final _thinkingWords = RegExp(
    r"\b(hmm+|thinking|loading|processing|wait|one sec|calculat\w*|"
    r"analyz\w*|checking|working on it|figuring|looking into|not sure|"
    r"searching|computing|one moment|please wait)\b",
    caseSensitive: false,
  );
  static final _curiousWords = RegExp(
    r"\b(what|how|why|when|where|who|which|interesting|curious|wonder|"
    r"really\?|tell me|explain|elaborate|describe|show me|fascinating|huh\?)\b",
    caseSensitive: false,
  );
  static final _sleepyWords = RegExp(
    r"\b(okay|ok|alright|sure|fine|noted|got it|understood|roger|copy|"
    r"calm|quiet|relax|rest|sleep|tired|slow|easy|chill|no rush|np)\b",
    caseSensitive: false,
  );

  static final _trailingQuestion = RegExp(r"\?\s*$");
  static final _exclaim = RegExp(r"!+");
  static final _shout = RegExp(r"\b[A-Z]{3,}\b");

  static bool _isNegated(String text, RegExpMatch match, {int window = 3}) {
    final before = text.substring(0, match.start);
    final lastBoundary = [
      before.lastIndexOf('.'),
      before.lastIndexOf('!'),
      before.lastIndexOf('?'),
      before.lastIndexOf(','),
    ].fold<int>(-1, (a, b) => b > a ? b : a);
    final clause = before.substring(lastBoundary + 1);
    final words = clause.trim().split(RegExp(r'\s+'));
    final tail = words.length <= window
        ? words
        : words.sublist(words.length - window);
    return _negation.hasMatch(tail.join(' '));
  }

  static int _score(String text, RegExp pattern) {
    var s = 0;
    for (final m in pattern.allMatches(text)) {
      if (!_isNegated(text, m)) s++;
    }
    return s;
  }

  static const _priority = [
    EmotionState.angry,
    EmotionState.celebrate,
    EmotionState.sad,
    EmotionState.greet,
    EmotionState.happy,
    EmotionState.curious,
    EmotionState.thinking,
    EmotionState.sleepy,
  ];

  static EmotionState? _leading(Map<EmotionState, int> scores) {
    EmotionState? best;
    var bestScore = 0;
    for (final s in _priority) {
      final sc = scores[s] ?? 0;
      if (sc > bestScore) {
        bestScore = sc;
        best = s;
      }
    }
    return best;
  }

  static EmotionState identify(String text) {
    final t = text.trim();
    if (t.isEmpty) return EmotionState.idle;
    final scores = <EmotionState, int>{
      EmotionState.angry: _score(t, _angryWords),
      EmotionState.celebrate: _score(t, _celebrateWords),
      EmotionState.sad: _score(t, _sadWords),
      EmotionState.greet: _score(t, _greetWords),
      EmotionState.happy: _score(t, _happyWords),
      EmotionState.curious: _score(t, _curiousWords),
      EmotionState.thinking: _score(t, _thinkingWords),
      EmotionState.sleepy: _score(t, _sleepyWords),
    };
    if (_trailingQuestion.hasMatch(t)) {
      scores[EmotionState.curious] = (scores[EmotionState.curious] ?? 0) + 2;
    }
    final ec = _exclaim.allMatches(t).length;
    final sc = _shout.allMatches(t).length;
    if (ec > 0 || sc > 0) {
      final leader = _leading(scores);
      if (leader != null) {
        scores[leader] = scores[leader]! + (ec > 1 ? 1 : 0) + (sc > 0 ? 1 : 0);
      }
    }
    return _leading(scores) ?? EmotionState.idle;
  }
}

// ============================================================================
// BLOCK 2 — STORY SEQUENCE CONTROLLER
// ZeroStoryPlayer drives the intro with: greet → walk → dance → satelliteHit
// → wakeUp → blush → idle.  Use it on the App Builder home screen.
// ============================================================================

class ZeroStoryPlayer extends StatefulWidget {
  final double mascotSize;
  const ZeroStoryPlayer({super.key, this.mascotSize = 80});

  @override
  State<ZeroStoryPlayer> createState() => _ZeroStoryPlayerState();
}

class _ZeroStoryPlayerState extends State<ZeroStoryPlayer> {
  static const _story = [
    EmotionState.greet,
    EmotionState.walking,
    EmotionState.dancing,
    EmotionState.satelliteHit,
    EmotionState.wakeUp,
    EmotionState.blush,
    EmotionState.idle,
  ];
  static const _durations = [1800, 2200, 2000, 2400, 1800, 1600, 0];

  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _nextStep();
  }

  void _nextStep() {
    if (!mounted) return;
    final dur = _durations[_step];
    if (dur <= 0) {
      // idle — optionally restart after 6s
      _timer = Timer(const Duration(seconds: 6), () {
        if (!mounted) return;
        setState(() => _step = 0);
        _nextStep();
      });
      return;
    }
    _timer = Timer(Duration(milliseconds: dur), () {
      if (!mounted) return;
      setState(() => _step = (_step + 1).clamp(0, _story.length - 1));
      _nextStep();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZeroMascot(state: _story[_step], size: widget.mascotSize);
  }
}

// ============================================================================
// BLOCK 3 — MASCOT WIDGET
// ============================================================================

const double _u = 4.0;
const double _designGrid = 26.0;

class ZeroMascot extends StatefulWidget {
  final EmotionState state;
  final double size;

  const ZeroMascot({super.key, this.state = EmotionState.idle, this.size = 88});

  @override
  State<ZeroMascot> createState() => _ZeroMascotState();
}

class _ZeroMascotState extends State<ZeroMascot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Timer? _blinkTimer;
  bool _isBlinking = false;

  bool _isContinuous(EmotionState s) => const {
    EmotionState.thinking,
    EmotionState.angry,
    EmotionState.happy,
    EmotionState.celebrate,
    EmotionState.greet,
    EmotionState.walking,
    EmotionState.dancing,
    EmotionState.satelliteHit,
    EmotionState.wakeUp,
    EmotionState.blush,
  }.contains(s);

  Duration _periodFor(EmotionState s) {
    switch (s) {
      case EmotionState.thinking:
        return const Duration(milliseconds: 1100);
      case EmotionState.angry:
        return const Duration(milliseconds: 260);
      case EmotionState.happy:
        return const Duration(milliseconds: 600);
      case EmotionState.celebrate:
        return const Duration(milliseconds: 500);
      case EmotionState.greet:
        return const Duration(milliseconds: 700);
      case EmotionState.walking:
        return const Duration(milliseconds: 800);
      case EmotionState.dancing:
        return const Duration(milliseconds: 500);
      case EmotionState.satelliteHit:
        return const Duration(milliseconds: 1600);
      case EmotionState.wakeUp:
        return const Duration(milliseconds: 1200);
      case EmotionState.blush:
        return const Duration(milliseconds: 900);
      default:
        return const Duration(milliseconds: 1500);
    }
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scheduleBlink();
    if (_isContinuous(widget.state)) {
      _ctrl.repeat(period: _periodFor(widget.state));
    }
  }

  @override
  void didUpdateWidget(ZeroMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      if (_isContinuous(widget.state)) {
        _ctrl.repeat(period: _periodFor(widget.state));
      } else {
        _ctrl.animateTo(0, duration: const Duration(milliseconds: 300));
      }
    }
  }

  void _scheduleBlink() {
    final delay = 2500 + math.Random().nextInt(3500);
    _blinkTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() => _isBlinking = true);
      Future.delayed(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        setState(() => _isBlinking = false);
        _scheduleBlink();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _ZeroMascotPainter(
          state: widget.state,
          blink: _isBlinking,
          animPhase: _ctrl.value,
          scale: widget.size / (_u * _designGrid),
        ),
      ),
    );
  }
}

// ============================================================================
// BLOCK 4 — PAINTER
// ============================================================================

class _ZeroMascotPainter extends CustomPainter {
  final EmotionState state;
  final bool blink;
  final double animPhase;
  final double scale;

  const _ZeroMascotPainter({
    required this.state,
    required this.blink,
    required this.animPhase,
    required this.scale,
  });

  static const _outline = Color(0xFF000000);
  static const _body = Color(0xFFFFFFFF);
  static const _eyeBlue = Color(0xFF1E88E5);
  static const _eyeWhite = Color(0xFFFFFFFF);
  static const _eyeAngry = Color(0xFFE53935);
  static const _shadow = Color(0x33000000);
  static const _shade = Color(0xFFE0E0E0);
  static const _darkShade = Color(0xFFBDBDBD);
  static const _tear = Color(0xFF90CAF9);
  static const _sparkleCol = Color(0xFFFFC107);
  static const _blushCol = Color(0xFFFF80AB);
  static const _satelliteCol = Color(0xFF78909C);
  static const _satelliteGold = Color(0xFFFFD54F);
  static const _starCol = Color(0xFFFFF9C4);

  static void _splat(
    List<List<String>> grid,
    int ox,
    int oy,
    List<String> pattern,
  ) {
    for (int y = 0; y < pattern.length; y++) {
      final row = pattern[y];
      for (int x = 0; x < row.length; x++) {
        final ch = row[x];
        if (ch == ' ') continue;
        final gy = oy + y;
        final gx = ox + x;
        if (gy >= 0 && gy < 26 && gx >= 0 && gx < 26) {
          grid[gy][gx] = ch;
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.medium;

    // ── Body offsets for animation ────────────────────────────────
    double bounceY = 0;
    double shakeX = 0;
    double tiltAngle = 0;

    switch (state) {
      case EmotionState.happy:
        bounceY = (-math.sin(animPhase * 2 * math.pi)).clamp(0.0, 1.0) * 1.5;
        break;
      case EmotionState.celebrate:
        bounceY = (-math.sin(animPhase * 2 * math.pi)).clamp(0.0, 1.0) * 2.0;
        break;
      case EmotionState.angry:
        shakeX = math.sin(animPhase * 2 * math.pi * 6) * 0.5;
        break;
      case EmotionState.curious:
        tiltAngle = math.sin(animPhase * math.pi) * 0.06;
        break;
      case EmotionState.walking:
        bounceY = (math.sin(animPhase * 2 * math.pi * 2)).abs() * 0.7;
        break;
      case EmotionState.dancing:
        bounceY =
            (-math.sin(animPhase * 2 * math.pi * 2)).clamp(0.0, 1.0) * 1.8;
        shakeX = math.sin(animPhase * 2 * math.pi) * 0.8;
        break;
      case EmotionState.satelliteHit:
        final phase = animPhase;
        if (phase > 0.5) {
          shakeX = math.sin(phase * math.pi * 8) * 0.6;
          bounceY = 1.0;
        }
        break;
      case EmotionState.wakeUp:
        tiltAngle = math.sin(animPhase * math.pi * 3) * 0.05;
        bounceY = (1.0 - animPhase) * 2.0;
        break;
      case EmotionState.blush:
        bounceY = math.sin(animPhase * math.pi) * 0.4;
        break;
      default:
        break;
    }

    // ── Build pixel grid ─────────────────────────────────────────
    final grid = List.generate(26, (_) => List.filled(26, ' '));

    // Body (always drawn)
    _splat(grid, 6, 3, [
      " OOOOOOOOOOO ",
      "O#WWWWWWWWW#O",
      "OWWWWWWWWWWWo",
      "OWWWWWWWWWWWo",
      "OWWWWWWWWWWWo",
      "OWWWWWWWWWWWo",
      "OWWWWWWWWWWWo",
      "OWWWWWWWWWWWo",
      "OWWWWWWWWWWWo",
      "OWWWWWWWWWWWo",
      "OWWWWWWWWWWWo",
      "O#ooooooooo#O",
      " OOOOOOOOOOO ",
    ]);

    // Legs — animate walk cycle
    final legPhase = animPhase * math.pi * 2;
    final leftLegY =
        (state == EmotionState.walking || state == EmotionState.dancing)
        ? (math.sin(legPhase) * 0.8).round()
        : 0;
    final rightLegY =
        (state == EmotionState.walking || state == EmotionState.dancing)
        ? (-math.sin(legPhase) * 0.8).round()
        : 0;

    _splat(grid, 8, 17 + leftLegY, [" OO ", " OW ", "OOOO", "OWWO", "OOOO"]);
    _splat(grid, 13, 17 + rightLegY, [" OO ", " OW ", "OOOO", "OWWO", "OOOO"]);

    // Antenna removed based on design feedback

    // Shadow
    _splat(grid, 5, 23, ["SSSSSSSSSSSSSS"]);

    // ── Right arm ───────────────────────────────────────────────
    _splat(grid, 18, 10, [
      " OOO",
      " O.O",
      " O.O",
      " O.O",
      "OO.O",
      "O..O",
      "OOOO",
    ]);

    // ── Left arm — state-dependent ───────────────────────────────
    switch (state) {
      case EmotionState.greet:
        final wiggle = (math.sin(animPhase * math.pi * 4) * 0.5).round();
        _splat(grid, 3 + wiggle, 4, [
          " OO ",
          "OWWO",
          "O..O",
          "OOOO",
          " O  ",
          " O  ",
          "OO  ",
        ]);
        break;

      case EmotionState.celebrate:
        final bounce2 = (math.sin(animPhase * math.pi * 2) * 0.7).round();
        _splat(grid, 2, 4 + bounce2, [
          "OO  ",
          "OWO ",
          "O.O ",
          "OOO ",
          " O  ",
          "OO  ",
        ]);
        break;

      case EmotionState.thinking:
        _splat(grid, 3, 9, [" OOO", " O.O", "OO.O", "O..O", "OOOO"]);
        break;

      case EmotionState.dancing:
        final danceWiggle = (math.sin(animPhase * math.pi * 4) * 1.0).round();
        _splat(grid, 3, 6 + danceWiggle, [" OO", "OWO", "OOO", " O "]);
        break;

      case EmotionState.satelliteHit:
        // Arms in shock, raised
        _splat(grid, 2, 5, ["OO", "OW", "OO", " O", " O"]);
        break;

      case EmotionState.wakeUp:
        final wakeWiggle = (math.sin(animPhase * math.pi * 6) * 0.5).round();
        _splat(grid, 3 + wakeWiggle, 8, [" OO", " OW", "OOO", " O "]);
        break;

      default:
        _splat(grid, 3, 10, [" OOO", " O.O", " O.O", " O.O", " OOO"]);
    }

    // ── Eyes ────────────────────────────────────────────────────
    if (blink || state == EmotionState.satelliteHit && animPhase > 0.5) {
      _splat(grid, 9, 9, ["OO"]);
      _splat(grid, 14, 9, ["OO"]);
    } else {
      switch (state) {
        case EmotionState.angry:
          _splat(grid, 9, 9, ["RR", "RR"]);
          _splat(grid, 14, 9, ["RR", "RR"]);
          _splat(grid, 8, 7, ["O "]);
          _splat(grid, 9, 8, ["O "]);
          _splat(grid, 15, 8, [" O"]);
          _splat(grid, 15, 7, [" O"]);
          break;

        case EmotionState.sad:
          _splat(grid, 9, 9, ["ww", "w*"]);
          _splat(grid, 14, 9, ["ww", "w*"]);
          _splat(grid, 10, 11, ["t"]);
          _splat(grid, 15, 11, ["t"]);
          _splat(grid, 10, 12, ["t"]);
          _splat(grid, 15, 12, ["t"]);
          break;

        case EmotionState.happy:
        case EmotionState.celebrate:
        case EmotionState.greet:
        case EmotionState.dancing:
          _splat(grid, 9, 8, ["ww", "ww", "w*"]);
          _splat(grid, 14, 8, ["ww", "ww", "w*"]);
          break;

        case EmotionState.sleepy:
          _splat(grid, 9, 9, ["OO", "  "]);
          _splat(grid, 14, 9, ["OO", "  "]);
          break;

        case EmotionState.curious:
          _splat(grid, 9, 8, ["ww", "w*"]);
          _splat(grid, 14, 8, ["ww", "w*"]);
          break;

        case EmotionState.satelliteHit:
          // Dazed spirals → X eyes
          _splat(grid, 9, 9, ["XX"]);
          _splat(grid, 14, 9, ["XX"]);
          break;

        case EmotionState.wakeUp:
        case EmotionState.blush:
          // Big wide eyes
          _splat(grid, 9, 7, ["ww", "ww", "w*"]);
          _splat(grid, 14, 7, ["ww", "ww", "w*"]);
          break;

        case EmotionState.walking:
          _splat(grid, 9, 9, ["ww", "w*"]);
          _splat(grid, 14, 9, ["ww", "w*"]);
          break;

        default:
          _splat(grid, 9, 9, ["ww", "w*"]);
          _splat(grid, 14, 9, ["ww", "w*"]);
      }
    }

    // ── Render grid ──────────────────────────────────────────────
    final cx = 13 * _u * scale;
    final cy = 10 * _u * scale;

    if (tiltAngle != 0) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(tiltAngle);
      canvas.translate(-cx, -cy);
    }

    for (int y = 0; y < 26; y++) {
      for (int x = 0; x < 26; x++) {
        final c = grid[y][x];
        if (c == ' ') continue;

        Color col;
        switch (c) {
          case 'O':
            col = _outline;
            break;
          case 'W':
            col = _body;
            break;
          case 'o':
            col = _shade;
            break;
          case '#':
            col = _darkShade;
            break;
          case 'w':
            col = _eyeBlue;
            break;
          case '*':
            col = _eyeWhite;
            break;
          case 'R':
            col = _eyeAngry;
            break;
          case 'S':
            col = _shadow;
            break;
          case '.':
            col = _shade;
            break;
          case 't':
            col = _tear;
            break;
          case 'B':
            col = _satelliteGold;
            break;
          case 'X':
            col = _eyeAngry;
            break;
          default:
            col = _outline;
        }

        paint.color = col;

        double dy = y.toDouble();
        double dx = x.toDouble();
        if (c != 'S') {
          dy -= bounceY;
          dx += shakeX;
        }

        canvas.drawRect(
          Rect.fromLTWH(
            dx * _u * scale,
            dy * _u * scale,
            _u * scale,
            _u * scale,
          ),
          paint,
        );
      }
    }

    if (tiltAngle != 0) canvas.restore();

    // ── Thinking dots ────────────────────────────────────────────
    if (state == EmotionState.thinking) {
      for (var i = 0; i < 3; i++) {
        var local = (animPhase * 1.6) - i * 0.28;
        local = local - local.floorToDouble();
        final lift = math.sin(local * math.pi).clamp(0.0, 1.0);
        paint.color = _outline.withValues(alpha: 0.25 + 0.75 * lift);
        canvas.drawRect(
          Rect.fromLTWH(
            (13.5 + i * 1.4) * _u * scale,
            (2.5 - lift * 0.6) * _u * scale,
            0.9 * _u * scale,
            0.9 * _u * scale,
          ),
          paint,
        );
      }
    }

    // ── Celebrate/Happy sparkles ──────────────────────────────────
    if (state == EmotionState.celebrate || state == EmotionState.happy) {
      final twinkle = (math.sin(animPhase * 2 * math.pi * 2) + 1) / 2;
      paint.color = _sparkleCol.withValues(alpha: 0.4 + 0.6 * twinkle);
      void sparkle(double sx, double sy) {
        canvas.drawRect(
          Rect.fromLTWH(
            (sx - 0.5) * _u * scale,
            sy * _u * scale,
            1.0 * _u * scale,
            0.3 * _u * scale,
          ),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            sx * _u * scale,
            (sy - 0.5) * _u * scale,
            0.3 * _u * scale,
            1.0 * _u * scale,
          ),
          paint,
        );
      }

      sparkle(5.0, 2.5);
      sparkle(20.0, 2.0);
      if (state == EmotionState.celebrate) {
        sparkle(3.0, 5.0);
        sparkle(22.0, 4.5);
      }
    }

    // ── Blush cheeks ─────────────────────────────────────────────
    if (state == EmotionState.blush || state == EmotionState.wakeUp) {
      final blushAlpha = state == EmotionState.blush ? 0.55 : 0.35 * animPhase;
      paint.color = _blushCol.withValues(alpha: blushAlpha);
      // Left cheek
      canvas.drawRect(
        Rect.fromLTWH(
          8 * _u * scale,
          11 * _u * scale,
          2 * _u * scale,
          1.2 * _u * scale,
        ),
        paint,
      );
      // Right cheek
      canvas.drawRect(
        Rect.fromLTWH(
          14 * _u * scale,
          11 * _u * scale,
          2 * _u * scale,
          1.2 * _u * scale,
        ),
        paint,
      );
    }

    // ── Satellite falling during satelliteHit ────────────────────
    if (state == EmotionState.satelliteHit) {
      final fallY = animPhase * 8;
      const satX = 16.0;
      final satYBase = 0.0 + fallY;

      // Satellite body
      paint.color = _satelliteCol;
      canvas.drawRect(
        Rect.fromLTWH(
          satX * _u * scale,
          satYBase * _u * scale,
          4 * _u * scale,
          2 * _u * scale,
        ),
        paint,
      );
      // Solar panels
      paint.color = _satelliteGold;
      canvas.drawRect(
        Rect.fromLTWH(
          (satX - 3) * _u * scale,
          (satYBase + 0.5) * _u * scale,
          2.5 * _u * scale,
          1 * _u * scale,
        ),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          (satX + 4) * _u * scale,
          (satYBase + 0.5) * _u * scale,
          2.5 * _u * scale,
          1 * _u * scale,
        ),
        paint,
      );
      // Impact star
      if (animPhase > 0.45) {
        paint.color = _sparkleCol.withValues(alpha: (animPhase - 0.45) * 2.0);
        final starX = (satX + 2) * _u * scale;
        final starY = (satYBase + 2) * _u * scale;
        final starR = 3 * _u * scale * (animPhase - 0.45) * 2;
        final starPath = Path();
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4) - math.pi / 8;
          final r = i.isEven ? starR : starR * 0.45;
          starPath.lineTo(
            starX + math.cos(angle) * r,
            starY + math.sin(angle) * r,
          );
        }
        starPath.close();
        canvas.drawPath(starPath, paint);
      }
    }

    // ── Daze stars after hit ─────────────────────────────────────
    if (state == EmotionState.satelliteHit && animPhase > 0.55) {
      final a = ((animPhase - 0.55) * 2.0).clamp(0.0, 1.0);
      for (var i = 0; i < 3; i++) {
        final angle = animPhase * math.pi * 4 + i * (2 * math.pi / 3);
        final sx = (13 + math.cos(angle) * 3.5) * _u * scale;
        final sy = (1.5 + math.sin(angle) * 1.5) * _u * scale;
        paint.color = _starCol.withValues(alpha: a * 0.9);
        canvas.drawRect(
          Rect.fromLTWH(
            sx - _u * scale * 0.4,
            sy - _u * scale * 0.4,
            _u * scale * 0.8,
            _u * scale * 0.8,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ZeroMascotPainter old) =>
      old.state != state ||
      old.blink != blink ||
      old.animPhase != animPhase ||
      old.scale != scale;
}

// ============================================================================
// Convenience alias kept for backward compat
// ============================================================================
class AIGenerationLoader extends StatelessWidget {
  final double size;
  final bool spinning;
  const AIGenerationLoader({super.key, this.size = 48, this.spinning = false});

  @override
  Widget build(BuildContext context) {
    return ZeroMascot(
      state: spinning ? EmotionState.thinking : EmotionState.idle,
      size: size,
    );
  }
}
