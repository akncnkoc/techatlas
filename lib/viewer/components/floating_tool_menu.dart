import 'package:flutter/material.dart';

class FloatingToolMenu extends StatelessWidget {
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenScratchpad;

  const FloatingToolMenu({
    super.key,
    required this.onOpenCalculator,
    required this.onOpenScratchpad,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          child: Container(
            width: 160,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onOpenCalculator,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.15),
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.calculate_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Hesap Makinesi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
                InkWell(
                  onTap: onOpenScratchpad,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.15),
                                Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.edit_note_rounded,
                            color: Theme.of(context).colorScheme.secondary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Not Defteri',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
