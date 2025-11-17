import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Simplifies stroke paths using the Douglas-Peucker algorithm
/// This reduces the number of points while maintaining visual fidelity
class StrokeSimplifier {
  StrokeSimplifier._();

  /// Simplifies a list of points using the Douglas-Peucker algorithm
  /// [points] - The original list of points
  /// [tolerance] - Maximum distance a point can be from the simplified line
  /// Returns a simplified list of points
  static List<Offset> simplify(List<Offset> points, double tolerance) {
    if (points.length < 3) return List.from(points);

    return _douglasPeucker(points, tolerance);
  }

  static List<Offset> _douglasPeucker(List<Offset> points, double tolerance) {
    if (points.length < 3) return points;

    // Find the point with the maximum distance from the line
    double maxDistance = 0;
    int index = 0;

    final start = points.first;
    final end = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      // Recursive call
      final leftSegment = _douglasPeucker(
        points.sublist(0, index + 1),
        tolerance,
      );
      final rightSegment = _douglasPeucker(
        points.sublist(index),
        tolerance,
      );

      // Combine results (remove duplicate point at the junction)
      return [...leftSegment.sublist(0, leftSegment.length - 1), ...rightSegment];
    } else {
      // If max distance is less than tolerance, remove all points between
      return [start, end];
    }
  }

  /// Calculates the perpendicular distance from a point to a line segment
  static double _perpendicularDistance(Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;

    // Normalize
    final magnitude = math.sqrt(dx * dx + dy * dy);
    if (magnitude == 0) {
      return (point - lineStart).distance;
    }

    final u = ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) / (magnitude * magnitude);

    // Closest point on the line segment
    final closestPoint = u < 0
        ? lineStart
        : u > 1
            ? lineEnd
            : Offset(
                lineStart.dx + u * dx,
                lineStart.dy + u * dy,
              );

    return (point - closestPoint).distance;
  }

  /// Fast simplification using a fixed distance threshold
  /// Useful for real-time drawing where Douglas-Peucker might be too slow
  static List<Offset> simplifyByDistance(List<Offset> points, double minDistance) {
    if (points.length < 2) return List.from(points);

    final simplified = <Offset>[points.first];
    var lastPoint = points.first;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = (points[i] - lastPoint).distance;
      if (distance >= minDistance) {
        simplified.add(points[i]);
        lastPoint = points[i];
      }
    }

    // Always include the last point
    if (points.isNotEmpty && points.last != lastPoint) {
      simplified.add(points.last);
    }

    return simplified;
  }
}
