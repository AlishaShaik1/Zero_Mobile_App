// zero_space_art.dart — Procedural pixel-art space background + satellite + terminal comet
// All elements are drawn programmatically with pixel-grid aesthetics.

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Animated Space Background (Twinkling Stars + Galaxy + Mountains + Grid)
// ─────────────────────────────────────────────────────────────────────────────

class ZeroSpaceDecor extends StatefulWidget {
  const ZeroSpaceDecor({super.key});

  @override
  State<ZeroSpaceDecor> createState() => _ZeroSpaceDecorState();
}

class _ZeroSpaceDecorState extends State<ZeroSpaceDecor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
      builder: (_, __) => SizedBox.expand(
        child: CustomPaint(painter: _SpaceDecorPainter(tick: _ctrl.value)),
      ),
    );
  }
}

class _SpaceDecorPainter extends CustomPainter {
  final double tick;
  const _SpaceDecorPainter({required this.tick});

  static const _bg = Color(0xFFFFFFFF);
  static const _gridLine = Color(0xFFB2E4F5);
  static const _mountainLight = Color(0xFFD6EEF8);
  static const _mountainDark = Color(0xFFB0D4E8);
  static const _moonBody = Color(0xFFE2E8F0);
  static const _moonCrater = Color(0xFFCBD5E1);
  static const _planetBody = Color(0xFF7DD3FC);
  static const _planetDark = Color(0xFF38BDF8);
  static const _star = Color(0xFF90CAF9);
  static const _starBright = Color(0xFF0EA5E9);
  static const _galaxyCore = Color(0xFFCBF0FF);

