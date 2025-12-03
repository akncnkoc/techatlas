import 'package:flutter/material.dart';
import 'package:akilli_tahta_proje_demo/viewer/stroke.dart';
import 'package:akilli_tahta_proje_demo/viewer/tool_state.dart';
import 'package:akilli_tahta_proje_demo/viewer/drawing_history.dart';
import 'package:akilli_tahta_proje_demo/core/utils/matrix_utils.dart'
    as custom_matrix;
import '../core/constants/app_constants.dart';
import 'dart:math' show cos, sin;

enum DrawingSurface { pdf, dialog }

class DrawingProvider extends ChangeNotifier {
  // Tool state
  ToolState _toolState = ToolState(
    mouse: true,
    eraser: false,
    pencil: false,
    highlighter: false,
    grab: false,
    shape: false,
    selection: false,
    magnifier: false,
    selectedShape: ShapeType.rectangle,
    color: Colors.red,
    width: 0.7,
  );
  ToolState get toolState => _toolState;

  // Drawing data for both PDF and dialogs
  final Map<int, List<Stroke>> _pageStrokes = {};
  final Map<String, List<Stroke>> _dialogStrokes = {};
  Stroke? activeStroke;
  bool isDrawing = false;

  // History management for both surfaces
  final DrawingHistory<int> _pdfHistory = DrawingHistory();
  final DrawingHistory<String> _dialogHistory = DrawingHistory();
  bool _canUndo = false;
  bool _canRedo = false;
  bool get canUndo => _canUndo;
  bool get canRedo => _canRedo;

  // Active surface management
  int _currentPage = 1;
  int get currentPage => _currentPage;
  DrawingSurface _activeSurface = DrawingSurface.pdf;
  String? _activeDialogImageKey;

  // Zoom & Rotation State
  double _scale = 1.0;
  double _rotationAngle = 0.0;
  final double _minZoom = AppConstants.minZoom;
  final double _maxZoom = AppConstants.maxZoom;

  double get zoomLevel => _scale;
  double get rotationAngle => _rotationAngle;

  List<Stroke> get strokesForCurrentPage {
    if (_activeSurface == DrawingSurface.dialog && _activeDialogImageKey != null) {
      return _dialogStrokes[_activeDialogImageKey!] ?? [];
    }
    return _pageStrokes[_currentPage] ?? [];
  }

  // --- Point Transformation ---
  Offset _transformPoint(
      TransformationController controller, Offset screenPoint) {
    // GestureDetector is OUTSIDE InteractiveViewer
    // So we receive screen coordinates and need to convert to content coordinates
    // This requires inverse of the transformation matrix
    return custom_matrix.MatrixUtils.transformPoint(
        controller.value, screenPoint);
  }

  // --- Tool State Methods ---
  void setTool(ToolState Function(ToolState) updater) {
    final newState = updater(_toolState);
    // Optimize: Only notify if state actually changed
    if (newState != _toolState) {
      _toolState = newState;
      notifyListeners();
    }
  }

  void setColor(Color color) {
    // Optimize: Only update if color changed
    if (_toolState.color == color) return;

    _toolState = _toolState.copyWith(
      color: color,
      pencil: !_toolState.shape && !_toolState.highlighter,
      highlighter: _toolState.highlighter,
      shape: _toolState.shape,
      eraser: false,
      grab: false,
      mouse: false,
      selection: false,
      magnifier: false,
    );
    notifyListeners();
  }

  void setWidth(double width) {
    // Optimize: Only update if width changed
    if (_toolState.width == width) return;

    _toolState = _toolState.copyWith(width: width);
    notifyListeners();
  }

  // --- Drawing Methods ---
  void startStroke(Offset position, TransformationController controller) {
    if (isDrawing) return;

    final transformedPosition = _transformPoint(controller, position);
    isDrawing = true;

    List<Stroke> strokes;
    if (_activeSurface == DrawingSurface.dialog && _activeDialogImageKey != null) {
      strokes = _dialogStrokes.putIfAbsent(_activeDialogImageKey!, () => []);
      // İlk çizimse boş durumu kaydet
      if (!_dialogHistory.canUndo(_activeDialogImageKey!) && !_dialogHistory.canRedo(_activeDialogImageKey!)) {
        _dialogHistory.saveState(_activeDialogImageKey!, []);
        _updateUndoRedoState();
      }
    } else {
      strokes = _pageStrokes.putIfAbsent(_currentPage, () => []);
      // İlk çizimse boş durumu kaydet
      if (!_pdfHistory.canUndo(_currentPage) && !_pdfHistory.canRedo(_currentPage)) {
        _pdfHistory.saveState(_currentPage, []);
        _updateUndoRedoState();
      }
    }

    if (_toolState.eraser) {
      activeStroke = Stroke(
        color: _toolState.color,
        width: _toolState.width,
        erase: true,
      );
      activeStroke!.points.add(transformedPosition);
      _eraseAt(transformedPosition, _toolState.width * 15); // Eraser radius 15x width (daha büyük alan)
    } else {
      activeStroke = Stroke(
        color: _toolState.color,
        width: _toolState.width,
        erase: false,
        isHighlighter: _toolState.highlighter,
      );
      activeStroke!.points.add(transformedPosition);
      strokes.add(activeStroke!);
    }
    notifyListeners();
  }

