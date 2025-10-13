import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io'; // 🆕 File için
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfx/pdfx.dart';
import 'pdf_viewer_with_drawing.dart';
import 'left_panel.dart';
import '../soru_cozucu_service.dart';
import 'pdf_thumbnail.dart'; // 🆕 Import ekle

class PdfDrawingViewerPage extends StatefulWidget {
  final String pdfPath;
  final VoidCallback? onBack;

  const PdfDrawingViewerPage({super.key, required this.pdfPath, this.onBack});

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
  bool _showThumbnails = false; // 🆕 Thumbnail görünürlük kontrolü

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

    if (!isHealthy) {
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
  }

  /// Seçili alanı transform'a göre düzelt ve crop et
  Future<Uint8List?> _captureSelectedArea() async {
    try {
      final state = _drawingKey.currentState;
      if (state == null || state.selectedAreaNotifier.value == null) {
        print('❌ Seçili alan yok');
        return null;
      }

      final boundary =
          _canvasKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        print('❌ Canvas boundary bulunamadı');
        return null;
      }

      // RenderBox boyutunu al
      final renderBox =
          _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) {
        print('❌ RenderBox bulunamadı');
        return null;
      }

      final viewportSize = renderBox.size;
      print(
        '📱 Viewport boyutu: ${viewportSize.width} x ${viewportSize.height}',
      );

      // Viewport koordinatlarında seçim alanını kullan (zoom'dan bağımsız)
      final selectedRect = state.selectedAreaNotifier.value!;
      print(
        '📐 Kullanıcının seçtiği alan (viewport): x=${selectedRect.left.toInt()}, y=${selectedRect.top.toInt()}, w=${selectedRect.width.toInt()}, h=${selectedRect.height.toInt()}',
      );

      // Screenshot al - viewport boyutunda
      final pixelRatio = 4.0;
      print('📸 Screenshot alınıyor (pixelRatio: $pixelRatio)...');

      final fullImage = await boundary.toImage(pixelRatio: pixelRatio);
      print('🖼️ Screenshot boyutu: ${fullImage.width} x ${fullImage.height}');

      // Gerçek scale faktörü (screenshot boyutu / viewport boyutu)
      final actualScaleX = fullImage.width / viewportSize.width;
      final actualScaleY = fullImage.height / viewportSize.height;

      print('📏 Scale faktörleri: X=$actualScaleX, Y=$actualScaleY');

      // Seçili alanı scale et
      final scaledLeft = selectedRect.left * actualScaleX;
      final scaledTop = selectedRect.top * actualScaleY;
      final scaledWidth = selectedRect.width * actualScaleX;
      final scaledHeight = selectedRect.height * actualScaleY;

      print(
        '✂️ Scaled crop area: x=${scaledLeft.toInt()}, y=${scaledTop.toInt()}, w=${scaledWidth.toInt()}, h=${scaledHeight.toInt()}',
      );

      // Sınırları clamp et
      final clampedLeft = scaledLeft.clamp(0.0, fullImage.width.toDouble());
      final clampedTop = scaledTop.clamp(0.0, fullImage.height.toDouble());
      final clampedRight = (scaledLeft + scaledWidth).clamp(
        0.0,
        fullImage.width.toDouble(),
      );
      final clampedBottom = (scaledTop + scaledHeight).clamp(
        0.0,
        fullImage.height.toDouble(),
      );

      final finalWidth = (clampedRight - clampedLeft).toInt();
      final finalHeight = (clampedBottom - clampedTop).toInt();

      print(
        '🎯 Final crop (clamped): x=${clampedLeft.toInt()}, y=${clampedTop.toInt()}, w=$finalWidth, h=$finalHeight',
      );

      // Geçerlilik kontrolü
      if (finalWidth < 10 || finalHeight < 10) {
        print('❌ Crop alanı çok küçük: ${finalWidth}x$finalHeight');
        fullImage.dispose();
        return null;
      }

      // Crop rectangle
      final cropRect = Rect.fromLTWH(
        clampedLeft,
        clampedTop,
        finalWidth.toDouble(),
        finalHeight.toDouble(),
      );

      // Yeni image oluştur
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Arka planı beyaz yap
      canvas.drawRect(
        Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
        Paint()..color = Colors.white,
      );

