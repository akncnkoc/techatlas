import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import '../page_time_tracker.dart';
import '../time_display_widget.dart';

class PdfViewerTopBar extends StatelessWidget {
  final String pdfPath;
  final PdfController pdfController;
  final bool showThumbnails;
  final VoidCallback onToggleThumbnails;
  final double zoomLevel;
  final PageTimeTracker timeTracker;
  final String currentPageTime;
  final VoidCallback? onBack;

  const PdfViewerTopBar({
    super.key,
    required this.pdfPath,
    required this.pdfController,
    required this.showThumbnails,
    required this.onToggleThumbnails,
    required this.zoomLevel,
    required this.timeTracker,
    required this.currentPageTime,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // PDF İkonu ve Başlık
          Icon(
            Icons.picture_as_pdf,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pdfPath.split('/').last,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Sayfa Bilgisi (Tıklanabilir - Thumbnail Toggle)
          ValueListenableBuilder<int>(
            valueListenable: pdfController.pageListenable,
            builder: (context, currentPage, child) {
              return InkWell(
                onTap: onToggleThumbnails,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: showThumbnails
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        showThumbnails ? Icons.grid_view : Icons.description,
                        size: 16,
                        color: showThumbnails
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sayfa $currentPage / ${pdfController.pagesCount ?? 0}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: showThumbnails
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        showThumbnails ? Icons.expand_more : Icons.chevron_right,
                        size: 18,
                        color: showThumbnails
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: 16),

          // Zoom Seviyesi
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.zoom_in, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${(zoomLevel * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Zaman Göstergesi
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => TimeStatisticsDialog(
                  timeTracker: timeTracker,
                  currentPage: pdfController.pageListenable.value,
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimeDisplay(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Geri Butonu
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onBack,
              tooltip: 'Kapat',
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