  void updateStroke(Offset position, TransformationController controller) {
    if (!isDrawing || activeStroke == null) return;

    final transformedPosition = _transformPoint(controller, position);
    activeStroke!.points.add(transformedPosition);
    if (_toolState.eraser) {
      _eraseAt(transformedPosition, _toolState.width * 15); // Daha büyük silgi alanı
    }
    notifyListeners();
  }

  void endStroke() {
    if (!isDrawing) return;

    activeStroke = null;
    isDrawing = false;
    _saveToHistory();
    notifyListeners();
  }

  void cancelStroke() {
    if (!isDrawing) return;
    if (activeStroke != null) {
      strokesForCurrentPage.remove(activeStroke);
    }
    activeStroke = null;
    isDrawing = false;
    notifyListeners();
  }

  void _eraseAt(Offset position, double eraserRadius) {
    final List<Stroke> currentStrokes = strokesForCurrentPage;
    final List<Stroke> newStrokes = [];

    for (final stroke in currentStrokes) {
      if (stroke.erase) continue;

      if (stroke.type != StrokeType.freehand) {
        // Shape erasure: expand to points and check for partial erasure
        final List<Offset> shapePoints = _expandShapeToPoints(stroke);
        final List<Offset> remainingPoints = [];
        final List<List<Offset>> segments = [];

        // Optimize: Use squared distance to avoid expensive sqrt()
        final eraserRadiusSq = eraserRadius * eraserRadius * 0.64; // 0.8^2 = 0.64

        for (int i = 0; i < shapePoints.length; i++) {
          final point = shapePoints[i];
          final dx = point.dx - position.dx;
          final dy = point.dy - position.dy;
          final distanceSq = dx * dx + dy * dy; // No sqrt() - much faster

          if (distanceSq >= eraserRadiusSq) {
            remainingPoints.add(point);
          } else {
            if (remainingPoints.isNotEmpty) {
              segments.add(List.from(remainingPoints));
              remainingPoints.clear();
            }
          }
        }

        if (remainingPoints.isNotEmpty) {
          segments.add(remainingPoints);
        }

        // Convert segments back to freehand strokes
        for (final segment in segments) {
          if (segment.length > 1) {
            final newStroke = Stroke(
              color: stroke.color,
              width: stroke.width,
              erase: false,
              isHighlighter: stroke.isHighlighter,
            );
            newStroke.points.addAll(segment);
            newStrokes.add(newStroke);
          }
        }
        continue;
      }

      // Freehand stroke erasure: break into segments
      final List<Offset> remainingPoints = [];
      final List<List<Offset>> segments = [];

      // Optimize: Use squared distance to avoid expensive sqrt()
      final eraserRadiusSq = eraserRadius * eraserRadius * 0.64; // 0.8^2 = 0.64

      for (int i = 0; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        final dx = point.dx - position.dx;
        final dy = point.dy - position.dy;
        final distanceSq = dx * dx + dy * dy; // No sqrt() - much faster

        if (distanceSq >= eraserRadiusSq) {
          remainingPoints.add(point);
        } else {
          if (remainingPoints.isNotEmpty) {
            segments.add(List.from(remainingPoints));
            remainingPoints.clear();
          }
        }
      }

      if (remainingPoints.isNotEmpty) {
        segments.add(remainingPoints);
      }

      for (final segment in segments) {
        if (segment.length > 1) { // Only add segments with more than one point
          final newStroke = Stroke(
            color: stroke.color,
            width: stroke.width,
            erase: false,
            isHighlighter: stroke.isHighlighter,
          );
          newStroke.points.addAll(segment);
          newStrokes.add(newStroke);
        }
      }
    }
    // Update the strokes list directly
    if (_activeSurface == DrawingSurface.dialog && _activeDialogImageKey != null) {
      _dialogStrokes[_activeDialogImageKey!] = newStrokes;
    } else {
      _pageStrokes[_currentPage] = newStrokes;
    }
  }

