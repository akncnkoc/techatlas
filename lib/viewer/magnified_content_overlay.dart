import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'tool_state.dart';
import 'widgets/drawable_content_widget.dart';

/// Widget that shows a magnified view of the selected area
class MagnifiedContentOverlay extends StatefulWidget {
  final Rect selectedArea;
  final GlobalKey contentKey;
  final double magnification;
  final VoidCallback? onClose;

  const MagnifiedContentOverlay({
    super.key,
    required this.selectedArea,
    required this.contentKey,
    this.magnification = 2.0,
    this.onClose,
  });

  @override
  State<MagnifiedContentOverlay> createState() =>
      _MagnifiedContentOverlayState();
}

class _MagnifiedContentOverlayState extends State<MagnifiedContentOverlay> {
  ui.Image? _capturedImage;
  bool _isCapturing = true;
  double _capturePixelRatio = 1.0;

  // Draggable and resizable state
  late double _width;
  late double _height;
  late Offset _position;
  bool _isDragging = false;
  bool _isResizing = false;
  String? _resizeDirection;

  // Fullscreen state
  bool _isFullscreen = false;
  late double _savedWidth;
  late double _savedHeight;
  late Offset _savedPosition;

  // Drawing state
  final GlobalKey<DrawableContentWidgetState> _drawingKey = GlobalKey();
  late ValueNotifier<ToolState> _toolNotifier;
  bool _isDrawingMode = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Initialize with default values
    _width = 400.0;
    _height = 300.0;
    _position = Offset.zero;

    _toolNotifier = ValueNotifier(
      ToolState(
        eraser: false,
        pencil: true,
        highlighter: false,
        grab: false,
        mouse: false,
        shape: false,
        selection: false,
        magnifier: false,
        selectedShape: ShapeType.line,
        color: Colors.red,
        width: 3.0,
      ),
    );
    _captureContent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // İlk açılışta boyut ve pozisyonu hesapla (only once)
    // Don't call setState here - just update the values directly
    if (!_isInitialized && !_isDragging && !_isResizing) {
      final screenSize = MediaQuery.of(context).size;
      // Calculate initial values without setState since didChangeDependencies
      // is called during build phase
      _width = (widget.selectedArea.width * widget.magnification).clamp(
        400.0,
        screenSize.width * 0.8,
      );
      _height = (widget.selectedArea.height * widget.magnification).clamp(
        300.0,
        screenSize.height * 0.8,
      );
      _position = Offset(
        (screenSize.width - _width) / 2,
        (screenSize.height - _height) / 2,
      );
      _isInitialized = true;

      // Schedule a rebuild for next frame instead of calling setState directly
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _captureContent() async {
    // Wait for the next frame to ensure RepaintBoundary is rendered
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    try {
      // Get the RenderObject from the RepaintBoundary
      final renderObject = widget.contentKey.currentContext?.findRenderObject();

      print('🔍 Capturing content...');
      print(
        '   Context: ${widget.contentKey.currentContext != null ? "✓" : "✗"}',
      );
      print('   RenderObject: ${renderObject != null ? "✓" : "✗"}');
      print(
        '   Is RepaintBoundary: ${renderObject is RenderRepaintBoundary ? "✓" : "✗"}',
      );

      if (renderObject is! RenderRepaintBoundary) {
        print('❌ RenderObject is not a RepaintBoundary!');
        if (!mounted) return;
        setState(() => _isCapturing = false);
        return;
      }

      final boundary = renderObject;
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

      // ⚡ 1. AŞAMA: HIZLI DÜŞÜK KALİTE YÜKLEME
      // Önce düşük pixel ratio ile hızlıca yakala ve göster
      final quickPixelRatio = (devicePixelRatio * 1.5).clamp(2.0, 3.0);
      print('⚡ Phase 1: Quick capture at ${quickPixelRatio}x...');

      final quickImage = await boundary.toImage(pixelRatio: quickPixelRatio);

      if (!mounted) return;

      setState(() {
        _capturedImage = quickImage;
        _capturePixelRatio = quickPixelRatio;
        _isCapturing = false;
      });

      print('✅ Quick preview loaded: ${quickImage.width}x${quickImage.height}');

      // 🎨 2. AŞAMA: YÜKSEK KALİTE YÜKLEME (ARKA PLANDA)
      // Kullanıcı zaten içeriği görüyor, şimdi yüksek kaliteyi yükle
      final highPixelRatio = (devicePixelRatio * widget.magnification * 1.5)
          .clamp(3.0, 6.0);
      print('🎨 Phase 2: High quality capture at ${highPixelRatio}x...');

      final highImage = await boundary.toImage(pixelRatio: highPixelRatio);

      if (!mounted) {
        highImage.dispose();
        return;
      }

      // Eski düşük kalite image'ı dispose et
      quickImage.dispose();

      setState(() {
        _capturedImage = highImage;
        _capturePixelRatio = highPixelRatio;
      });

      print('✅ High quality loaded: ${highImage.width}x${highImage.height}');
      print('   Selected area: ${widget.selectedArea}');
    } catch (e, stackTrace) {
      print('❌ Error capturing content: $e');
      print('   Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() => _isCapturing = false);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isResizing) {
      _handleResize(details);
    } else if (_isDragging) {
      _handleDrag(details);
    }
  }

  void _handleDrag(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;

      // Ekran sınırlarını kontrol et
      final size = MediaQuery.of(context).size;
      _position = Offset(
        _position.dx.clamp(0.0, size.width - _width),
        _position.dy.clamp(0.0, size.height - _height),
      );
    });
  }

