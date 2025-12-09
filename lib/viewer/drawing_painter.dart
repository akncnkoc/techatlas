import 'package:flutter/material.dart';
import 'stroke.dart';
import 'dart:math' as math;

class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;

  DrawingPainter({required this.strokes});

  // Cache Paint objects to avoid recreating them
  final Map<String, Paint> _paintCache = {};

  Paint _getPaint(Stroke stroke) {
    final key =
        '${stroke.color.r}_${stroke.color.g}_${stroke.color.b}_${stroke.width}_${stroke.isHighlighter}';

    return _paintCache.putIfAbsent(key, () {
      return Paint()
        ..color = stroke.isHighlighter
            ? stroke.color.withValues(alpha: 0.4)
            : stroke.color
        ..strokeWidth = stroke.isHighlighter ? stroke.width * 2.5 : stroke.width
        ..strokeCap = stroke.isHighlighter ? StrokeCap.square : StrokeCap.round
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
        case StrokeType.triangle:
          _drawTriangle(canvas, stroke, paint);
          break;
        case StrokeType.star:
          _drawStar(canvas, stroke, paint);
          break;
        case StrokeType.pentagon:
          _drawPentagon(canvas, stroke, paint);
          break;
        case StrokeType.hexagon:
          _drawHexagon(canvas, stroke, paint);
          break;
        case StrokeType.ellipse:
          _drawEllipse(canvas, stroke, paint);
          break;
        case StrokeType.doubleArrow:
          _drawDoubleArrow(canvas, stroke, paint);
          break;
      }
    }
  }

  void _drawFreehand(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.isEmpty) return;
    canvas.drawPath(stroke.path, paint);
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

  void _drawTriangle(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      final start = stroke.points.first;
      final end = stroke.points.last;

      final path = Path();
      // Top point
      path.moveTo((start.dx + end.dx) / 2, start.dy);
      // Bottom right
      path.lineTo(end.dx, end.dy);
      // Bottom left
      path.lineTo(start.dx, end.dy);
      // Close path
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawStar(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      final center = Offset(
        (stroke.points.first.dx + stroke.points.last.dx) / 2,
        (stroke.points.first.dy + stroke.points.last.dy) / 2,
      );
      final radius = (stroke.points.first - stroke.points.last).distance / 2;

      final path = Path();
      const points = 5;
      const innerRadiusRatio = 0.4;

      for (int i = 0; i < points * 2; i++) {
        final angle = (i * math.pi / points) - math.pi / 2;
        final r = (i.isEven ? radius : radius * innerRadiusRatio);
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  void _drawPentagon(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      _drawPolygon(canvas, stroke, paint, 5);
    }
  }

  void _drawHexagon(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      _drawPolygon(canvas, stroke, paint, 6);
    }
  }

  void _drawPolygon(Canvas canvas, Stroke stroke, Paint paint, int sides) {
    final center = Offset(
      (stroke.points.first.dx + stroke.points.last.dx) / 2,
      (stroke.points.first.dy + stroke.points.last.dy) / 2,
    );
    final radius = (stroke.points.first - stroke.points.last).distance / 2;

    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * math.pi / sides) - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawEllipse(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      final rect = Rect.fromPoints(stroke.points.first, stroke.points.last);
      canvas.drawOval(rect, paint);
    }
  }

  void _drawDoubleArrow(Canvas canvas, Stroke stroke, Paint paint) {
    if (stroke.points.length >= 2) {
      final start = stroke.points.first;
      final end = stroke.points.last;

      // Draw main line
      canvas.drawLine(start, end, paint);

      // Calculate arrow heads
      const arrowLength = 20.0;
      const arrowAngle = 25.0 * math.pi / 180;

      final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);

      // Arrow head at end
      final arrowPoint1 = Offset(
        end.dx - arrowLength * math.cos(angle - arrowAngle),
        end.dy - arrowLength * math.sin(angle - arrowAngle),
      );
      final arrowPoint2 = Offset(
        end.dx - arrowLength * math.cos(angle + arrowAngle),
        end.dy - arrowLength * math.sin(angle + arrowAngle),
      );
      canvas.drawLine(end, arrowPoint1, paint);
      canvas.drawLine(end, arrowPoint2, paint);

      // Arrow head at start (pointing opposite direction)
      final arrowPoint3 = Offset(
        start.dx + arrowLength * math.cos(angle - arrowAngle),
        start.dy + arrowLength * math.sin(angle - arrowAngle),
      );
      final arrowPoint4 = Offset(
        start.dx + arrowLength * math.cos(angle + arrowAngle),
        start.dy + arrowLength * math.sin(angle + arrowAngle),
      );
      canvas.drawLine(start, arrowPoint3, paint);
      canvas.drawLine(start, arrowPoint4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    return true;
  }
}

class HistoryPainter extends DrawingPainter {
  final int repaintVersion;

  HistoryPainter({required super.strokes, required this.repaintVersion});

  @override
  bool shouldRepaint(covariant HistoryPainter oldDelegate) {
    // Repaint if the version changed (triggered by _historyNotifier)
    if (repaintVersion != oldDelegate.repaintVersion) {
      return true;
    }

    // Fallback: Check if list instance or length changed
    if (identical(strokes, oldDelegate.strokes)) {
      return strokes.length != oldDelegate.strokes.length;
    }
    return true;
  }
}

class ActiveStrokePainter extends DrawingPainter {
  final Stroke? activeStroke;

  ActiveStrokePainter({this.activeStroke}) : super(strokes: []);

  @override
  void paint(Canvas canvas, Size size) {
    if (activeStroke == null || activeStroke!.points.isEmpty) return;

    final paint = _getPaint(activeStroke!);

    switch (activeStroke!.type) {
      case StrokeType.freehand:
        _drawFreehand(canvas, activeStroke!, paint);
        break;
      case StrokeType.rectangle:
        _drawRectangle(canvas, activeStroke!, paint);
        break;
      case StrokeType.circle:
        _drawCircle(canvas, activeStroke!, paint);
        break;
      case StrokeType.line:
        _drawLine(canvas, activeStroke!, paint);
        break;
      case StrokeType.arrow:
        _drawArrow(canvas, activeStroke!, paint);
        break;
      case StrokeType.triangle:
        _drawTriangle(canvas, activeStroke!, paint);
        break;
      case StrokeType.star:
        _drawStar(canvas, activeStroke!, paint);
        break;
      case StrokeType.pentagon:
        _drawPentagon(canvas, activeStroke!, paint);
        break;
      case StrokeType.hexagon:
        _drawHexagon(canvas, activeStroke!, paint);
        break;
      case StrokeType.ellipse:
        _drawEllipse(canvas, activeStroke!, paint);
        break;
      case StrokeType.doubleArrow:
        _drawDoubleArrow(canvas, activeStroke!, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ActiveStrokePainter oldDelegate) {
    // Always repaint active stroke as it changes continuously during drawing
    return true;
  }
}
