import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// Page navigation buttons component
class PageNavigationButtons extends StatelessWidget {
  final PdfController controller;
  final bool isCompact;

  const PageNavigationButtons({
    super.key,
    required this.controller,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _CompactNavigation(controller: controller);
    }
    return _FullNavigation(controller: controller);
  }
}

class _FullNavigation extends StatelessWidget {
  final PdfController controller;

  const _FullNavigation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Sayfa Navigasyonu',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _NavButton(
              icon: Icons.first_page,
              tooltip: 'İlk Sayfa',
              onPressed: () => controller.jumpToPage(1),
            ),
            _NavButton(
              icon: Icons.chevron_left,
              tooltip: 'Önceki Sayfa',
              onPressed: () => controller.previousPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeIn,
              ),
            ),
            _NavButton(
              icon: Icons.chevron_right,
              tooltip: 'Sonraki Sayfa',
              onPressed: () => controller.nextPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeIn,
              ),
            ),
            _NavButton(
              icon: Icons.last_page,
              tooltip: 'Son Sayfa',
              onPressed: () => controller.jumpToPage(
                controller.pagesCount ?? 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactNavigation extends StatelessWidget {
  final PdfController controller;

  const _CompactNavigation({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.first_page, size: 18),
          onPressed: () => controller.jumpToPage(1),
          tooltip: 'İlk sayfa',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: () => controller.previousPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeIn,
          ),
          tooltip: 'Önceki sayfa',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 18),
          onPressed: () => controller.nextPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeIn,
          ),
          tooltip: 'Sonraki sayfa',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
        IconButton(
          icon: const Icon(Icons.last_page, size: 18),
          onPressed: () => controller.jumpToPage(
            controller.pagesCount ?? 1,
          ),
          tooltip: 'Son sayfa',
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 24,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
    );
  }
}
