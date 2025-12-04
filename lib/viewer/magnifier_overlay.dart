import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class MagnifierOverlay extends StatelessWidget {
  final Offset? position;
  final Rect? selectedArea;
  final Widget child;
  final double magnification;
  final Size? magnifierSize;

  const MagnifierOverlay({
    super.key,
    this.position,
    this.selectedArea,
    required this.child,
    this.magnification = 2.0,
    this.magnifierSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (selectedArea != null)
          Positioned.fill(
            child: CustomPaint(
              painter: MagnifierPainter(
                selectedArea: selectedArea!,
                magnification: magnification,
              ),
            ),
          ),
        if (position != null && selectedArea == null)
          Positioned(
            left: position!.dx - 75,
            top: position!.dy - 75,
            child: IgnorePointer(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(child: Container(color: Colors.transparent)),
              ),
            ),
          ),
      ],
    );
  }
}

class MagnifierPainter extends CustomPainter {
  final Rect selectedArea;
  final double magnification;

  MagnifierPainter({required this.selectedArea, required this.magnification});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a path for the overlay (entire screen minus selected area)
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(selectedArea)
      ..fillType = PathFillType.evenOdd;

    // Draw semi-transparent overlay except for selected area
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // Draw gradient border around selected area
    final borderPaint = Paint()
      ..shader = ui.Gradient.linear(
        selectedArea.topLeft,
        selectedArea.bottomRight,
        [const Color(0xFF2196F3), const Color(0xFF1976D2)],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRect(selectedArea, borderPaint);

    // Inner glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFF2196F3).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(selectedArea, glowPaint);

    // Draw corner handles with gradient
    final handleSize = 14.0;
    final corners = [
      selectedArea.topLeft,
      selectedArea.topRight,
      selectedArea.bottomLeft,
      selectedArea.bottomRight,
    ];

    for (final corner in corners) {
      // Outer glow
      canvas.drawCircle(
        corner,
        handleSize / 2 + 2,
        Paint()
          ..color = const Color(0xFF2196F3).withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // Gradient fill
      final gradientPaint = Paint()
        ..shader = ui.Gradient.radial(corner, handleSize / 2, [
          const Color(0xFF64B5F6),
          const Color(0xFF2196F3),
        ]);
      canvas.drawCircle(corner, handleSize / 2, gradientPaint);

      // White border
      canvas.drawCircle(
        corner,
        handleSize / 2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(MagnifierPainter oldDelegate) {
    return oldDelegate.selectedArea != selectedArea ||
        oldDelegate.magnification != magnification;
  }
}

class MagnifierState {
  Offset? startPoint;
  Offset? currentPoint;
  Rect? selectedArea;
  bool isSelecting;
  bool isResizing;
  String? resizeHandle; // 'topLeft', 'topRight', 'bottomLeft', 'bottomRight'

  MagnifierState({
    this.startPoint,
    this.currentPoint,
    this.selectedArea,
    this.isSelecting = false,
    this.isResizing = false,
    this.resizeHandle,
  });

  Rect? getSelectionRect() {
    if (startPoint == null || currentPoint == null) return null;

    final left = startPoint!.dx < currentPoint!.dx
        ? startPoint!.dx
        : currentPoint!.dx;
    final top = startPoint!.dy < currentPoint!.dy
        ? startPoint!.dy
        : currentPoint!.dy;
    final right = startPoint!.dx > currentPoint!.dx
        ? startPoint!.dx
        : currentPoint!.dx;
    final bottom = startPoint!.dy > currentPoint!.dy
        ? startPoint!.dy
        : currentPoint!.dy;

    return Rect.fromLTRB(left, top, right, bottom);
  }

  String? getHandleAtPosition(Offset position) {
    if (selectedArea == null) return null;

    final handleSize = 20.0; // Hit area for handles

    if ((position - selectedArea!.topLeft).distance < handleSize) {
      return 'topLeft';
    } else if ((position - selectedArea!.topRight).distance < handleSize) {
      return 'topRight';
    } else if ((position - selectedArea!.bottomLeft).distance < handleSize) {
      return 'bottomLeft';
    } else if ((position - selectedArea!.bottomRight).distance < handleSize) {
      return 'bottomRight';
    }

    return null;
  }

  bool isPointInSelectedArea(Offset position) {
    if (selectedArea == null) return false;
    return selectedArea!.contains(position);
  }

  MagnifierState copyWith({
    Offset? startPoint,
    Offset? currentPoint,
    Rect? selectedArea,
    bool? isSelecting,
    bool? isResizing,
    String? resizeHandle,
    bool clearStartPoint = false,
    bool clearCurrentPoint = false,
    bool clearSelectedArea = false,
    bool clearResizeHandle = false,
  }) {
    return MagnifierState(
      startPoint: clearStartPoint ? null : (startPoint ?? this.startPoint),
      currentPoint: clearCurrentPoint
          ? null
          : (currentPoint ?? this.currentPoint),
      selectedArea: clearSelectedArea
          ? null
          : (selectedArea ?? this.selectedArea),
      isSelecting: isSelecting ?? this.isSelecting,
      isResizing: isResizing ?? this.isResizing,
      resizeHandle: clearResizeHandle
          ? null
          : (resizeHandle ?? this.resizeHandle),
    );
  }
}
