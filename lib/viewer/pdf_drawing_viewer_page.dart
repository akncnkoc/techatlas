import 'package:flutter/gestures.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../core/extensions/pdf_viewer_controller_extensions.dart';
import 'pdf_viewer_with_drawing.dart';
import 'widgets/vertical_tool_sidebar.dart';
import '../soru_cozucu_service.dart';
import 'calculator_widget.dart';
import 'scratchpad_widget.dart';
import '../models/crop_data.dart';
import 'page_time_tracker.dart';

// Components
import 'components/pdf_viewer_top_bar.dart';
import 'components/right_thumbnail_sidebar.dart';
import 'components/floating_tool_menu.dart';
import 'components/analysis_result_dialog.dart';

// Services
import 'services/image_capture_service.dart';

import 'package:akilli_tahta_proje_demo/viewer/drawing_provider.dart';
import 'package:provider/provider.dart';

class PdfDrawingViewerPage extends StatefulWidget {
  final String pdfPath;
  final VoidCallback? onBack;
  final CropData? cropData;
  final String? zipFilePath;
  final Uint8List? pdfBytes; // Web platformu için PDF bytes
  final Uint8List? zipBytes; // Web platformu için ZIP bytes

  const PdfDrawingViewerPage({
    super.key,
    required this.pdfPath,
    this.onBack,
    this.cropData,
    this.zipFilePath,
    this.pdfBytes,
    this.zipBytes,
  });

  @override
  State<PdfDrawingViewerPage> createState() => _PdfDrawingViewerPageState();
}

class _PdfDrawingViewerPageState extends State<PdfDrawingViewerPage> {
  late PdfViewerController _pdfController;
  late Future<PdfDocument> _pdfDocument;
  final GlobalKey<PdfViewerWithDrawingState> _drawingKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  // Soru Çözücü Service
  final SoruCozucuService _service = SoruCozucuService();

  // DrawingProvider - initState'te oluşturulacak
  late DrawingProvider _drawingProvider;

  bool _isAnalyzing = false;
  bool _serverHealthy = false;
  bool _showThumbnails = false;
  bool _isToolMenuVisible = false;
  bool _showCalculator = false;
  bool _showScratchpad = false;
  bool _isPdfLoading = true;

  // Sidebar Position State
  Offset _sidebarPosition = const Offset(16, 10);

  @override
  void initState() {
    super.initState();

    // DrawingProvider'ı oluştur
    _drawingProvider = DrawingProvider();

    // pdfrx: Separate document loading from controller
    _pdfController = PdfViewerController();
    _pdfDocument = widget.pdfBytes != null
        ? PdfDocument.openData(widget.pdfBytes!)
        : PdfDocument.openFile(widget.pdfPath);

    _loadPdf();
    _checkServerHealth();
  }