  void _handleResize(DragUpdateDetails details) {
    setState(() {
      final size = MediaQuery.of(context).size;
      const minWidth = 300.0;
      const minHeight = 200.0;

      switch (_resizeDirection) {
        case 'bottom-right':
          _width = (_width + details.delta.dx).clamp(
            minWidth,
            size.width - _position.dx,
          );
          _height = (_height + details.delta.dy).clamp(
            minHeight,
            size.height - _position.dy,
          );
          break;
        case 'bottom-left':
          final newWidth = _width - details.delta.dx;
          if (newWidth >= minWidth && _position.dx + details.delta.dx >= 0) {
            _width = newWidth;
            _position = Offset(_position.dx + details.delta.dx, _position.dy);
          }
          _height = (_height + details.delta.dy).clamp(
            minHeight,
            size.height - _position.dy,
          );
          break;
        case 'top-right':
          final newHeight = _height - details.delta.dy;
          if (newHeight >= minHeight && _position.dy + details.delta.dy >= 0) {
            _height = newHeight;
            _position = Offset(_position.dx, _position.dy + details.delta.dy);
          }
          _width = (_width + details.delta.dx).clamp(
            minWidth,
            size.width - _position.dx,
          );
          break;
        case 'top-left':
          final newWidth = _width - details.delta.dx;
          final newHeight = _height - details.delta.dy;
          if (newWidth >= minWidth && _position.dx + details.delta.dx >= 0) {
            _width = newWidth;
            _position = Offset(_position.dx + details.delta.dx, _position.dy);
          }
          if (newHeight >= minHeight && _position.dy + details.delta.dy >= 0) {
            _height = newHeight;
            _position = Offset(_position.dx, _position.dy + details.delta.dy);
          }
          break;
      }
    });
  }

