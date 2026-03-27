import 'package:flutter/material.dart';
import 'split_flap_row.dart';

/// A display row that contains multiple split-flap units.
/// Refactored to use [SplitFlapRow] (CustomPainter) for high performance.
class SplitFlapDisplay extends StatelessWidget {
  final String text;
  final int maxLength;
  final double unitWidth;
  final double unitHeight;
  final Color? flapColor;
  final Color? textColor;

  const SplitFlapDisplay({
    super.key,
    required this.text,
    required this.maxLength,
    required this.unitWidth,
    required this.unitHeight,
    this.flapColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SplitFlapRow(
      text: text,
      maxLength: maxLength,
      unitWidth: unitWidth,
      unitHeight: unitHeight,
      flapColor: flapColor ?? const Color(0xFF1E1E1E),
      textColor: textColor ?? Colors.white,
    );
  }
}