  Future<void> _loadPdf() async {
    try {
      await _pdfDocument;
      await Future.delayed(const Duration(milliseconds: 100));

      _pdfController.addListener(() {
        if (mounted && _pdfController.isReady) {
          setState(() {});
        }
      });

      if (mounted) {
        setState(() => _isPdfLoading = false);
      }
    } catch (e) {
      print('❌ Error loading PDF: $e');
      if (mounted) {
        setState(() => _isPdfLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _drawingProvider.dispose();
    super.dispose();
  }

  /// Python sunucusunun çalışıp çalışmadığını kontrol et
  Future<void> _checkServerHealth() async {
    final isHealthy = await _service.checkHealth();

    if (!mounted) return;

    setState(() {
      _serverHealthy = isHealthy;
    });

    // if (!isHealthy) {
    //   _showServerHealthWarning();
    // }
  }

  /// Seçili alanı capture et
  Future<Uint8List?> _captureSelectedArea() async {
    final state = _drawingKey.currentState;
    if (state == null || state.selectedAreaNotifier.value == null) {
      print('❌ Seçili alan yok');
      return null;
    }

    return ImageCaptureService.captureSelectedArea(
      canvasKey: _canvasKey,
      selectedRect: state.selectedAreaNotifier.value!,
    );
  }

  /// Soru çözme işlemini başlat
  Future<void> _solveProblem() async {
    if (_isAnalyzing) return;

    final state = _drawingKey.currentState;
    if (state == null || state.selectedAreaNotifier.value == null) {
      _showSnackBar('⚠️ Lütfen önce bir alan seçin!', Colors.orange);
      return;
    }

    // Sunucu kontrolü
    if (!_serverHealthy) {
      _showSnackBar(
        'Python sunucusu çalışmıyor!',
        Colors.red,
        action: SnackBarAction(
          label: 'Test Et',
          textColor: Colors.white,
          onPressed: _checkServerHealth,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    _showAnalyzingDialog();

    try {
      print('📸 Seçili alan capture ediliyor...');
      final imageBytes = await _captureSelectedArea();

      if (imageBytes == null) {
        throw Exception('Görsel alınamadı');
      }

      print('✅ Seçili alan alındı: ${imageBytes.length} bytes');

      print('🔍 API\'ye gönderiliyor...');
      final result = await _service.analyzeImage(imageBytes, returnImage: true);

      if (!mounted) return;
      Navigator.of(context).pop(); // Progress dialog'u kapat

      if (result == null || !result.success) {
        throw Exception(result?.error ?? 'Analiz başarısız');
      }

      print('✅ Analiz tamamlandı: ${result.soruSayisi} soru bulundu');

      state.clearSelection();

      _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      _showSnackBar('❌ Hata: $e', Colors.red);
      print('❌ Soru çözme hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _showAnalyzingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  '🤖 Seçili alan analiz ediliyor...',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResultDialog(AnalysisResult result) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return AnalysisResultDialog(result: result);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showSnackBar(
    String message,
    Color backgroundColor, {
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        action: action,
      ),
    );
  }

  void _toggleToolMenu() {
    setState(() {
      _isToolMenuVisible = !_isToolMenuVisible;
    });
  }

  void _openCalculator() {
    setState(() {
      _showCalculator = true;
    });
  }

  void _closeCalculator() {
    setState(() {
      _showCalculator = false;
    });
  }

  void _openScratchpad() {
    setState(() {
      _showScratchpad = true;
    });
  }

  void _closeScratchpad() {
    setState(() {
      _showScratchpad = false;
    });
  }

  void _toggleThumbnails() {
    setState(() {
      _showThumbnails = !_showThumbnails;
    });
  }

  /// Sayfaya git dialog'unu göster
  void _showGoToPageDialog() {
    final pageController = TextEditingController();
    final totalPages = _pdfController.pagesCount ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sayfaya Git'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toplam $totalPages sayfa',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pageController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Sayfa Numarası',
                  hintText: '1-$totalPages arası',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.tag),
                ),
                onSubmitted: (value) {
                  _goToPage(pageController.text, totalPages);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                _goToPage(pageController.text, totalPages);
                Navigator.of(context).pop();
              },
              child: const Text('Git'),
            ),
          ],
        );
      },
    );
  }