  Widget _buildResizeHandle(String direction) {
    double? left, right, top, bottom;
    MouseCursor cursor;

    switch (direction) {
      case 'top-left':
        cursor = SystemMouseCursors.resizeUpLeft;
        left = 0;
        top = 0;
        break;
      case 'top-right':
        cursor = SystemMouseCursors.resizeUpRight;
        right = 0;
        top = 0;
        break;
      case 'bottom-left':
        cursor = SystemMouseCursors.resizeDownLeft;
        left = 0;
        bottom = 0;
        break;
      case 'bottom-right':
        cursor = SystemMouseCursors.resizeDownRight;
        right = 0;
        bottom = 0;
        break;
      default:
        cursor = SystemMouseCursors.basic;
    }

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanStart: (_) {
            setState(() {
              _isResizing = true;
              _resizeDirection = direction;
            });
          },
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) {
            setState(() {
              _isResizing = false;
              _resizeDirection = null;
            });
          },
          child: Container(
            width: 20,
            height: 20,
            color: Colors.transparent,
            child: Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.7),
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isSelected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.blue
                  : Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildColorPicker(Color currentColor) {
    return Tooltip(
      message: 'Renk Seç',
      child: InkWell(
        onTap: () {
          // Show color picker dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Renk Seç'),
              content: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        Colors.red,
                        Colors.blue,
                        Colors.green,
                        Colors.yellow,
                        Colors.orange,
                        Colors.purple,
                        Colors.pink,
                        Colors.black,
                        Colors.white,
                        Colors.brown,
                      ].map((color) {
                        return InkWell(
                          onTap: () {
                            _toolNotifier.value = _toolNotifier.value.copyWith(
                              color: color,
                            );
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == currentColor
                                    ? Colors.blue
                                    : Colors.grey,
                                width: color == currentColor ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: currentColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    setState(() {
      if (_isFullscreen) {
        // Tam ekrandan çık - önceki boyut ve pozisyona dön
        _width = _savedWidth;
        _height = _savedHeight;
        _position = _savedPosition;
        _isFullscreen = false;
        print('📉 Normal moda dönüldü');
      } else {
        // Tam ekrana geç - mevcut boyut ve pozisyonu kaydet
        _savedWidth = _width;
        _savedHeight = _savedHeight;
        _savedPosition = _position;

        // Ekran boyutunu al ve tam ekran yap
        final screenSize = MediaQuery.of(context).size;
        _width = screenSize.width;
        _height = screenSize.height;
        _position = Offset.zero;
        _isFullscreen = true;
        print('📈 Tam ekran moduna geçildi');
      }
    });
  }

  @override
  void dispose() {
    _capturedImage?.dispose();
    _toolNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop yok - arkadaki işlemlere izin vermek için

        // Magnified content - Draggable and Resizable
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onTap: () {}, // Backdrop'un tap'ini engelle
            child: Container(
              width: _width,
              height: _height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  width: 3,
                  color: Theme.of(context).colorScheme.primary,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Magnified content with drawing capability
                    if (_isCapturing)
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'İçerik yakalanıyor...',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    else if (_capturedImage != null)
                      DrawableContentWidget(
                        key: _drawingKey,
                        isDrawingEnabled: _isDrawingMode,
                        toolNotifier: _toolNotifier,
                        onDrawingChanged: () {
                          // Force repaint when drawing changes
                          setState(() {});
                          print('🎨 Drawing changed - repainted');
                        },
                        child: CustomPaint(
                          painter: _MagnifiedImagePainter(
                            image: _capturedImage!,
                            sourceRect: widget.selectedArea,
                            capturePixelRatio: _capturePixelRatio,
                          ),
                          size: Size(_width, _height),
                        ),
                      )
                    else
                      const Center(
                        child: Text(
                          'İçerik yakalanamadı',
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),

                    // Drag handle at top (tam ekranda disabled)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: MouseRegion(
                        cursor: _isFullscreen
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.move,
                        child: GestureDetector(
                          onPanStart: _isFullscreen
                              ? null
                              : (_) {
                                  setState(() {
                                    _isDragging = true;
                                  });
                                },
                          onPanUpdate: _isFullscreen ? null : _onPanUpdate,
                          onPanEnd: _isFullscreen
                              ? null
                              : (_) {
                                  setState(() {
                                    _isDragging = false;
                                  });
                                },
                          child: Container(
                            height: 40,
                            color: Colors.transparent,
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.5),
                                      Colors.black.withValues(alpha: 0.3),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.drag_indicator,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Büyütme: ${widget.magnification.toStringAsFixed(1)}x',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Fullscreen button
                    if (!_isCapturing && _capturedImage != null)
                      Positioned(
                        top: 8,
                        right: 56,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleFullscreen,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.8),
                                    Colors.black.withValues(alpha: 0.6),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isFullscreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Close button
                    if (widget.onClose != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onClose,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.shade600,
                                    Colors.red.shade800,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Drawing toolbar
                    if (!_isCapturing && _capturedImage != null)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.85),
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ValueListenableBuilder<ToolState>(
                              valueListenable: _toolNotifier,
                              builder: (context, tool, _) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Drawing mode toggle
                                    _buildToolButton(
                                      icon: _isDrawingMode
                                          ? Icons.touch_app
                                          : Icons.edit_off,
                                      isSelected: _isDrawingMode,
                                      tooltip: _isDrawingMode
                                          ? 'Çizim Kapalı'
                                          : 'Çizim Açık',
                                      onTap: () {
                                        setState(() {
                                          _isDrawingMode = !_isDrawingMode;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    if (_isDrawingMode) ...[
                                      // Pencil
                                      _buildToolButton(
                                        icon: Icons.brush,
                                        isSelected: tool.pencil,
                                        tooltip: 'Kalem',
                                        onTap: () {
                                          _toolNotifier.value = tool.copyWith(
                                            pencil: true,
                                            eraser: false,
                                            highlighter: false,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      // Eraser
                                      _buildToolButton(
                                        icon: Icons.cleaning_services,
                                        isSelected: tool.eraser,
                                        tooltip: 'Silgi',
                                        onTap: () {
                                          _toolNotifier.value = tool.copyWith(
                                            eraser: true,
                                            pencil: false,
                                            highlighter: false,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      // Highlighter
                                      _buildToolButton(
                                        icon: Icons.highlight,
                                        isSelected: tool.highlighter,
                                        tooltip: 'Fosforlu',
                                        onTap: () {
                                          _toolNotifier.value = tool.copyWith(
                                            highlighter: true,
                                            pencil: false,
                                            eraser: false,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      // Color picker
                                      _buildColorPicker(tool.color),
                                      const SizedBox(width: 4),
                                      // Undo
                                      _buildToolButton(
                                        icon: Icons.undo,
                                        isSelected: false,
                                        tooltip: 'Geri Al',
                                        onTap: () {
                                          final state =
                                              _drawingKey.currentState;
                                          if (state != null) {
                                            state.undo();
                                            print('↩️ Geri alındı');
                                          } else {
                                            print('⚠️ Drawing state null!');
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      // Clear
                                      _buildToolButton(
                                        icon: Icons.delete_outline,
                                        isSelected: false,
                                        tooltip: 'Temizle',
                                        onTap: () {
                                          final state =
                                              _drawingKey.currentState;
                                          if (state != null) {
                                            state.clearDrawing();
                                            print('🧹 Çizimler temizlendi');
                                          } else {
                                            print('⚠️ Drawing state null!');
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                    // Resize handles (tam ekranda gizli)
                    if (!_isFullscreen) ...[
                      _buildResizeHandle('top-left'),
                      _buildResizeHandle('top-right'),
                      _buildResizeHandle('bottom-left'),
                      _buildResizeHandle('bottom-right'),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter to draw the magnified portion of the captured image
class _MagnifiedImagePainter extends CustomPainter {
  final ui.Image image;
  final Rect sourceRect;
  final double capturePixelRatio;

  _MagnifiedImagePainter({
    required this.image,
    required this.sourceRect,
    required this.capturePixelRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    // Calculate source rectangle with proper scaling
    // The image is captured at high pixel ratio for magnification
    final scaledSourceRect = Rect.fromLTRB(
      sourceRect.left * capturePixelRatio,
      sourceRect.top * capturePixelRatio,
      sourceRect.right * capturePixelRatio,
      sourceRect.bottom * capturePixelRatio,
    );

    // Ensure source rect is within image bounds
    final clampedSourceRect = Rect.fromLTRB(
      scaledSourceRect.left.clamp(0.0, image.width.toDouble()),
      scaledSourceRect.top.clamp(0.0, image.height.toDouble()),
      scaledSourceRect.right.clamp(0.0, image.width.toDouble()),
      scaledSourceRect.bottom.clamp(0.0, image.height.toDouble()),
    );

    print('🎨 Painting magnified image:');
    print('   Image size: ${image.width}x${image.height}');
    print('   Source rect (screen): $sourceRect');
    print('   Capture pixel ratio: ${capturePixelRatio}x');
    print('   Scaled source rect: $scaledSourceRect');
    print('   Clamped source rect: $clampedSourceRect');
    print('   Canvas size: $size');

    // Destination rectangle fills the entire canvas
    final destRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw the magnified portion
    canvas.drawImageRect(image, clampedSourceRect, destRect, paint);
  }

  @override
  bool shouldRepaint(_MagnifiedImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.sourceRect != sourceRect ||
        oldDelegate.capturePixelRatio != capturePixelRatio;
  }
}

/// Painter for selection overlay with handles
class MagnifierSelectionPainter extends CustomPainter {
  final Rect selectedArea;

  MagnifierSelectionPainter({required this.selectedArea});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw semi-transparent overlay except for selected area
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Draw overlay on the entire canvas
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Clear the selected area (cut out the rectangle)
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRect(selectedArea, clearPaint);

    // Draw border around selected area
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(selectedArea, borderPaint);

    // Draw corner handles
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final handleSize = 12.0;
    final corners = [
      selectedArea.topLeft,
      selectedArea.topRight,
      selectedArea.bottomLeft,
      selectedArea.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, handleSize / 2, handlePaint);
      canvas.drawCircle(
        corner,
        handleSize / 2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(MagnifierSelectionPainter oldDelegate) {
    return oldDelegate.selectedArea != selectedArea;
  }
}