      // Crop edilen bölgeyi çiz
      canvas.drawImageRect(
        fullImage,
        cropRect,
        Rect.fromLTWH(0, 0, finalWidth.toDouble(), finalHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();

      // Eğer görsel çok küçükse, upscale yap
      final minDimension = 1200; // Minimum boyut
      int outputWidth = finalWidth;
      int outputHeight = finalHeight;

      if (finalWidth < minDimension || finalHeight < minDimension) {
        final scale =
            minDimension /
            (finalWidth < finalHeight ? finalWidth : finalHeight);
        outputWidth = (finalWidth * scale).toInt();
        outputHeight = (finalHeight * scale).toInt();
        print(
          '📈 Upscaling: ${finalWidth}x$finalHeight → ${outputWidth}x$outputHeight',
        );
      }

      final croppedImage = await picture.toImage(outputWidth, outputHeight);

      print(
        '✅ Cropped image oluşturuldu: ${croppedImage.width} x ${croppedImage.height}',
      );

      // PNG'ye dönüştür
      final byteData = await croppedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      // Cleanup
      fullImage.dispose();
      croppedImage.dispose();

      final result = byteData?.buffer.asUint8List();

      if (result != null) {
        print('💾 PNG boyutu: ${(result.length / 1024).toStringAsFixed(1)} KB');

        // Debug: Görseli kaydet
        try {
          final downloadsPath =
              '/Users/${Platform.environment['USER']}/Downloads';
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final debugFile = File('$downloadsPath/debug_crop_$timestamp.png');
          await debugFile.writeAsBytes(result);
          print('🔍 Debug: Görsel kaydedildi → ${debugFile.path}');
          print('👁️ Görseli açıp doğru kesilip kesilmediğini kontrol edin!');
        } catch (e) {
          print('⚠️ Debug kayıt hatası: $e');
        }
      }

      return result;
    } catch (e, stackTrace) {
      print('❌ Crop hatası: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Soru çözme işlemini başlat
  Future<void> _solveProblem() async {
    if (_isAnalyzing) return;

    final state = _drawingKey.currentState;
    if (state == null || state.selectedAreaNotifier.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Lütfen önce bir alan seçin!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Sunucu kontrolü
    if (!_serverHealthy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Python sunucusu çalışmıyor!'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Test Et',
            textColor: Colors.white,
            onPressed: _checkServerHealth,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _lastResult = null;
    });

    // Progress indicator göster
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Hata: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      print('❌ Soru çözme hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  /// Sonuçları dialog'da göster
  void _showResultDialog(AnalysisResult result) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${result.soruSayisi} Soru Bulundu',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cevaplı görsel varsa göster
                      if (result.resultImage != null) ...[
                        const Text(
                          '📸 Cevaplı Görsel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            result.resultImage!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),
                      ],

                      // Soru detayları
                      const Text(
                        '📝 Soru Detayları',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      ...result.sorular.asMap().entries.map((entry) {
                        final soru = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Soru başlığı
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Soru ${soru.soruNo}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Soru metni
                                  Text(
                                    soru.metin,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Cevap
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green,
                                        width: 2,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Cevap: ${soru.dogruSecenek}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Açıklama
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.lightbulb_outline,
                                          size: 18,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            soru.aciklama,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ÜST BAR - Sayfa Bilgisi ve Kontroller
          Container(
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
                    widget.pdfPath.split('/').last,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Sayfa Bilgisi (Tıklanabilir - Thumbnail Toggle)
                ValueListenableBuilder<int>(
                  valueListenable: _pdfController.pageListenable,
                  builder: (context, currentPage, child) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _showThumbnails = !_showThumbnails;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _showThumbnails
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showThumbnails
                                  ? Icons.grid_view
                                  : Icons.description,
                              size: 16,
                              color: _showThumbnails
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sayfa $currentPage / ${_pdfController.pagesCount ?? 0}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _showThumbnails
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showThumbnails
                                  ? Icons.expand_more
                                  : Icons.chevron_right,
                              size: 18,
                              color: _showThumbnails
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 16),

                // Zoom Seviyesi
                AnimatedBuilder(
                  animation:
                      _drawingKey.currentState?.transformationController ??
                      TransformationController(),
                  builder: (context, child) {
                    final state = _drawingKey.currentState;
                    final zoomLevel = state?.zoomLevel ?? 1.0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
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
                    );
                  },
                ),

                const SizedBox(width: 16),

                // Geri Butonu
                if (widget.onBack != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onBack,
                    tooltip: 'Kapat',
                  ),
              ],
            ),
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
                  ),
                ),

                // Floating Panel (Overlay)
                FloatingLeftPanel(
                  controller: _pdfController,
                  drawingKey: _drawingKey,
                  onSolveProblem: _serverHealthy ? _solveProblem : null,
                ),
              ],
            ),
          ),

          // 🆕 ALT KISIM - PDF Thumbnail List (Toggle edilebilir)
          if (_showThumbnails)
            ValueListenableBuilder<int>(
              valueListenable: _pdfController.pageListenable,
              builder: (context, currentPage, child) {
                return PdfThumbnailList(
                  pdfController: _pdfController,
                  currentPage: currentPage,
                  totalPages: _pdfController.pagesCount ?? 0,
                  onPageSelected: (pageNumber) {
                    _pdfController.jumpToPage(pageNumber);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
