import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  State<MagnifiedContentOverlay> createState() => _MagnifiedContentOverlayState();
}

class _MagnifiedContentOverlayState extends State<MagnifiedContentOverlay> {
  ui.Image? _capturedImage;
  bool _isCapturing = true;
  double _capturePixelRatio = 1.0;

  @override
  void initState() {
    super.initState();
    _captureContent();
  }

  Future<void> _captureContent() async {
    // Wait for the next frame to ensure RepaintBoundary is rendered
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    try {
      // Get the RenderObject from the RepaintBoundary
      final renderObject = widget.contentKey.currentContext?.findRenderObject();

      print('🔍 Capturing content...');
      print('   Context: ${widget.contentKey.currentContext != null ? "✓" : "✗"}');
      print('   RenderObject: ${renderObject != null ? "✓" : "✗"}');
      print('   Is RepaintBoundary: ${renderObject is RenderRepaintBoundary ? "✓" : "✗"}');

      if (renderObject is! RenderRepaintBoundary) {
        print('❌ RenderObject is not a RepaintBoundary!');
        if (!mounted) return;
        setState(() => _isCapturing = false);
        return;
      }

      final boundary = renderObject;

      // Capture the image at high pixel ratio for better quality
      // Use higher pixel ratio to get crisp magnified image
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      final capturePixelRatio = (devicePixelRatio * widget.magnification).clamp(2.0, 6.0);
      print('   Device pixel ratio: ${devicePixelRatio}x');
      print('   Capturing at ${capturePixelRatio}x pixel ratio for magnification...');

      final image = await boundary.toImage(pixelRatio: capturePixelRatio);

      if (!mounted) return;

      setState(() {
        _capturedImage = image;
        _capturePixelRatio = capturePixelRatio;
        _isCapturing = false;
      });

      print('✅ Content captured successfully: ${image.width}x${image.height}');
      print('   Selected area: ${widget.selectedArea}');
      print('   Capture pixel ratio: ${capturePixelRatio}x');
    } catch (e, stackTrace) {
      print('❌ Error capturing content: $e');
      print('   Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _capturedImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Calculate the size of the magnified view
    final magnifiedWidth = (widget.selectedArea.width * widget.magnification)
        .clamp(200.0, screenSize.width * 0.9);
    final magnifiedHeight = (widget.selectedArea.height * widget.magnification)
        .clamp(200.0, screenSize.height * 0.9);

    return Stack(
      children: [
        // Semi-transparent background overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),
        ),

        // Magnified content
        Center(
          child: Container(
            width: magnifiedWidth,
            height: magnifiedHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // Magnified content
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
                    CustomPaint(
                      painter: _MagnifiedImagePainter(
                        image: _capturedImage!,
                        sourceRect: widget.selectedArea,
                        capturePixelRatio: _capturePixelRatio,
                      ),
                      size: Size(magnifiedWidth, magnifiedHeight),
                    )
                  else
                    const Center(
                      child: Text(
                        'İçerik yakalanamadı',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
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
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
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
                ],
              ),
            ),
          ),
        ),

        // Info text at bottom
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Büyütme: ${widget.magnification.toStringAsFixed(1)}x • Kapatmak için tıklayın',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
    canvas.drawImageRect(
      image,
      clampedSourceRect,
      destRect,
      paint,
    );
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

  MagnifierSelectionPainter({
    required this.selectedArea,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw semi-transparent overlay except for selected area
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Draw overlay on the entire canvas
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);

    // Clear the selected area (cut out the rectangle)
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear;
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
