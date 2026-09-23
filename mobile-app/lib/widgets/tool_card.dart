import 'package:flutter/material.dart';
import '../theme/zero_theme.dart';

class ToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isActive;
  final VoidCallback? onToggle;

  const ToolCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isActive = true,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark 
        ? Colors.black.withValues(alpha: 0.2) 
        : Colors.black.withValues(alpha: 0.03);
    final borderColor = isActive ? ZeroTheme.accent.withValues(alpha: 0.3) : ZeroTheme.ink.withValues(alpha: 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Wrap content instead of taking full width
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive
                  ? ZeroTheme.accent.withValues(alpha: 0.1)
                  : ZeroTheme.ink.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isActive ? ZeroTheme.accent : ZeroTheme.muted,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : ZeroTheme.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ZeroTheme.muted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (onToggle != null)
            Transform.scale(
              scale: 0.7, // Make switch smaller
              child: Switch(
                value: isActive,
                onChanged: (val) => onToggle!(),
                activeTrackColor: ZeroTheme.accent,
                activeThumbColor: ZeroTheme.white,
              ),
            ),
        ],
      ),
    );
  }
}
