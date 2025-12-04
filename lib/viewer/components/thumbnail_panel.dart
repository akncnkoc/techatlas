import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/extensions/pdf_viewer_controller_extensions.dart';
import '../pdf_thumbnail.dart';

class ThumbnailPanel extends StatelessWidget {
  final PdfViewerController pdfController;
  final Future<PdfDocument> pdfDocument;
  final int currentPage;
  final VoidCallback onClose;

  const ThumbnailPanel({
    super.key,
    required this.pdfController,
    required this.pdfDocument,
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
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Icon(
                Icons.swipe_down_rounded,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        // Thumbnail List
        PdfThumbnailList(
          pdfController: pdfController,
          pdfDocument: pdfDocument,
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
