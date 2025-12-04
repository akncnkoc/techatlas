import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/extensions/pdf_viewer_controller_extensions.dart';
import '../pdf_thumbnail.dart';

class RightThumbnailSidebar extends StatelessWidget {
  final PdfViewerController pdfController;
  final Future<PdfDocument> pdfDocument;
  final int currentPage;
  final VoidCallback onClose;

  const RightThumbnailSidebar({
    super.key,
    required this.pdfController,
    required this.pdfDocument,
    required this.currentPage,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        bottomLeft: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 160, // Increased width for better spacing
          height: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.85),
            border: Border(
              left: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with Close Button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sayfalar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: onClose,
                      tooltip: 'Kapat',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        foregroundColor: scheme.onSurfaceVariant,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(36, 36),
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical Thumbnail List
              Expanded(
                child: PdfThumbnailList(
                  pdfController: pdfController,
                  pdfDocument: pdfDocument,
                  currentPage: currentPage,
                  totalPages: pdfController.pagesCount ?? 0,
                  scrollDirection: Axis.vertical,
                  onPageSelected: (pageNumber) {
                    pdfController.jumpToPage(pageNumber);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
