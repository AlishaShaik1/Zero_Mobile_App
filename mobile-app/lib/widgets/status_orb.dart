import 'package:flutter/material.dart';

enum OrbState { idle, thinking, searching, executing, listening }

class StatusOrb extends StatefulWidget {
  final OrbState state;
  final double size;

  const StatusOrb({super.key, required this.state, this.size = 14.0});

  @override
  State<StatusOrb> createState() => _StatusOrbState();
}

class _StatusOrbState extends State<StatusOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColorForState(OrbState state) {
    switch (state) {
      case OrbState.idle:
        return const Color(0xFF22C55E); // Green
      case OrbState.thinking:
        return const Color(0xFFA855F7); // Purple
      case OrbState.searching:
        return const Color(0xFF06B6D4); // Cyan
      case OrbState.executing:
        return const Color(0xFFF97316); // Orange
      case OrbState.listening:
        return const Color(0xFF3B82F6); // Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForState(widget.state);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale =
            0.8 + (_controller.value * 0.4); // Pulses between 0.8 and 1.2
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 2 * _controller.value,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