  List<Offset> _expandShapeToPoints(Stroke stroke) {
    if (stroke.points.length < 2) return stroke.points;

    final p1 = stroke.points[0];
    final p2 = stroke.points[1];
    final List<Offset> expandedPoints = [];

    switch (stroke.type) {
      case StrokeType.line:
      case StrokeType.arrow:
      case StrokeType.doubleArrow:
        expandedPoints.addAll(_interpolateLine(p1, p2));
        break;

      case StrokeType.rectangle:
        final rect = Rect.fromPoints(p1, p2);
        expandedPoints.addAll(_interpolateLine(rect.topLeft, rect.topRight));
        expandedPoints.addAll(_interpolateLine(rect.topRight, rect.bottomRight));
        expandedPoints.addAll(_interpolateLine(rect.bottomRight, rect.bottomLeft));
        expandedPoints.addAll(_interpolateLine(rect.bottomLeft, rect.topLeft));
        break;

      case StrokeType.circle:
        final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final radius = (p2 - p1).distance / 2;
        // Optimize: Reduce points from radius*2 to max(16, radius/5)
        // This gives 16-200 points instead of 100-2000 points
        final steps = (radius / 5).ceil().clamp(16, 200);

        for (int i = 0; i < steps; i++) {
          final angle = (i / steps) * 2 * 3.14159;
          expandedPoints.add(
            Offset(
              center.dx + radius * cos(angle),
              center.dy + radius * sin(angle),
            ),
          );
        }
        break;

      case StrokeType.ellipse:
        final rect = Rect.fromPoints(p1, p2);
        final center = rect.center;
        final radiusX = rect.width / 2;
        final radiusY = rect.height / 2;
        // Optimize: Reduce points similar to circle
        final steps = ((radiusX + radiusY) / 5).ceil().clamp(16, 200);

        for (int i = 0; i < steps; i++) {
          final angle = (i / steps) * 2 * 3.14159;
          expandedPoints.add(
            Offset(
              center.dx + radiusX * cos(angle),
              center.dy + radiusY * sin(angle),
            ),
          );
        }
        break;

      case StrokeType.triangle:
        final top = Offset((p1.dx + p2.dx) / 2, p1.dy);
        final bottomRight = Offset(p2.dx, p2.dy);
        final bottomLeft = Offset(p1.dx, p2.dy);

        expandedPoints.addAll(_interpolateLine(top, bottomRight));
        expandedPoints.addAll(_interpolateLine(bottomRight, bottomLeft));
        expandedPoints.addAll(_interpolateLine(bottomLeft, top));
        break;

      case StrokeType.star:
        final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final radius = (p2 - p1).distance / 2;
        const points = 5;
        const innerRadiusRatio = 0.4;

        for (int i = 0; i < points * 2; i++) {
          final angle = (i * 3.14159 / points) - 3.14159 / 2;
          final r = (i.isEven ? radius : radius * innerRadiusRatio);
          final current = Offset(
            center.dx + r * cos(angle),
            center.dy + r * sin(angle),
          );

          final nextAngle = ((i + 1) * 3.14159 / points) - 3.14159 / 2;
          final nextR = ((i + 1).isEven ? radius : radius * innerRadiusRatio);
          final next = Offset(
            center.dx + nextR * cos(nextAngle),
            center.dy + nextR * sin(nextAngle),
          );

          expandedPoints.addAll(_interpolateLine(current, next));
        }
        break;

      case StrokeType.pentagon:
        expandedPoints.addAll(_expandPolygon(p1, p2, 5));
        break;

      case StrokeType.hexagon:
        expandedPoints.addAll(_expandPolygon(p1, p2, 6));
        break;

      default:
        expandedPoints.addAll(stroke.points);
    }

    return expandedPoints;
  }

  List<Offset> _expandPolygon(Offset p1, Offset p2, int sides) {
    final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final radius = (p2 - p1).distance / 2;
    final List<Offset> expandedPoints = [];

    for (int i = 0; i < sides; i++) {
      final angle = (i * 2 * 3.14159 / sides) - 3.14159 / 2;
      final nextAngle = ((i + 1) * 2 * 3.14159 / sides) - 3.14159 / 2;

      final current = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      final next = Offset(
        center.dx + radius * cos(nextAngle),
        center.dy + radius * sin(nextAngle),
      );

      expandedPoints.addAll(_interpolateLine(current, next));
    }

    return expandedPoints;
  }

