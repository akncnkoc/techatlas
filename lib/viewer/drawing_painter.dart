import 'package:flutter/material.dart';
import 'stroke.dart';
import 'dart:math' as math;

class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;

  DrawingPainter({required this.strokes});

  // Cache Paint objects to avoid recreating them
  final Map<String, Paint> _paintCache = {};

  Paint _getPaint(Stroke stroke) {
    final key = '${stroke.color.r}_${stroke.color.g}_${stroke.color.b}_${stroke.width}_${stroke.isHighlighter}';

    return _paintCache.putIfAbsent(key, () {
      return Paint()
        ..color = stroke.isHighlighter
            ? stroke.color.withValues(alpha: 0.4)
            : stroke.color
        ..strokeWidth = stroke.isHighlighter
            ? stroke.width * 2.5
            : stroke.width
        ..strokeCap = stroke.isHighlighter
            ? StrokeCap.square
            : StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true
        ..blendMode = stroke.isHighlighter
            ? BlendMode.multiply
            : BlendMode.srcOver;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = _getPaint(stroke);

      switch (stroke.type) {
        case StrokeType.freehand:
          _drawFreehand(canvas, stroke, paint);
          break;
        case StrokeType.rectangle:
          _drawRectangle(canvas, stroke, paint);
          break;
        case StrokeType.circle:
          _drawCircle(canvas, stroke, paint);
          break;
        case StrokeType.line:
          _drawLine(canvas, stroke, paint);
          break;
        case StrokeType.arrow:
          _drawArrow(canvas, stroke, paint);
          break;
      }
    }
  }

  void _drawFreehand(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
    } else if (stroke.points.length == 2) {
      // 2 nokta varsa düz çizgi çiz
      canvas.drawLine(stroke.points.first, stroke.points.last, paint);
    } else {
      // 3 veya daha fazla nokta için smooth path
      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length - 1; i++) {
        final current = stroke.points[i];
        final next = stroke.points[i + 1];
        final controlPoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          controlPoint.dx,
          controlPoint.dy,
        );
      }

      // Son noktaya çiz
      final lastPoint = stroke.points.last;
      path.lineTo(lastPoint.dx, lastPoint.dy);

      canvas.drawPath(path, paint);
    }
  }

  void _drawRectangle(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      final rect = Rect.fromPoints(stroke.points.first, stroke.points.last);
      canvas.drawRect(rect, paint);
    }
  }

  void _drawCircle(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      final center = stroke.points.first;
      final radius = (stroke.points.first - stroke.points.last).distance;
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _drawLine(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      canvas.drawLine(stroke.points.first, stroke.points.last, paint);
    }
  }

  void _drawArrow(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      final start = stroke.points.first;
      final end = stroke.points.last;

      // Draw main line
      canvas.drawLine(start, end, paint);

      // Calculate arrow head
      const arrowLength = 20.0;
      const arrowAngle = 25.0 * math.pi / 180;

      final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);

      // Arrow head points
      final arrowPoint1 = Offset(
        end.dx - arrowLength * math.cos(angle - arrowAngle),
        end.dy - arrowLength * math.sin(angle - arrowAngle),
      );

      final arrowPoint2 = Offset(
        end.dx - arrowLength * math.cos(angle + arrowAngle),
        end.dy - arrowLength * math.sin(angle + arrowAngle),
      );

      // Draw arrow head
      canvas.drawLine(end, arrowPoint1, paint);
      canvas.drawLine(end, arrowPoint2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    // Always repaint during drawing for real-time feedback
    // This is necessary for active stroke to be visible immediately
    return true;
  }
}
