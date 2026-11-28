import 'package:flutter/material.dart';

/// Compact, horizontally scrollable selection with visible scroll affordance.
class HorizontalChoiceStrip extends StatelessWidget {
  const HorizontalChoiceStrip({
    super.key,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 8,
  });
  final List<Widget> children;
  final double spacing, runSpacing;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          children[i],
        ],
      ],
    ),
  );
}
