import 'package:flutter/material.dart';

enum StrokeType { freehand, rectangle, circle, arrow, line }

class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool erase;
  final StrokeType type;

  Stroke({
    required this.color,
    required this.width,
    required this.erase,
    this.type = StrokeType.freehand,
  }) : points = [];

  Stroke.shape({
    required this.color,
    required this.width,
    required this.type,
    required List<Offset> shapePoints,
  }) : points = List.from(shapePoints),
       erase = false;
}
