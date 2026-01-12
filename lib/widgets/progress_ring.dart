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

  Color _getColor() {
    if (percentage == 0) return Colors.grey;
    if (percentage < 33) return Colors.orange;
    if (percentage < 66) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    // Scale font based on ring size
    final fontSize = size < 60 ? size * 0.28 : size * 0.23;
    final strokeWidth = size < 60 ? 4.0 : 6.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: strokeWidth,
              backgroundColor: Theme.of(context).colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(_getColor()),
            ),
          ),
          if (size >= 50)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percentage.toInt()}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
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
