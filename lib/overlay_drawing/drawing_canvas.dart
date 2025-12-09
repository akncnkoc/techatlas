import 'package:flutter/material.dart';

/// Çizim noktası
class DrawPoint {
  final Offset offset;
  final Color color;
  final double width;
  final bool isEraser;

  DrawPoint({
    required this.offset,
    required this.color,
    required this.width,
    this.isEraser = false,
  });
}

/// Çizim stroke'u (bir çizgi)
class DrawStroke {
  final List<DrawPoint> points;
  final Color color;
  final double width;
  final bool isEraser;

  DrawStroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });
}

/// Sistem genelinde çizim yapılabilen canvas
class DrawingCanvas extends StatefulWidget {
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  const DrawingCanvas({
    super.key,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  final List<DrawStroke> _strokes = [];
  List<DrawPoint> _currentPoints = [];

  /// Geri al
  void undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  /// Temizle
  void clear() {
    setState(() {
      _strokes.clear();
      _currentPoints = [];
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentPoints = [
        DrawPoint(
          offset: details.localPosition,
          color: widget.color,
          width: widget.strokeWidth,
          isEraser: widget.isEraser,
        ),
      ];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPoints.add(
        DrawPoint(
          offset: details.localPosition,
          color: widget.color,
          width: widget.strokeWidth,
          isEraser: widget.isEraser,
        ),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (_currentPoints.isNotEmpty) {
        _strokes.add(
          DrawStroke(
            points: List.from(_currentPoints),
            color: widget.color,
            width: widget.strokeWidth,
            isEraser: widget.isEraser,
          ),
        );
        _currentPoints = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: DrawingPainter(
            strokes: _strokes,
            currentPoints: _currentPoints,
            currentColor: widget.color,
            currentWidth: widget.strokeWidth,
            isEraser: widget.isEraser,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Çizimleri render eden painter
class DrawingPainter extends CustomPainter {
  final List<DrawStroke> strokes;
  final List<DrawPoint> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;

  DrawingPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Tamamlanmış stroke'ları çiz
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width, stroke.isEraser);
    }

    // Aktif stroke'u çiz
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, currentWidth, isEraser);
    }
  }

  void _drawStroke(Canvas canvas, List<DrawPoint> points, Color color, double width, bool isEraser) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (isEraser) {
      // Silgi için blend mode
      paint.blendMode = BlendMode.clear;
      paint.color = Colors.transparent;
    } else {
      paint.color = color;
    }

    final path = Path();
    path.moveTo(points.first.offset.dx, points.first.offset.dy);

    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1].offset;
      final p2 = points[i].offset;

      // Smooth curve için quadratic bezier
      final midPoint = Offset(
        (p1.dx + p2.dx) / 2,
        (p1.dy + p2.dy) / 2,
      );

      path.quadraticBezierTo(p1.dx, p1.dy, midPoint.dx, midPoint.dy);
    }

    // Son noktaya
    if (points.length > 1) {
      final lastPoint = points.last.offset;
      path.lineTo(lastPoint.dx, lastPoint.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
   return true;
  }
}
