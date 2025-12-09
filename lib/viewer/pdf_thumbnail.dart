import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/crop_data.dart';

// Global thumbnail cache - PDF ID ve sayfa numarasına göre cache tutar
class ThumbnailCache {
  static final Map<String, Map<int, ui.Image>> _cache = {};

  static String _getCacheKey(PdfViewerController controller) {
    return controller.hashCode.toString();
  }

  static ui.Image? get(PdfViewerController controller, int pageNumber) {
    final key = _getCacheKey(controller);
    return _cache[key]?[pageNumber];
  }

  static void put(
    PdfViewerController controller,
    int pageNumber,
    ui.Image image,
  ) {
    final key = _getCacheKey(controller);
    _cache[key] ??= {};
    _cache[key]![pageNumber] = image;
  }

  static void clear() {
    _cache.clear();
  }

  static void clearForController(PdfViewerController controller) {
    final key = _getCacheKey(controller);
    _cache.remove(key);
  }
}

class PdfThumbnailList extends StatefulWidget {
  final PdfViewerController pdfController;
  final Future<PdfDocument> pdfDocument;
  final int currentPage;
  final int totalPages;
  final Function(int) onPageSelected;
  final Axis scrollDirection;
  final CropData? cropData;

  const PdfThumbnailList({
    super.key,
    required this.pdfController,
    required this.pdfDocument,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
    this.scrollDirection = Axis.horizontal,
    this.cropData,
  });

  @override
  State<PdfThumbnailList> createState() => _PdfThumbnailListState();
}

class _PdfThumbnailListState extends State<PdfThumbnailList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PdfThumbnailList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _scrollToCurrentPage();
    }
  }

  @override
  void initState() {
    super.initState();
    // İlk açılışta da ortala
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentPage();
    });
  }

  void _scrollToCurrentPage() {
    if (!_scrollController.hasClients) return;

    // Determine thumbnail size and padding based on scroll direction
    final bool isVertical = widget.scrollDirection == Axis.vertical;
    final double thumbnailSize = isVertical ? 140.0 : 106.0; // 90 + 16 margin
    final double padding = isVertical ? 12.0 : 8.0;

    // Calculate the target position of the item's center
    final double itemStart = padding + (widget.currentPage - 1) * thumbnailSize;
    final double itemCenter = itemStart + (thumbnailSize / 2);

    // Calculate screen center
    final double viewportDimension =
        _scrollController.position.viewportDimension;
    final double screenCenter = viewportDimension / 2;

    // Calculate the scroll position to center the item
    final double targetScrollPosition = itemCenter - screenCenter;

    // Clamp the scroll position
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double minScroll = _scrollController.position.minScrollExtent;
    final double finalPosition = targetScrollPosition.clamp(
      minScroll,
      maxScroll,
    );

    _scrollController.animateTo(
      finalPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (_scrollController.hasClients) {
              final offset = _scrollController.offset + event.scrollDelta.dy;
              final maxScroll = _scrollController.position.maxScrollExtent;
              final minScroll = _scrollController.position.minScrollExtent;

              _scrollController.jumpTo(offset.clamp(minScroll, maxScroll));
            }
          }
        },
        child: Container(
          // Height is only relevant for horizontal scrolling
          height: widget.scrollDirection == Axis.horizontal ? 140 : null,
          width: widget.scrollDirection == Axis.vertical ? 120 : null,
          decoration: widget.scrollDirection == Axis.horizontal
              ? BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                )
              : null,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: widget.scrollDirection,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            itemCount: widget.totalPages,
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              final thumbnail = PdfThumbnail(
                controller: widget.pdfController,
                pdfDocument: widget.pdfDocument,
                pageNumber: pageNumber,
                isCurrentPage: pageNumber == widget.currentPage,
                onTap: () => widget.onPageSelected(pageNumber),
                cropData: widget.cropData,
              );

              if (widget.scrollDirection == Axis.vertical) {
                return SizedBox(height: 140, child: thumbnail);
              }
              return thumbnail;
            },
          ),
        ),
      ),
    );
  }
}

// PdfThumbnail widget'ı buraya eklenecek
class PdfThumbnail extends StatefulWidget {
  final PdfViewerController controller;
  final Future<PdfDocument> pdfDocument;
  final int pageNumber;
  final bool isCurrentPage;
  final VoidCallback onTap;

  const PdfThumbnail({
    super.key,
    required this.controller,
    required this.pdfDocument,
    required this.pageNumber,
    required this.isCurrentPage,
    required this.onTap,
    this.cropData,
  });

  final CropData? cropData;

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  ui.Image? _cachedImage;
  bool _isLoading = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    // Önce global cache'e bak
    final cachedImage = ThumbnailCache.get(
      widget.controller,
      widget.pageNumber,
    );
    if (cachedImage != null) {
      if (mounted) {
        setState(() {
          _cachedImage = cachedImage;
          _isLoading = false;
        });
      }
      return;
    }

    // Eğer cache'te yoksa ve şu an yükleniyorsa tekrar yükleme
    if (_cachedImage != null || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      // pdfrx: Use pdfDocument pages
      final document = await widget.pdfDocument;
      if (widget.pageNumber < 1 || widget.pageNumber > document.pages.length) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }
      final page = document.pages[widget.pageNumber - 1]; // Pages are 0-indexed

      // pdfrx: Render the page to get image
      final pageImage = await page.render(
        width: (page.width * 2.0).round(),
        height: (page.height * 2.0).round(),
        fullWidth: (page.width * 2.0).round().toDouble(),
        fullHeight: (page.height * 2.0).round().toDouble(),
      );

      if (pageImage != null) {
        final image = await pageImage.createImage();

        ThumbnailCache.put(widget.controller, widget.pageNumber, image);

        if (mounted) {
          setState(() {
            _cachedImage = image;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading thumbnail for page ${widget.pageNumber}: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = widget.isCurrentPage;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 90,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : _isHovering
                  ? colorScheme.outline
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected || _isHovering
                ? [
                    BoxShadow(
                      color: isSelected
                          ? colorScheme.primary.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: isSelected ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    child: _cachedImage != null
                        ? RawImage(image: _cachedImage, fit: BoxFit.cover)
                        : Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  colorScheme.primary.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Text(
                    _getLabel(),
                    style: TextStyle(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLabel() {
    if (widget.cropData == null) return '${widget.pageNumber}';

    final crops = widget.cropData!.getCropsForPage(widget.pageNumber);
    if (crops.isEmpty) return '${widget.pageNumber}';

    // Find first crop with question number
    final questionCrop = crops.firstWhere(
      (c) => c.questionNumber != null,
      orElse: () => crops.first,
    );

    if (questionCrop.questionNumber != null) {
      return '${questionCrop.questionNumber}';
    }

    return '${widget.pageNumber}';
  }
}
