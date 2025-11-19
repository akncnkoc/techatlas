import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'pdf_viewer_with_drawing.dart';
import 'left_panel.dart';
import '../soru_cozucu_service.dart';
import 'calculator_widget.dart';
import 'scratchpad_widget.dart';
import '../models/crop_data.dart';

// Components
import 'components/pdf_viewer_top_bar.dart';
import 'components/thumbnail_panel.dart';
import 'components/floating_tool_menu.dart';
import 'components/analysis_result_dialog.dart';
import 'components/bottom_drag_handle.dart';

// Services
import 'services/image_capture_service.dart';

class PdfDrawingViewerPage extends StatefulWidget {
  final String pdfPath;
  final VoidCallback? onBack;
  final CropData? cropData;
  final String? zipFilePath;

  const PdfDrawingViewerPage({
    super.key,
    required this.pdfPath,
    this.onBack,
    this.cropData,
    this.zipFilePath,
  });

  @override
  State<PdfDrawingViewerPage> createState() => _PdfDrawingViewerPageState();
}

class _PdfDrawingViewerPageState extends State<PdfDrawingViewerPage> {
  late PdfController _pdfController;
  final GlobalKey<PdfViewerWithDrawingState> _drawingKey = GlobalKey();
  final GlobalKey _canvasKey = GlobalKey();

  // Soru Çözücü Service
  final SoruCozucuService _service = SoruCozucuService();

  bool _isAnalyzing = false;
  AnalysisResult? _lastResult;
  bool _serverHealthy = false;
  bool _showThumbnails = false;
  bool _isToolMenuVisible = false;
  bool _showCalculator = false;
  bool _showScratchpad = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfController(
      document: PdfDocument.openFile(widget.pdfPath),
    );
    _checkServerHealth();
  }

  @override
  void dispose() {
    _pdfController.dispose();
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

  void _showServerHealthWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Python sunucusu çalışmıyor! Soru çözme özelliği kullanılamaz.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Tekrar Dene',
          textColor: Colors.white,
          onPressed: _checkServerHealth,
        ),
      ),
    );
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
      _lastResult = null;
    });

    _showAnalyzingDialog();

    try {
      // 1. Seçili alanı capture et
      print('📸 Seçili alan capture ediliyor...');
      final imageBytes = await _captureSelectedArea();

      if (imageBytes == null) {
        throw Exception('Görsel alınamadı');
      }

      print('✅ Seçili alan alındı: ${imageBytes.length} bytes');

      // 2. Python API'ye gönder ve analiz et
      print('🔍 API\'ye gönderiliyor...');
      final result = await _service.analyzeImage(imageBytes, returnImage: true);

      if (!mounted) return;
      Navigator.of(context).pop(); // Progress dialog'u kapat

      if (result == null || !result.success) {
        throw Exception(result?.error ?? 'Analiz başarısız');
      }

      print('✅ Analiz tamamlandı: ${result.soruSayisi} soru bulundu');

      setState(() {
        _lastResult = result;
      });

      // 3. Seçimi temizle
      state.clearSelection();

      // 4. Sonuçları göster
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
    showDialog(
      context: context,
      builder: (context) => AnalysisResultDialog(result: result),
    );
  }

  void _showSnackBar(String message, Color backgroundColor,
      {SnackBarAction? action}) {
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

  @override
  Widget build(BuildContext context) {
    final state = _drawingKey.currentState;

    return Scaffold(
      body: Column(
        children: [
          // ÜST BAR
          if (state != null)
            ValueListenableBuilder<String>(
              valueListenable: state.currentPageTimeNotifier,
              builder: (context, pageTime, _) {
                return AnimatedBuilder(
                  animation: state.transformationController,
                  builder: (context, _) {
                    return PdfViewerTopBar(
                      pdfPath: widget.pdfPath,
                      pdfController: _pdfController,
                      showThumbnails: _showThumbnails,
                      onToggleThumbnails: _toggleThumbnails,
                      zoomLevel: state.zoomLevel,
                      timeTracker: state.timeTracker,
                      currentPageTime: pageTime,
                      onBack: widget.onBack,
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
                  child: PdfViewerWithDrawing(
                    key: _drawingKey,
                    controller: _pdfController,
                    cropData: widget.cropData,
                    zipFilePath: widget.zipFilePath,
                  ),
                ),

                // Floating Panel (Overlay)
                FloatingLeftPanel(
                  controller: _pdfController,
                  drawingKey: _drawingKey,
                  onSolveProblem: _serverHealthy ? _solveProblem : null,
                ),

                // Drag Handle - Alt kısımda thumbnail açmak için
                if (!_showThumbnails)
                  BottomDragHandle(
                    onSwipeUp: () {
                      setState(() {
                        _showThumbnails = true;
                      });
                    },
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
              ],
            ),
          ),

          // ALT KISIM - PDF Thumbnail List
          if (_showThumbnails)
            ValueListenableBuilder<int>(
              valueListenable: _pdfController.pageListenable,
              builder: (context, currentPage, child) {
                return ThumbnailPanel(
                  pdfController: _pdfController,
                  currentPage: currentPage,
                  onClose: () {
                    setState(() {
                      _showThumbnails = false;
                    });
                  },
                );
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleToolMenu,
        tooltip: 'Araçlar',
        child: Icon(_isToolMenuVisible ? Icons.close : Icons.widgets),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
