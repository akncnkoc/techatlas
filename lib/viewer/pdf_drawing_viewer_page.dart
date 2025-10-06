import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'pdf_utils.dart';
import 'pdf_viewer_with_drawing.dart';
import 'left_panel.dart';
import 'pdf_thumbnail.dart';

class PdfDrawingViewerPage extends StatefulWidget {
  final String pdfPath;
  final VoidCallback? onBack;
  const PdfDrawingViewerPage({super.key, required this.pdfPath, this.onBack});

  @override
  State<PdfDrawingViewerPage> createState() => _PdfDrawingViewerPageState();
}

class _PdfDrawingViewerPageState extends State<PdfDrawingViewerPage> {
  PdfController? pdfController;
  final GlobalKey<PdfViewerWithDrawingState> drawingKey =
      GlobalKey<PdfViewerWithDrawingState>();

  // Draggable panel position
  double panelLeft = 100;
  double panelTop = 100;

  // Thumbnail panel visibility
  bool _showThumbnails = false;

  @override
  void initState() {
    super.initState();
    _loadControllerFor(widget.pdfPath);
  }

  Future<void> _loadControllerFor(String pdfPath) async {
    final realPath = await resolvePdfPath(pdfPath);
    if (!mounted) return;
    setState(() {
      pdfController = PdfController(document: PdfDocument.openFile(realPath));
    });
  }

  @override
  void didUpdateWidget(covariant PdfDrawingViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pdfPath != widget.pdfPath) {
      pdfController?.dispose();
      pdfController = null;
      setState(() {});
      _loadControllerFor(widget.pdfPath);
    }
  }

  @override
  void dispose() {
    pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (pdfController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screenSize = MediaQuery.of(context).size;

    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.onBack != null) {
          widget.onBack!();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.pdfPath.split('/').last,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Geri',
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _showThumbnails ? Icons.visibility_off_rounded : Icons.grid_view_rounded,
              ),
              tooltip: _showThumbnails ? 'Sayfaları Gizle' : 'Sayfaları Göster',
              onPressed: () {
                setState(() {
                  _showThumbnails = !_showThumbnails;
                });
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            // PDF viewer fills the stack
            Positioned.fill(
              child: PdfViewerWithDrawing(
                key: drawingKey,
                controller: pdfController!,
              ),
            ),

            // Bottom page thumbnails (animated show/hide)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 0,
              right: 0,
              bottom: _showThumbnails ? 0 : -140,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: pdfController!.pageListenable,
                  builder: (context, currentPage, _) {
                    final pageCount = pdfController!.pagesCount ?? 1;
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      itemCount: pageCount,
                      itemBuilder: (context, index) {
                        final pageNumber = index + 1;
                        final isCurrentPage = pageNumber == currentPage;

                        return PdfThumbnail(
                          key: ValueKey(pageNumber),
                          controller: pdfController!,
                          pageNumber: pageNumber,
                          isCurrentPage: isCurrentPage,
                          onTap: () => pdfController!.jumpToPage(pageNumber),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Draggable LeftPanel
            Positioned(
              left: panelLeft,
              top: panelTop,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Draggable handle
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          panelLeft += details.delta.dx;
                          panelTop += details.delta.dy;

                          // Approximate panel size for boundaries
                          const panelWidth = 320.0;
                          const panelHeight = 520.0;

                          // Clamp to screen bounds
                          panelLeft = panelLeft.clamp(
                            0.0,
                            screenSize.width - panelWidth,
                          );
                          panelTop = panelTop.clamp(
                            0.0,
                            screenSize.height - panelHeight,
                          );
                        });
                      },
                      child: Container(
                        width: 320,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Çizim Araçları',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Panel content with fixed height
                    SizedBox(
                      width: 320,
                      height: 472,
                      child: LeftPanel(
                        controller: pdfController!,
                        drawingKey: drawingKey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
