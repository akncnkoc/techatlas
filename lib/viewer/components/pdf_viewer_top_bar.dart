import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/extensions/pdf_viewer_controller_extensions.dart';
import '../page_time_tracker.dart';
import '../time_display_widget.dart';

class PdfViewerTopBar extends StatelessWidget {
  final String pdfPath;
  final PdfViewerController pdfController;
  final int currentPage;
  final bool showThumbnails;
  final VoidCallback onToggleThumbnails;
  final double zoomLevel;
  final PageTimeTracker timeTracker;
  final String currentPageTime;
  final VoidCallback? onBack;
  final VoidCallback? onGoToPage;

  const PdfViewerTopBar({
    super.key,
    required this.pdfPath,
    required this.pdfController,
    required this.currentPage,
    required this.showThumbnails,
    required this.onToggleThumbnails,
    required this.zoomLevel,
    required this.timeTracker,
    required this.currentPageTime,
    this.onBack,
    this.onGoToPage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            width: 1.5,
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // PDF İkonu
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              Icons.picture_as_pdf_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Spacer(flex: 1),

          // Sayfa Bilgisi (Tıklanabilir - Thumbnail Toggle)
          InkWell(
            onTap: onToggleThumbnails,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: showThumbnails
                    ? LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      )
                    : null,
                color: showThumbnails
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                boxShadow: showThumbnails
                    ? [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showThumbnails ? Icons.grid_view : Icons.description,
                    size: 14,
                    color: showThumbnails
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sayfa $currentPage / ${pdfController.pagesCount ?? 0}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: showThumbnails
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    showThumbnails ? Icons.expand_more : Icons.chevron_right,
                    size: 16,
                    color: showThumbnails
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Sayfaya Git Butonu
          if (onGoToPage != null)
            Tooltip(
              message: 'Sayfaya Git',
              child: InkWell(
                onTap: onGoToPage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.numbers,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Git',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (onGoToPage != null) const SizedBox(width: 12),

          // Zoom Seviyesi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.zoom_in,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  '${(zoomLevel * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => TimeStatisticsDialog(
                  timeTracker: timeTracker,
                  currentPage: currentPage,
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatTimeDisplay(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Geri Butonu
          if (onBack != null)
            Tooltip(
              message: 'Kapat',
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade400.withValues(alpha: 0.15),
                        Colors.red.shade600.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimeDisplay() {
    final totalDuration = timeTracker.getTotalDuration();
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);
    final seconds = totalDuration.inSeconds.remainder(60);

    String totalTimeText;
    if (hours > 0) {
      totalTimeText = '${hours}s ${minutes}d ${seconds}sn';
    } else if (minutes > 0) {
      totalTimeText = '${minutes}d ${seconds}sn';
    } else {
      totalTimeText = '${seconds}sn';
    }

    return 'Total: $totalTimeText / Sayfa: $currentPageTime';
  }
}