  /// Belirtilen sayfaya git
  void _goToPage(String pageText, int totalPages) {
    final pageNumber = int.tryParse(pageText);

    if (pageNumber == null) {
      _showSnackBar('⚠️ Geçerli bir sayı girin!', Colors.orange);
      return;
    }

    if (pageNumber < 1 || pageNumber > totalPages) {
      _showSnackBar(
        '⚠️ Sayfa numarası 1-$totalPages arasında olmalı!',
        Colors.orange,
      );
      return;
    }

    _pdfController.jumpToPage(pageNumber);
    _showSnackBar('📄 Sayfa $pageNumber\'e gidildi', Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _drawingProvider,
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                Consumer<DrawingProvider>(
                  builder: (context, drawingProvider, child) {
                    if (_isPdfLoading) {
                      return const SizedBox.shrink();
                    }

                    final state = _drawingKey.currentState;

                    if (state == null) {
                      return PdfViewerTopBar(
                        pdfPath: widget.pdfPath,
                        pdfController: _pdfController,
                        currentPage: drawingProvider.currentPage,
                        showThumbnails: _showThumbnails,
                        onToggleThumbnails: _toggleThumbnails,
                        zoomLevel: drawingProvider.zoomLevel,
                        timeTracker: PageTimeTracker(onUpdate: () {}),
                        currentPageTime: '0sn',
                        onBack: widget.onBack,
                        onGoToPage: _showGoToPageDialog,
                      );
                    }

                    return ValueListenableBuilder<String>(
                      valueListenable: state.currentPageTimeNotifier,
                      builder: (context, pageTime, _) {
                        return AnimatedBuilder(
                          animation: state.transformationController,
                          builder: (context, _) {
                            return PdfViewerTopBar(
                              pdfPath: widget.pdfPath,
                              pdfController: _pdfController,
                              currentPage: drawingProvider.currentPage,
                              showThumbnails: _showThumbnails,
                              onToggleThumbnails: _toggleThumbnails,
                              zoomLevel: drawingProvider.zoomLevel,
                              timeTracker: state.timeTracker,
                              currentPageTime: pageTime,
                              onBack: widget.onBack,
                              onGoToPage: _showGoToPageDialog,
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                // PDF Viewer + Floating Panel
                Expanded(
                  child: Stack(
                    children: [
                      // PDF Viewer (Full screen)
                      RepaintBoundary(
                        key: _canvasKey,
                        child: Listener(
                          onPointerSignal: (event) {
                            if (event is PointerScrollEvent) {
                              final controller = _pdfController;
                              if (controller.isReady) {
                                final matrix = controller.value.clone();
                                final dy = -event.scrollDelta.dy;
                                matrix.translateByVector3(
                                  Vector3(0.0, dy, 0.0),
                                );
                                controller.value = matrix;
                              }
                            }
                          },
                          onPointerPanZoomUpdate: (event) {
                            // print('PanZoom event: ${event.panDelta}');
                            final controller = _pdfController;
                            if (controller.isReady) {
                              final matrix = controller.value.clone();
                              final dy = event.panDelta.dy;
                              matrix.translateByVector3(Vector3(0, dy, 0));
                              controller.value = matrix;
                            }
                          },
                          child: PdfViewerWithDrawing(
                            key: _drawingKey,
                            controller: _pdfController,
                            documentRef: _pdfDocument,
                            cropData: widget.cropData,
                            zipFilePath: widget.zipFilePath,
                            zipBytes: widget.zipBytes,
                          ),
                        ),
                      ),

                      // Floating Panel (Overlay)
                      // Vertical Tool Sidebar (Draggable)
                      if (_drawingKey.currentState != null)
                        Positioned(
                          left: _sidebarPosition.dx,
                          top: _sidebarPosition.dy,
                          child: VerticalToolSidebar(
                            drawingProvider: _drawingProvider,
                            toolNotifier:
                                _drawingKey.currentState!.toolNotifier,
                            canUndoNotifier:
                                _drawingKey.currentState!.canUndoNotifier,
                            canRedoNotifier:
                                _drawingKey.currentState!.canRedoNotifier,
                            onSolve: _serverHealthy ? _solveProblem : null,
                            onRotateLeft: () =>
                                _drawingKey.currentState!.rotateLeft(),
                            onRotateRight: () =>
                                _drawingKey.currentState!.rotateRight(),
                            onFirstPage: () => _pdfController.jumpToPage(1),
                            onPreviousPage: () => _pdfController.previousPage(),
                            onNextPage: () => _pdfController.nextPage(),
                            onLastPage: () => _pdfController.jumpToPage(
                              _pdfController.pagesCount ?? 1,
                            ),
                            onUndo: () => _drawingKey.currentState!.undo(),
                            onRedo: () => _drawingKey.currentState!.redo(),
                            onClear: () =>
                                _drawingKey.currentState!.clearCurrentPage(),
                            onDragUpdate: (details) {
                              setState(() {
                                _sidebarPosition += details.delta;
                              });
                            },
                            onToggleThumbnails: () {
                              setState(() {
                                _showThumbnails = !_showThumbnails;
                              });
                            },
                          ),
                        ),

                      // Floating Tool Menu (Sağ alt köşe)
                      if (_isToolMenuVisible)
                        FloatingToolMenu(
                          onOpenCalculator: _openCalculator,
                          onOpenScratchpad: _openScratchpad,
                        ),

                      // Calculator Widget (Overlay)
                      if (_showCalculator)
                        CalculatorWidget(onClose: _closeCalculator),

                      // Scratchpad Widget (Overlay)
                      if (_showScratchpad)
                        ScratchpadWidget(onClose: _closeScratchpad),

                      // Right Thumbnail Sidebar
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        right: _showThumbnails ? 0 : -160, // Hide off-screen
                        top: 0,
                        bottom: 0,
                        child: RightThumbnailSidebar(
                          pdfController: _pdfController,
                          pdfDocument: _pdfDocument,
                          currentPage: _drawingProvider.currentPage,
                          onClose: () {
                            setState(() {
                              _showThumbnails = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Loading overlay
            if (_isPdfLoading)
              Positioned.fill(
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.95),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Loading animation
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            strokeWidth: 6,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Loading text
                        Text(
                          'PDF Yükleniyor...',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'Lütfen bekleyin',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Progress indicator dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            return TweenAnimationBuilder<double>(
                              key: ValueKey('$_isPdfLoading-$index'),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(
                                milliseconds: 600 + (index * 200),
                              ),
                              curve: Curves.easeInOut,
                              builder: (context, value, child) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.2 + (value * 0.8)),
                                  ),
                                );
                              },
                              onEnd: () {
                                // Repeat animation
                                if (mounted && _isPdfLoading) {
                                  setState(() {});
                                }
                              },
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _toggleToolMenu,
          tooltip: 'Araçlar',
          child: Icon(_isToolMenuVisible ? Icons.close : Icons.widgets),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
