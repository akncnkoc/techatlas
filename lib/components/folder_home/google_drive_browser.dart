import 'package:flutter/material.dart';
import '../../google_drive/models.dart' as gdrive;
import '../../models/app_models.dart'; // For BreadcrumbItem
import '../../models/downloaded_book.dart';

class GoogleDriveBrowser extends StatelessWidget {
  final List<gdrive.DriveItem> items;
  final List<BreadcrumbItem> breadcrumbs;
  final Function(String id, String name) onFolderTap;
  final Function(gdrive.DriveItem item) onBookTap;
  final Function(int index) onBreadcrumbTap;
  final VoidCallback onRefresh;
  final Set<String> downloadingBooks;
  final Map<String, double> downloadProgress;
  final Function(gdrive.DriveItem item) onDownloadTap;
  final Function(String id) onCancelDownload;
  final List<DownloadedBook> downloadedBooks;

  const GoogleDriveBrowser({
    Key? key,
    required this.items,
    required this.breadcrumbs,
    required this.onFolderTap,
    required this.onBookTap,
    required this.onBreadcrumbTap,
    required this.onRefresh,
    required this.downloadingBooks,
    required this.downloadProgress,
    required this.onDownloadTap,
    required this.onCancelDownload,
    required this.downloadedBooks,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDriveBreadcrumbs(context),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.tertiaryContainer,
                      Theme.of(
                        context,
                      ).colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_off_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Bu klasör boş',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Klasör veya .book dosyası bulunamadı',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Yenile',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isFolder = item.isFolder;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              if (isFolder) {
                onFolderTap(item.id, item.name);
              } else {
                onBookTap(item);
              }
            },
            child: Card(
              elevation: 2,
              shadowColor: isFolder
                  ? Theme.of(
                      context,
                    ).colorScheme.tertiary.withValues(alpha: 0.15)
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                          Theme.of(context).colorScheme.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Icon container with gradient
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isFolder
                                    ? [
                                        Theme.of(context).colorScheme.tertiary
                                            .withValues(alpha: 0.1),
                                        Theme.of(context).colorScheme.tertiary
                                            .withValues(alpha: 0.05),
                                      ]
                                    : [
                                        Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.1),
                                        Theme.of(context).colorScheme.secondary
                                            .withValues(alpha: 0.05),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(14),
                                topRight: Radius.circular(14),
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Main icon (folder or book)
                                Center(
                                  child: item.thumbnailLink != null
                                      ? ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(14),
                                              ),
                                          child: Image.network(
                                            item.thumbnailLink!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Icon(
                                                    isFolder
                                                        ? Icons.folder_rounded
                                                        : Icons
                                                              .menu_book_rounded,
                                                    size: 40,
                                                    color: isFolder
                                                        ? Theme.of(
                                                            context,
                                                          ).colorScheme.tertiary
                                                        : Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                  );
                                                },
                                          ),
                                        )
                                      : Icon(
                                          isFolder
                                              ? Icons.folder_rounded
                                              : Icons.menu_book_rounded,
                                          size: 40,
                                          color: isFolder
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.tertiary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                        ),
                                ),
                                // Small badge
                                if (!isFolder)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .secondary
                                                .withValues(alpha: 0.3),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.cloud_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Item name and actions
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          width: double.infinity,
                          child: Column(
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  letterSpacing: -0.2,
                                  height: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                              ),
                              if (!isFolder) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 28,
                                  width: double.infinity,
                                  child:
                                      downloadedBooks.any(
                                        (b) => b.id == item.id,
                                      )
                                      ? FilledButton.icon(
                                          onPressed:
                                              null, // Disabled if downloaded
                                          icon: const Icon(
                                            Icons.check_rounded,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'İndirildi',
                                            style: TextStyle(fontSize: 10),
                                          ),
                                          style: FilledButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            backgroundColor: Colors.green,
                                            disabledBackgroundColor: Colors
                                                .green
                                                .withValues(alpha: 0.5),
                                            disabledForegroundColor:
                                                Colors.white,
                                          ),
                                        )
                                      : OutlinedButton.icon(
                                          onPressed: () => onDownloadTap(item),
                                          icon: const Icon(
                                            Icons.download_rounded,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'İndir',
                                            style: TextStyle(fontSize: 10),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            side: BorderSide(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Download progress overlay
                  if (!isFolder && downloadingBooks.contains(item.id))
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                value: downloadProgress[item.id] ?? 0.0,
                                strokeWidth: 4,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '%${((downloadProgress[item.id] ?? 0.0) * 100).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'İndiriliyor...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Cancel button
                            OutlinedButton.icon(
                              onPressed: () => onCancelDownload(item.id),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('İptal'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
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
        );
      },
    );
  }

  Widget _buildDriveBreadcrumbs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.cloud_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < breadcrumbs.length; i++) ...[
                    InkWell(
                      onTap: () => onBreadcrumbTap(i),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: i == breadcrumbs.length - 1
                            ? BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.secondary
                                        .withValues(alpha: 0.12),
                                    Theme.of(context).colorScheme.secondary
                                        .withValues(alpha: 0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Text(
                          breadcrumbs[i].name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i == breadcrumbs.length - 1
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == breadcrumbs.length - 1
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    if (i < breadcrumbs.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
