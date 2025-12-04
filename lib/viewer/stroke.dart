import 'package:flutter/material.dart';

enum StrokeType {
  freehand,
  rectangle,
  circle,
  arrow,
  line,
  triangle,
  star,
  pentagon,
  hexagon,
  ellipse,
  doubleArrow,
}

class Stroke {
  final List<Offset> _points;
  List<Offset> get points => _points;

  final Color color;
  final double width;
  final bool erase;
  final bool isHighlighter;
  StrokeType type;

  Path? _path;

  Stroke({
    required this.color,
    required this.width,
    required this.erase,
    this.isHighlighter = false,
    this.type = StrokeType.freehand,
  }) : _points = [];

  Stroke.shape({
    required this.color,
    required this.width,
    required this.type,
    required List<Offset> shapePoints,
    this.isHighlighter = false,
  }) : _points = List.from(shapePoints),
       erase = false;

  void addPoint(Offset point) {
    _points.add(point);
    _path = null; // Invalidate cache
  }

  Path get path {
    if (_path != null) return _path!;

    final path = Path();
    if (_points.isEmpty) {
      _path = path;
      return path;
    }

    if (_points.length == 1) {
      // Draw a dot for a single point
      path.addOval(Rect.fromCircle(center: _points.first, radius: width / 2));
    } else if (_points.length == 2) {
      // Draw a line for 2 points
      path.moveTo(_points.first.dx, _points.first.dy);
      path.lineTo(_points.last.dx, _points.last.dy);
    } else {
      // Quadratic bezier for smooth curves
      path.moveTo(_points.first.dx, _points.first.dy);
      for (int i = 1; i < _points.length - 1; i++) {
        final current = _points[i];
        final next = _points[i + 1];
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
      final lastPoint = _points.last;
      path.lineTo(lastPoint.dx, lastPoint.dy);
    }

    _path = path;
    return path;
  }
}
