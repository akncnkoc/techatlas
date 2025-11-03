import 'package:flutter/material.dart';

enum ShapeType { rectangle, circle, arrow, line }

class ToolState {
  final bool eraser;
  final bool pencil;
  final bool highlighter;
  final bool grab;
  final bool mouse;
  final bool shape;
  final bool selection;
  final bool magnifier;
  final ShapeType selectedShape;
  final Color color;
  final double width;

  const ToolState({
    required this.eraser,
    required this.pencil,
    required this.highlighter,
    required this.grab,
    required this.mouse,
    required this.shape,
    required this.selection,
    required this.magnifier,
    required this.selectedShape,
    required this.color,
    required this.width,
  });

  ToolState copyWith({
    bool? eraser,
    bool? pencil,
    bool? highlighter,
    bool? grab,
    bool? mouse,
    bool? shape,
    bool? selection,
    bool? magnifier,
    ShapeType? selectedShape,
    Color? color,
    double? width,
  }) {
    return ToolState(
      eraser: eraser ?? this.eraser,
      pencil: pencil ?? this.pencil,
      highlighter: highlighter ?? this.highlighter,
      grab: grab ?? this.grab,
      mouse: mouse ?? this.mouse,
      shape: shape ?? this.shape,
      selection: selection ?? this.selection,
      magnifier: magnifier ?? this.magnifier,
      selectedShape: selectedShape ?? this.selectedShape,
      color: color ?? this.color,
      width: width ?? this.width,
    );
  }
}
