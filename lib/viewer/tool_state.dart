import 'package:flutter/material.dart';

enum ShapeType { rectangle, circle, arrow, line }

class ToolState {
  final bool eraser;
  final bool pencil;
  final bool grab;
  final bool shape;
  final ShapeType selectedShape;
  final Color color;
  final double width;

  const ToolState({
    required this.eraser,
    required this.pencil,
    required this.grab,
    required this.shape,
    required this.selectedShape,
    required this.color,
    required this.width,
  });

  ToolState copyWith({
    bool? eraser,
    bool? pencil,
    bool? grab,
    bool? shape,
    ShapeType? selectedShape,
    Color? color,
    double? width,
  }) {
    return ToolState(
      eraser: eraser ?? this.eraser,
      pencil: pencil ?? this.pencil,
      grab: grab ?? this.grab,
      shape: shape ?? this.shape,
      selectedShape: selectedShape ?? this.selectedShape,
      color: color ?? this.color,
      width: width ?? this.width,
    );
  }
}