  void _splat(
    Canvas c,
    Paint p,
    double ox,
    double oy,
    double u,
    List<String> grid,
    Map<String, Color> palette,
  ) {
    for (int y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (int x = 0; x < row.length; x++) {
        final char = row[x];
        if (char == ' ') continue;
        final col = palette[char];
        if (col != null) {
          p.color = col;
          c.drawRect(Rect.fromLTWH(ox + x * u, oy + y * u, u, u), p);
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rand = math.Random(42);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    // ── 1. White background ──────────────────────────────────────────────────
    paint.color = _bg;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // ── 2. Twinkling stars ───────────────────────────────────────────────────
    final starRand = math.Random(77);
    for (int i = 0; i < 80; i++) {
      final sx = starRand.nextDouble() * w;
      final sy = starRand.nextDouble() * h * 0.7;
      final phase = starRand.nextDouble() * math.pi * 2;
      final blink =
          0.2 + 0.8 * ((math.sin(tick * math.pi * 2 + phase) + 1) / 2);

      if (i % 7 == 0) {
        // Cross star
        const size = 3.0;
        paint.color = _starBright.withValues(alpha: blink * 0.8);
        canvas.drawRect(
          Rect.fromLTWH(sx - size * 2, sy, size * 5, size),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(sx, sy - size * 2, size, size * 5),
          paint,
        );
      } else {
        paint.color = _star.withValues(alpha: blink * 0.6);
        final s = i % 3 == 0 ? 3.0 : 2.0;
        canvas.drawRect(Rect.fromLTWH(sx, sy, s, s), paint);
      }
    }

    // ── 3. Galaxy spiral ─────────────────────────────────────────────────────
    final cx = w * 0.52;
    final cy = h * 0.30;

    for (int i = 0; i < 2800; i++) {
      final r = math.sqrt(rand.nextDouble()) * (w * 0.56);
      final theta =
          r * 0.022 + rand.nextDouble() * 0.4 + (i % 2 == 0 ? 0 : math.pi);
      double ox = cx + r * math.cos(theta);
      double oy = cy + r * 0.42 * math.sin(theta);
      ox += (rand.nextDouble() - 0.5) * 14;
      oy += (rand.nextDouble() - 0.5) * 14;

      if (ox > 0 && ox < w && oy > 0 && oy < h * 0.65) {
        final opacity = 0.1 + rand.nextDouble() * 0.55;
        paint.color = _galaxyCore.withValues(alpha: opacity);
        final s = rand.nextDouble() > 0.92 ? 2.5 : 1.5;
        canvas.drawRect(Rect.fromLTWH(ox, oy, s, s), paint);
      }
    }
    // Bright galaxy core
    for (int i = 0; i < 200; i++) {
      final r = rand.nextDouble() * 14;
      final theta = rand.nextDouble() * math.pi * 2;
      final ox = cx + r * math.cos(theta);
      final oy = cy + r * 0.5 * math.sin(theta);
      paint.color = _starBright.withValues(
        alpha: 0.5 + rand.nextDouble() * 0.5,
      );
      canvas.drawRect(Rect.fromLTWH(ox, oy, 2, 2), paint);
    }

    // ── 4. Moon (top left) ──────────────────────────────────────────────────
    final moonMap = {'O': _moonBody, 'c': _moonCrater};
    final moonGrid = [
      "    OOOOOO    ",
      "  OOO OOOOOO  ",
      " OcOOOOOO OOO ",
      " OOOOOcOOOOOO ",
      "OOOOOOOOccOOOO",
      "OOOO OOOcccOOO",
      "OOOOOOOOccOOOO",
      "OOOOOOOOOOOOOO",
      " OOOOOOOOOO O ",
      " OOcOOcOOOOOO ",
      "  OOOOccOOOO  ",
      "    OOOOOO    ",
    ];
    _splat(canvas, paint, 18.0, 30.0, 4.5, moonGrid, moonMap);

    // ── 5. Planet (right middle) ─────────────────────────────────────────────
    final planetMap = {'P': _planetBody, 'R': _planetDark};
    final planetGrid = [
      "          RRRR     ",
      "      PPPPPRRRR    ",
      "    PPPPPPPPPRRR   ",
      "  RRRPPPPPPPPPPP   ",
      "RRRRRPPPPPPPPP     ",
      "RR    PPPPPPP      ",
      "       RRPPPP      ",
      "         PPP       ",
    ];
    _splat(canvas, paint, w * 0.62, h * 0.20, 4.0, planetGrid, planetMap);

    // ── 6. Retro grid (bottom half) ──────────────────────────────────────────
    final gridTop = h * 0.72;
    // Vanishing-point perspective grid
    for (int i = 0; i <= 12; i++) {
      final t = i / 12.0;
      // Horizontal lines — foreshortened
      final y = gridTop + (h - gridTop) * math.pow(t, 1.6);
      paint.color = _gridLine.withValues(alpha: 0.35 - t * 0.2);
      canvas.drawRect(Rect.fromLTWH(0, y, w, 1.5), paint);
    }
    // Vertical lines converging at horizon centre
    final vpX = w * 0.5;
    for (int i = -6; i <= 6; i++) {
      if (i == 0) continue;
      final t = i.abs() / 6.0;
      final bx = vpX + (w * 0.55) * (i / 6);
      paint.color = _gridLine.withValues(alpha: 0.30 - t * 0.12);
      // Draw as thin path from horizon to bottom
      final path = Path()
        ..moveTo(vpX, gridTop)
        ..lineTo(bx, h);
      canvas.drawPath(
        path,
        paint
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      paint.style = PaintingStyle.fill;
    }

    // ── 7. Mountain silhouette ───────────────────────────────────────────────
    final mtTop = h * 0.68;
    final mtPath = Path();
    mtPath.moveTo(0, h * 0.78);
    // Jagged pixel peaks using a seeded RNG
    final mRand = math.Random(13);
    double mx = 0;
    while (mx < w) {
      final peakH = mRand.nextDouble() * h * 0.12 + h * 0.02;
      final peakW = mRand.nextDouble() * 50 + 20;
      mtPath.lineTo(mx + peakW / 2, mtTop + (h * 0.10 - peakH));
      mtPath.lineTo(mx + peakW, h * 0.78);
      mx += peakW;
    }
    mtPath.lineTo(w, h * 0.78);
    mtPath.lineTo(w, h);
    mtPath.lineTo(0, h);
    mtPath.close();
    paint.color = _mountainDark.withValues(alpha: 0.35);
    canvas.drawPath(mtPath, paint);

    // Snow caps (lighter jagged tops)
    final snowPath = Path();
    snowPath.moveTo(0, h * 0.78);
    final sRand = math.Random(13);
    double smx = 0;
    while (smx < w) {
      final peakH = sRand.nextDouble() * h * 0.12 + h * 0.02;
      final peakW = sRand.nextDouble() * 50 + 20;
      final px = smx + peakW / 2;
      final py = mtTop + (h * 0.10 - peakH);
      snowPath.lineTo(px - 5, py + 14);
      snowPath.lineTo(px, py);
      snowPath.lineTo(px + 5, py + 14);
      smx += peakW;
    }
    snowPath.lineTo(w, h * 0.78);
    paint.color = _mountainLight.withValues(alpha: 0.5);
    canvas.drawPath(
      snowPath,
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    paint.style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(_SpaceDecorPainter old) => old.tick != tick;
}

// ─────────────────────────────────────────────────────────────────────────────
// Standalone Satellite widget (used by _FallingSatellite)
// ─────────────────────────────────────────────────────────────────────────────

class ZeroSatellite extends StatelessWidget {
  final double scale;
  const ZeroSatellite({super.key, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60 * scale,
      height: 52 * scale,
      child: CustomPaint(painter: _SatellitePainter()),
    );
  }
}

class _SatellitePainter extends CustomPainter {
  static const _satBody = Color(0xFF94A3B8);
  static const _satPanel = Color(0xFF38BDF8);
  static const _satDark = Color(0xFF0F172A);
  static const _satWhite = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    final satMap = {
      'S': _satBody,
      'P': _satPanel,
      'x': _satDark,
      'w': _satWhite,
    };
    final satGrid = [
      "          PP   ",
      "        PPxxP  ",
      "      PPxxPP   ",
      "    PPxxPP     ",
      "  SSxxPP       ",
      "  SSwS         ",
      " SxSwwS        ",
      "  SSxS  PP     ",
      "       PxxPP   ",
      "     PPxxPP    ",
      "   PPxxPP      ",
      "   PP          ",
    ];

    double u = size.width / 15;
    for (int y = 0; y < satGrid.length; y++) {
      final row = satGrid[y];
      for (int x = 0; x < row.length; x++) {
        final char = row[x];
        if (char == ' ') continue;
        final col = satMap[char];
        if (col != null) {
          paint.color = col;
          canvas.drawRect(Rect.fromLTWH(x * u, y * u, u, u), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Terminal Comet (for Code workspace terminal panel)
// ─────────────────────────────────────────────────────────────────────────────

class ZeroCometIcon extends StatefulWidget {
  const ZeroCometIcon({super.key});

  @override
  State<ZeroCometIcon> createState() => _ZeroCometIconState();
}

class _ZeroCometIconState extends State<ZeroCometIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
      builder: (_, __) => SizedBox(
        width: 88,
        height: 80,
        child: CustomPaint(painter: _CometPainter(tick: _ctrl.value)),
      ),
    );
  }
}

class _CometPainter extends CustomPainter {
  final double tick;
  const _CometPainter({required this.tick});

  static const _core = Color(0xFF0F172A);
  static const _crust = Color(0xFF38BDF8);
  static const _tailBase = Color(0xFF0EA5E9);
  static const _tailEnd = Color(0xFF0284C7);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final cometMap = {'C': _core, '#': _crust, 'B': _tailBase, 'E': _tailEnd};
    final grid = [
      "                      C",
      "                     CC",
      "                   #CC#",
      "                B ##C# ",
      "             BB B ###  ",
      "          EB BB B#     ",
      "       EEE  BB         ",
      "    EEE  EE            ",
      " E E                   ",
    ];

    const double u = 4.0;
    // Animate a glow pulse on the tail
    final glowPulse = (math.sin(tick * math.pi * 2) + 1) / 2;

    for (int y = 0; y < grid.length; y++) {
      final row = grid[y];
      for (int x = 0; x < row.length; x++) {
        final char = row[x];
        if (char == ' ') continue;
        final col = cometMap[char];
        if (col != null) {
          double opacity;
          if (char == 'E') {
            opacity = 0.15 + glowPulse * 0.45;
          } else if (char == 'B') {
            opacity = 0.5 + glowPulse * 0.35;
          } else {
            opacity = 1.0;
          }
          paint.color = col.withValues(alpha: opacity);
          canvas.drawRect(Rect.fromLTWH(x * u, y * u, u, u), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CometPainter old) => old.tick != tick;
}
