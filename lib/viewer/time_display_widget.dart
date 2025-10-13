import 'package:flutter/material.dart';
import 'page_time_tracker.dart';

/// Mevcut sayfadaki süreyi gösteren floating widget
class TimeDisplayWidget extends StatelessWidget {
  final ValueNotifier<String> timeNotifier;
  final VoidCallback? onTap;

  const TimeDisplayWidget({super.key, required this.timeNotifier, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<String>(
      valueListenable: timeNotifier,
      builder: (context, timeText, child) {
        return Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: scheme.surface,
          shadowColor: Colors.black.withOpacity(0.2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tüm sayfa sürelerini gösteren detaylı dialog
class TimeStatisticsDialog extends StatelessWidget {
  final PageTimeTracker timeTracker;
  final int currentPage;

  const TimeStatisticsDialog({
    super.key,
    required this.timeTracker,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allPageData = timeTracker.getAllPageData();
    final sortedPages = allPageData.keys.toList()..sort();
    final totalDuration = timeTracker.getTotalDuration();

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: scheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Zaman İstatistikleri',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Total time card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: scheme.primary, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toplam Süre',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(totalDuration),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Page list header
            Text(
              'Sayfa Detayları',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Page list
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: sortedPages.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz veri yok',
                          style: TextStyle(
                            color: scheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: sortedPages.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: scheme.outlineVariant.withOpacity(0.5),
                        ),
                        itemBuilder: (context, index) {
                          final pageNum = sortedPages[index];
                          final pageData = allPageData[pageNum]!;
                          final isCurrentPage = pageNum == currentPage;
                          final percentage = totalDuration.inSeconds > 0
                              ? (pageData.currentTotalDuration.inSeconds /
                                        totalDuration.inSeconds) *
                                    100
                              : 0.0;

                          return Container(
                            color: isCurrentPage
                                ? scheme.primaryContainer.withOpacity(0.2)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                // Page number
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isCurrentPage
                                        ? scheme.primary
                                        : scheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$pageNum',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isCurrentPage
                                            ? scheme.onPrimary
                                            : scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Progress bar and time
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Sayfa $pageNum',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            pageData.formatDuration(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: scheme.primary,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Progress bar
                                      Stack(
                                        children: [
                                          Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: scheme
                                                  .surfaceContainerHighest,
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: percentage / 100,
                                            child: Container(
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: scheme.primary,
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${percentage.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurface.withOpacity(
                                            0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Close button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}s ${minutes}d ${seconds}sn';
    } else if (minutes > 0) {
      return '${minutes}d ${seconds}sn';
    } else {
      return '${seconds}sn';
    }
  }
}
