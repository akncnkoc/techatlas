import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../pdf_thumbnail.dart';

class ThumbnailPanel extends StatelessWidget {
  final PdfController pdfController;
  final int currentPage;
  final VoidCallback onClose;

  const ThumbnailPanel({
    super.key,
    required this.pdfController,
    required this.currentPage,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag Handle - Aşağı swipe ile kapatma
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (details) {
            // Aşağı doğru hızlı swipe kontrolü
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 500) {
              onClose();
            }
          },
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        // Thumbnail List
        PdfThumbnailList(
          pdfController: pdfController,
          currentPage: currentPage,
          totalPages: pdfController.pagesCount ?? 0,
          onPageSelected: (pageNumber) {
            pdfController.jumpToPage(pageNumber);
          },
        ),
      ],
    );
  }
}
