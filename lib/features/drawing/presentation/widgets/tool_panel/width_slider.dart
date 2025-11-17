import 'package:flutter/material.dart';

/// Stroke width slider component
class WidthSlider extends StatelessWidget {
  final double width;
  final double min;
  final double max;
  final Function(double) onChanged;
  final String label;

  const WidthSlider({
    super.key,
    required this.width,
    required this.onChanged,
    this.min = 1.0,
    this.max = 20.0,
    this.label = 'Kalınlık',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                width.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: width.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) * 2).toInt().clamp(1, 100),
            onChanged: onChanged,
          ),
        ),
        // Visual preview of the stroke width
        Center(
          child: Container(
            width: double.infinity,
            height: width.clamp(2, 20),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(width / 2),
            ),
          ),
        ),
      ],
    );
  }
}