  List<Offset> _interpolateLine(Offset start, Offset end) {
    final List<Offset> points = [];
    // Optimize: Reduce from distance/2 to distance/5
    // This gives 5px spacing instead of 2px - still smooth but 60% fewer points
    final steps = ((end - start).distance / 5).ceil().clamp(2, 100);

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      points.add(
        Offset(
          start.dx + (end.dx - start.dx) * t,
          start.dy + (end.dy - start.dy) * t,
        ),
      );
    }

    return points;
  }


  // --- View Control Methods ---
  void setScale(double newScale) {
    _scale = newScale.clamp(_minZoom, _maxZoom);
    notifyListeners();
  }

  void zoomIn() {
    setScale(_scale * 1.2);
  }

  void zoomOut() {
    setScale(_scale / 1.2);
  }

  void resetZoom() {
    setScale(1.0);
  }

  void setRotationAngle(double angle) {
    _rotationAngle = angle;
    notifyListeners();
  }

  void rotateLeft() {
    setRotationAngle(_rotationAngle - (1.5708)); // -90 degrees in radians
  }

  void rotateRight() {
    setRotationAngle(_rotationAngle + (1.5708)); // +90 degrees in radians
  }

  void resetRotation() {
    setRotationAngle(0.0);
  }


  // --- Surface and History Methods ---
  void setActiveDialogSurface(String imageKey) {
    _activeSurface = DrawingSurface.dialog;
    _activeDialogImageKey = imageKey;
    _updateUndoRedoState();
    notifyListeners();
  }

  void clearActiveDialogSurface() {
    _activeSurface = DrawingSurface.pdf;
    _activeDialogImageKey = null;
    _updateUndoRedoState();
    notifyListeners();
  }

  void setCurrentPage(int page) {
    if (_currentPage == page || _activeSurface != DrawingSurface.pdf) return;
    _currentPage = page;
    _updateUndoRedoState();
    notifyListeners();
  }

  void _saveToHistory() {
    if (_activeSurface == DrawingSurface.dialog && _activeDialogImageKey != null) {
      _dialogHistory.saveState(_activeDialogImageKey!, _dialogStrokes[_activeDialogImageKey!] ?? []);
    } else {
      _pdfHistory.saveState(_currentPage, _pageStrokes[_currentPage] ?? []);
    }
    _updateUndoRedoState();
  }

  void _updateUndoRedoState() {
    bool oldCanUndo = _canUndo;
    bool oldCanRedo = _canRedo;

    if (_activeSurface == DrawingSurface.dialog && _activeDialogImageKey != null) {
      _canUndo = _dialogHistory.canUndo(_activeDialogImageKey!);
      _canRedo = _dialogHistory.canRedo(_activeDialogImageKey!);
    } else {
      _canUndo = _pdfHistory.canUndo(_currentPage);
      _canRedo = _pdfHistory.canRedo(_currentPage);
    }

    // Sadece durum değiştiyse notify et
    if (oldCanUndo != _canUndo || oldCanRedo != _canRedo) {
      notifyListeners();
    }
  }

  void undo() {
    List<Stroke>? previousState;
    if (_activeSurface == DrawingSurface.dialog && _activeDialogImageKey != null) {
      previousState = _dialogHistory.undo(_activeDialogImageKey!);
      if (previousState != null) {
        _dialogStrokes[_activeDialogImageKey!] = previousState;
      }
    } else {
      previousState = _pdfHistory.undo(_currentPage);
      if (previousState != null) {
        _pageStrokes[_currentPage] = previousState;
      }
    }
    
    if (previousState != null) {
      _updateUndoRedoState();
      notifyListeners();
    }
  }

  void redo() {
    List<Stroke>? nextState;
    if (_activeSurface == DrawingSurface.dialog && _activeDialogImageKey != null) {
      nextState = _dialogHistory.redo(_activeDialogImageKey!);
      if (nextState != null) {
        _dialogStrokes[_activeDialogImageKey!] = nextState;
      }
    } else {
      nextState = _pdfHistory.redo(_currentPage);
      if (nextState != null) {
        _pageStrokes[_currentPage] = nextState;
      }
    }

    if (nextState != null) {
      _updateUndoRedoState();
      notifyListeners();
    }
  }

  void clearCurrentPage() {
    if (_activeSurface == DrawingSurface.dialog && _activeDialogImageKey != null) {
      _dialogStrokes[_activeDialogImageKey!]?.clear();
      _dialogHistory.clear(_activeDialogImageKey!);
    } else {
      _pageStrokes[_currentPage]?.clear();
      _pdfHistory.clear(_currentPage);
    }
    _saveToHistory(); // Save the clearing action
    notifyListeners();
  }
}
