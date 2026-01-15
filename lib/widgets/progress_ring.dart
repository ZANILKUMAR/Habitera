import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  final double percentage;
  final double size;
  final String? label;

  const ProgressRing({
    super.key,
    required this.percentage,
    this.size = 120,
    this.label,
  });

  Color _getColor(bool isDark) {
    if (percentage == 0) {
      // Return transparent when empty - the base ring handles the visual
      return isDark ? Colors.grey.shade700 : Colors.grey.shade400;
    }
    if (percentage < 33) return Colors.orange;
    if (percentage < 66) return Colors.amber;
    return Colors.green;
  }

  Color _getBaseRingColor(bool isDark) {
    // Soft, neutral base ring color that's visible but subtle
    return isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Scale font based on ring size
    final fontSize = size < 60 ? size * 0.28 : size * 0.23;
    final strokeWidth = size < 60 ? 4.0 : 6.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base ring - always visible as a subtle background
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1.0, // Full circle for the base
              strokeWidth: strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(_getBaseRingColor(isDark)),
            ),
          ),
          // Progress ring - animates from 0 to percentage
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percentage / 100),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(_getColor(isDark)),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          if (size >= 50)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: percentage),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      '${value.toInt()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: fontSize,
                            fontWeight: FontWeight.w600,
                          ),
                    );
                  },
                ),
                if (label != null && size >= 80)
                  Text(
                    label!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: size * 0.1,
                        ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
