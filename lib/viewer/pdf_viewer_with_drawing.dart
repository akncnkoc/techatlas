import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:archive/archive.dart';
import 'stroke.dart';
import 'drawing_painter.dart';
import 'tool_state.dart';
import 'drawing_history.dart';
import 'page_time_tracker.dart';
import 'magnifier_overlay.dart';
import 'magnified_content_overlay.dart';
import '../models/crop_data.dart';
import 'dart:math' show cos, sin;

// Import new components and utilities
import '../core/constants/app_constants.dart';
import '../core/utils/matrix_utils.dart' as custom_matrix;
import '../features/pdf_viewer/presentation/widgets/dialogs/image_gallery_dialog.dart';

class PdfViewerWithDrawing extends StatefulWidget {
  final PdfController controller;
  final CropData? cropData;
  final String? zipFilePath;

  const PdfViewerWithDrawing({
    super.key,
    required this.controller,
    this.cropData,
    this.zipFilePath,
  });

  @override
  State<PdfViewerWithDrawing> createState() => PdfViewerWithDrawingState();
}

class PdfViewerWithDrawingState extends State<PdfViewerWithDrawing> {
  final Map<int, List<Stroke>> _pageStrokes = {};
  Stroke? _activeStroke;
  final ValueNotifier<int> _repaintNotifier = ValueNotifier<int>(0);
  final ValueNotifier<ToolState> toolNotifier = ValueNotifier<ToolState>(
    ToolState(
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
      width: 3.0,
    ),
  );

  // Undo/Redo için geçmiş yönetimi
  final DrawingHistory _history = DrawingHistory();
  final ValueNotifier<bool> _canUndoNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _canRedoNotifier = ValueNotifier<bool>(false);

  // Zaman takibi
  late final PageTimeTracker _timeTracker;
  final ValueNotifier<String> _currentPageTimeNotifier = ValueNotifier<String>(
    '0sn',
  );

  int _currentPage = 1;
  final TransformationController transformationController =
      TransformationController();

  // Use AppConstants for zoom limits
  final double _minZoom = AppConstants.minZoom;
  final double _maxZoom = AppConstants.maxZoom;

  bool _isDrawing = false;
  bool _isPanning = false;
  double _rotationAngle = 0.0;
  double _lastRotation = 0.0;
  Offset? _shapeStartPoint;
  Matrix4? _scaleStartTransform; // Pinch zoom için başlangıç transform
  Offset? _scaleStartFocalPoint; // Pinch zoom için başlangıç focal point

  Offset? _panStartPosition;
  Offset? _panLastPosition;
  DateTime? _panStartTime;

  // Use AppConstants for gesture thresholds
  static const double _swipeVelocityThreshold = AppConstants.swipeVelocityThreshold;
  static const double _swipeDistanceThreshold = AppConstants.swipeDistanceThreshold;

  final ValueNotifier<Rect?> selectedAreaNotifier = ValueNotifier<Rect?>(null);
  Offset? _selectionStartScreen;

  // Magnifier state
  MagnifierState _magnifierState = MagnifierState();
  final ValueNotifier<Rect?> _magnifierAreaNotifier = ValueNotifier<Rect?>(null);
  bool _showMagnifiedView = false;
  Rect? _magnifiedRect;

  double _lastRenderedScale = 1.0;
  final ValueNotifier<double> _pdfScaleNotifier = ValueNotifier<double>(1.0);

  int _activePointers = 0; // Aktif parmak sayısı

  // RepaintBoundary key for capturing content
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.pageListenable.addListener(_onPageChanged);
    transformationController.addListener(_onTransformChanged);

    _timeTracker = PageTimeTracker(onUpdate: _updateTimeDisplay);
    _timeTracker.onPageChanged(_currentPage);
    _timeTracker.startTimer();

    _saveToHistory();
  }

  void _onPageChanged() {
    final page = widget.controller.pageListenable.value;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      _repaintNotifier.value++;
      _updateUndoRedoState();
      _timeTracker.onPageChanged(page);
    }
  }

  void _onTransformChanged() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();

    if ((currentScale - _lastRenderedScale).abs() / _lastRenderedScale > 0.05) {
      _lastRenderedScale = currentScale;
      _pdfScaleNotifier.value = currentScale;
    }
  }

  @override
  void dispose() {
    widget.controller.pageListenable.removeListener(_onPageChanged);
    transformationController.removeListener(_onTransformChanged);
    transformationController.dispose();
    _repaintNotifier.dispose();
    selectedAreaNotifier.dispose();
    _magnifierAreaNotifier.dispose();
    _pdfScaleNotifier.dispose();
    _canUndoNotifier.dispose();
    _canRedoNotifier.dispose();
    _timeTracker.dispose();
    _currentPageTimeNotifier.dispose();
    super.dispose();
  }

  List<Stroke> get _strokes => _pageStrokes[_currentPage] ??= [];

  /// Undo/Redo durumunu güncelle
  void _updateUndoRedoState() {
    _canUndoNotifier.value = _history.canUndo(_currentPage);
    _canRedoNotifier.value = _history.canRedo(_currentPage);
  }

  /// Geçmişe kaydet
  void _saveToHistory() {
    _history.saveState(_currentPage, _strokes);
    _updateUndoRedoState();
  }

  /// Zaman gösterimini güncelle
  void _updateTimeDisplay() {
    final pageData = _timeTracker.getCurrentPageData();
    if (pageData != null) {
      _currentPageTimeNotifier.value = pageData.formatDuration();
    }
  }

  /// Mevcut sayfa için zaman verisini al
  String getCurrentPageTime() {
    return _currentPageTimeNotifier.value;
  }

  /// Mevcut sayfa zaman notifier'ını al
  ValueNotifier<String> get currentPageTimeNotifier => _currentPageTimeNotifier;

  /// Zaman takipçisini al (detaylı bilgi için)
  PageTimeTracker get timeTracker => _timeTracker;

  // Use custom MatrixUtils for point transformation
  Offset _transformPoint(Offset point) {
    return custom_matrix.MatrixUtils.transformPoint(
      transformationController.value,
      point,
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastRotation = 0.0;
    final tool = toolNotifier.value;

    print(
      "🎯 ScaleStart: ${details.pointerCount} pointers, tool: pencil=${tool.pencil}, eraser=${tool.eraser}, highlighter=${tool.highlighter}",
    );

    // 2 parmak: Zoom için başlangıç transformu ve focal point'i kaydet
    if (details.pointerCount == 2) {
      _scaleStartTransform = Matrix4.copy(transformationController.value);
      _scaleStartFocalPoint = details.localFocalPoint;
      print("✌️ 2 pointers: zoom mode at ${details.localFocalPoint}");
      return;
    }

    // Sadece 1 parmak işlemlerini yönet
    if (details.pointerCount == 1) {
      if (tool.grab || tool.mouse) {
        _isPanning = true;
        _panStartPosition = details.localFocalPoint;
        _panStartTime = DateTime.now();
        print("👆 1 pointer: panning mode");
      } else if (tool.shape || tool.pencil || tool.eraser || tool.highlighter) {
        if (_rotationAngle != 0.0) {
          print("⚠️ Rotation is not zero, skipping draw");
          return;
        }
        if (tool.shape) {
          _startShape(details.localFocalPoint);
          print("📐 1 pointer: shape mode");
        } else {
          _startStroke(details.localFocalPoint);
          print("✏️ 1 pointer: drawing mode");
        }
      }
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final tool = toolNotifier.value;

    // 3 parmak hareketi: Rotasyon
    if (details.pointerCount == 3) {
      final rotationDelta = details.rotation - _lastRotation;
      _rotationAngle += rotationDelta;
      _lastRotation = details.rotation;
      setState(() {});
      return;
    }

    // 2 parmak hareketi: Pinch to zoom (gerçek zamanlı)
    if (details.pointerCount == 2 && _scaleStartTransform != null && _scaleStartFocalPoint != null) {
      final scaleChange = details.scale;

      // Zoom limitlerini kontrol et
      final startScale = custom_matrix.MatrixUtils.getScale(_scaleStartTransform!);
      final newScale = (startScale * scaleChange).clamp(_minZoom, _maxZoom);

      // Use custom MatrixUtils for zoom transformation
      transformationController.value = custom_matrix.MatrixUtils.createZoomTransform(
        focalPoint: _scaleStartFocalPoint!,
        startTransform: _scaleStartTransform!,
        startScale: startScale,
        newScale: newScale,
      );

      return;
    }

    // 1 parmak hareketleri - çizim ve pan işlemleri
    if (details.pointerCount == 1) {
      if ((tool.grab || tool.mouse) && _isPanning) {
        _panLastPosition = details.localFocalPoint;

        final currentTransform = transformationController.value;
        final newTransform = Matrix4.copy(currentTransform)
          ..translateByVector3(
            Vector3(details.focalPointDelta.dx, details.focalPointDelta.dy, 0),
          );
        transformationController.value = newTransform;
      } else if (tool.shape) {
        _updateShape(details.localFocalPoint);
      } else if (tool.pencil || tool.eraser || tool.highlighter) {
        _updateStroke(details.localFocalPoint);
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    final tool = toolNotifier.value;

    // Zoom bittiğinde başlangıç transformunu ve focal point'i temizle
    _scaleStartTransform = null;
    _scaleStartFocalPoint = null;

    if ((tool.grab || tool.mouse) && _isPanning) {
      if (_panStartPosition != null &&
          _panLastPosition != null &&
          _panStartTime != null) {
        final distance = _panLastPosition! - _panStartPosition!;
        final duration = DateTime.now().difference(_panStartTime!);
        final velocity = distance.dx.abs() / (duration.inMilliseconds / 1000.0);

        final isHorizontalSwipe = distance.dx.abs() > distance.dy.abs() * 2.0;

        final isFastEnough = velocity > _swipeVelocityThreshold;
        final isLongEnough = distance.dx.abs() > _swipeDistanceThreshold;

        if (isHorizontalSwipe && isFastEnough && isLongEnough) {
          setState(() {
            transformationController.value = Matrix4.identity();
            _lastRenderedScale = 1.0;
            _pdfScaleNotifier.value = 1.0;
          });

          if (distance.dx > 0) {
            widget.controller.previousPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          } else {
            widget.controller.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          }
        }
      }

      _isPanning = false;
      _panStartPosition = null;
      _panLastPosition = null;
      _panStartTime = null;
    } else if (tool.shape) {
      _endShape();
    } else if (tool.pencil || tool.eraser || tool.highlighter) {
      _endStroke();
    }

    _lastRotation = 0.0;
  }

  void _startShape(Offset position) {
    final transformedPosition = position;

    setState(() {
      _isDrawing = true;
      _shapeStartPoint = transformedPosition;

      final tool = toolNotifier.value;
      StrokeType strokeType;

      switch (tool.selectedShape) {
        case ShapeType.rectangle:
          strokeType = StrokeType.rectangle;
          break;
        case ShapeType.circle:
          strokeType = StrokeType.circle;
          break;
        case ShapeType.line:
          strokeType = StrokeType.line;
          break;
        case ShapeType.arrow:
          strokeType = StrokeType.arrow;
          break;
      }

      _activeStroke = Stroke.shape(
        color: tool.color,
        width: tool.width,
        type: strokeType,
        shapePoints: [transformedPosition, transformedPosition],
      );

      _strokes.add(_activeStroke!);
      _repaintNotifier.value++;
    });
  }

  void _updateShape(Offset position) {
    if (_activeStroke != null && _shapeStartPoint != null) {
      final transformedPosition = _transformPoint(position);
      _activeStroke!.points[1] = transformedPosition;
      _repaintNotifier.value++;
    }
  }

  void _endShape() {
    setState(() {
      _activeStroke = null;
      _shapeStartPoint = null;
      _isDrawing = false;
      _repaintNotifier.value++;
    });
    _saveToHistory();
  }

  void _startStroke(Offset position) {
    print("🖊️ _startStroke called at $position");
    final transformedPosition = _transformPoint(position);
    print("🔄 Transformed position: $transformedPosition");

    setState(() {
      _isDrawing = true;

      final tool = toolNotifier.value;

      if (tool.eraser) {
        _activeStroke = Stroke(
          color: tool.color,
          width: tool.width,
          erase: true,
        );
        _activeStroke!.points.add(transformedPosition);
        _eraseAt(transformedPosition, tool.width);
        print("🧹 Eraser stroke started");
        return;
      }

      _activeStroke = Stroke(
        color: tool.color,
        width: tool.width,
        erase: false,
        isHighlighter: tool.highlighter,
      );
      _activeStroke!.points.add(transformedPosition);
      _strokes.add(_activeStroke!);

      _repaintNotifier.value++;
      print(
        "✅ Stroke started: ${_strokes.length} total strokes, highlighter: ${tool.highlighter}",
      );
    });
  }

  void _updateStroke(Offset position) {
    if (!_isDrawing && _activeStroke == null) return;

    final transformedPosition = _transformPoint(position);
    final tool = toolNotifier.value;

    if (tool.eraser) {
      _activeStroke?.points.add(transformedPosition);
      _eraseAt(transformedPosition, tool.width);
    } else {
      if (_activeStroke != null && _activeStroke!.points.isNotEmpty) {
        final lastPoint = _activeStroke!.points.last;
        final distance = (transformedPosition - lastPoint).distance;

        final minDistance = tool.highlighter
            ? AppConstants.minHighlighterDistance
            : AppConstants.minDrawingDistance;

        if (distance > minDistance) {
          _activeStroke!.points.add(transformedPosition);
        }
      } else {
        _activeStroke?.points.add(transformedPosition);
      }
    }

    _repaintNotifier.value++;
  }

  void _endStroke() {
    setState(() {
      _activeStroke = null;
      _isDrawing = false;
      _repaintNotifier.value++;
    });
    _saveToHistory();
  }

  void _eraseAt(Offset position, double eraserRadius) {
    final List<Stroke> newStrokes = [];

    for (final stroke in _strokes) {
      if (stroke.erase) continue;

      if (stroke.type != StrokeType.freehand) {
        final List<Offset> shapePoints = _expandShapeToPoints(stroke);
        final List<Offset> remainingPoints = [];
        final List<List<Offset>> segments = [];

        for (int i = 0; i < shapePoints.length; i++) {
          final point = shapePoints[i];
          final distance = (point - position).distance;

          if (distance >= eraserRadius * 1.2) {
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
          if (segment.length > 1) {
            final newStroke = Stroke(
              color: stroke.color,
              width: stroke.width,
              erase: false,
            );
            newStroke.points.addAll(segment);
            newStrokes.add(newStroke);
          }
        }
        continue;
      }

      final List<Offset> remainingPoints = [];
      final List<List<Offset>> segments = [];

      for (int i = 0; i < stroke.points.length; i++) {
        final point = stroke.points[i];
        final distance = (point - position).distance;

        if (distance >= eraserRadius * 1.2) {
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
        if (segment.length > 1) {
          final newStroke = Stroke(
            color: stroke.color,
            width: stroke.width,
            erase: false,
          );
          newStroke.points.addAll(segment);
          newStrokes.add(newStroke);
        }
      }
    }

    _strokes.removeWhere((stroke) => !stroke.erase);
    _strokes.addAll(newStrokes);
  }

  List<Offset> _expandShapeToPoints(Stroke stroke) {
    if (stroke.points.length < 2) return stroke.points;

    final p1 = stroke.points[0];
    final p2 = stroke.points[1];
    final List<Offset> expandedPoints = [];

    switch (stroke.type) {
      case StrokeType.line:
      case StrokeType.arrow:
        final steps = ((p2 - p1).distance / 2).ceil();
        for (int i = 0; i <= steps; i++) {
          final t = i / steps;
          expandedPoints.add(
            Offset(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t),
          );
        }
        break;

      case StrokeType.rectangle:
        final topLeft = Offset(
          p1.dx < p2.dx ? p1.dx : p2.dx,
          p1.dy < p2.dy ? p1.dy : p2.dy,
        );
        final bottomRight = Offset(
          p1.dx > p2.dx ? p1.dx : p2.dx,
          p1.dy > p2.dy ? p1.dy : p2.dy,
        );
        final topRight = Offset(bottomRight.dx, topLeft.dy);
        final bottomLeft = Offset(topLeft.dx, bottomRight.dy);

        expandedPoints.addAll(_interpolateLine(topLeft, topRight));
        expandedPoints.addAll(_interpolateLine(topRight, bottomRight));
        expandedPoints.addAll(_interpolateLine(bottomRight, bottomLeft));
        expandedPoints.addAll(_interpolateLine(bottomLeft, topLeft));
        break;

      case StrokeType.circle:
        final center = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final radius = (p2 - p1).distance / 2;
        final steps = (radius * 2).ceil();

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

      default:
        expandedPoints.addAll(stroke.points);
    }

    return expandedPoints;
  }

  List<Offset> _interpolateLine(Offset start, Offset end) {
    final List<Offset> points = [];
    final steps = ((end - start).distance / 2).ceil();

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

  void clearCurrentPage() {
    _strokes.clear();
    setState(() {
      _repaintNotifier.value++;
    });
    _saveToHistory();
  }

  void undo() {
    final previousState = _history.undo(_currentPage);
    if (previousState != null) {
      setState(() {
        _pageStrokes[_currentPage] = previousState;
        _repaintNotifier.value++;
      });
      _updateUndoRedoState();
    }
  }

  void redo() {
    final nextState = _history.redo(_currentPage);
    if (nextState != null) {
      setState(() {
        _pageStrokes[_currentPage] = nextState;
        _repaintNotifier.value++;
      });
      _updateUndoRedoState();
    }
  }

  bool get canUndo => _canUndoNotifier.value;

  bool get canRedo => _canRedoNotifier.value;

  ValueNotifier<bool> get canUndoNotifier => _canUndoNotifier;

  ValueNotifier<bool> get canRedoNotifier => _canRedoNotifier;

  double get zoomLevel => transformationController.value.getMaxScaleOnAxis();

  void zoomIn() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.2).clamp(_minZoom, _maxZoom);
    transformationController.value = Matrix4.identity()..scaleByVector3(Vector3(newScale, newScale, 1));
  }

  void zoomOut() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(_minZoom, _maxZoom);
    transformationController.value = Matrix4.identity()..scaleByVector3(Vector3(newScale, newScale, 1));
  }

  void resetZoom() {
    transformationController.value = Matrix4.identity();
    _lastRenderedScale = 1.0;
    _pdfScaleNotifier.value = 1.0;
  }

  void rotateLeft() {
    setState(() {
      _rotationAngle -= 1.5708;
    });
  }

  void rotateRight() {
    setState(() {
      _rotationAngle += 1.5708;
    });
  }

  void resetRotation() {
    setState(() {
      _rotationAngle = 0.0;
    });
  }

  void setPencil(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      pencil: value,
      highlighter: false,
      eraser: false,
      grab: false,
      shape: false,
      mouse: false,
      selection: false,
      magnifier: false,
    );
  }

  void setHighlighter(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      highlighter: value,
      pencil: false,
      eraser: false,
      grab: false,
      shape: false,
      mouse: false,
      selection: false,
      magnifier: false,
    );
  }

  void setEraser(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      eraser: value,
      pencil: false,
      highlighter: false,
      grab: false,
      shape: false,
      mouse: false,
      selection: false,
      magnifier: false,
    );
  }

  void setGrab(bool value) {
    // Grab artık mouse ile aynı işlevi görüyor
    toolNotifier.value = toolNotifier.value.copyWith(
      mouse: value,
      grab: false,
      pencil: false,
      highlighter: false,
      eraser: false,
      shape: false,
      selection: false,
      magnifier: false,
    );
  }

  void setMouse(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      mouse: value,
      pencil: false,
      highlighter: false,
      eraser: false,
      grab: false,
      shape: false,
      selection: false,
      magnifier: false,
    );
  }

  void setShape(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      shape: value,
      pencil: false,
      highlighter: false,
      eraser: false,
      grab: false,
      mouse: false,
      selection: false,
      magnifier: false,
    );
  }

  void setSelectedShape(ShapeType shapeType) {
    toolNotifier.value = toolNotifier.value.copyWith(
      selectedShape: shapeType,
      shape: true,
      pencil: false,
      highlighter: false,
      eraser: false,
      grab: false,
      mouse: false,
      selection: false,
      magnifier: false,
    );
  }

  void setColor(Color value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      color: value,
      pencil: !toolNotifier.value.shape && !toolNotifier.value.highlighter,
      highlighter: toolNotifier.value.highlighter,
      shape: toolNotifier.value.shape,
      eraser: false,
      grab: false,
      mouse: false,
      selection: false,
      magnifier: false,
    );
  }

  void setWidth(double value) {
    toolNotifier.value = toolNotifier.value.copyWith(width: value);
  }

  void setSelection(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      selection: value,
      mouse: false,
      pencil: false,
      highlighter: false,
      eraser: false,
      grab: false,
      shape: false,
      magnifier: false,
    );
    if (!value) {
      selectedAreaNotifier.value = null;
      _selectionStartScreen = null;
    }
  }

  void setMagnifier(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      magnifier: value,
      mouse: false,
      pencil: false,
      highlighter: false,
      eraser: false,
      grab: false,
      shape: false,
      selection: false,
    );
    if (!value) {
      _magnifierState = MagnifierState();
      _magnifierAreaNotifier.value = null;
    }
  }

  void clearSelection() {
    selectedAreaNotifier.value = null;
    _selectionStartScreen = null;
    setMouse(true);
  }

  void _handlePointerDown(PointerDownEvent event) {
    final tool = toolNotifier.value;
    if (tool.selection) {
      _selectionStartScreen = event.localPosition;
      selectedAreaNotifier.value = null;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final tool = toolNotifier.value;
    if (tool.selection && _selectionStartScreen != null) {
      selectedAreaNotifier.value = Rect.fromPoints(
        _selectionStartScreen!,
        event.localPosition,
      );
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final tool = toolNotifier.value;
    if (tool.selection) {
      _selectionStartScreen = null;
    }
  }

  void _handleMagnifierPointerDown(PointerDownEvent event) {
    final tool = toolNotifier.value;
    if (!tool.magnifier) return;

    final position = event.localPosition;
    final handle = _magnifierState.getHandleAtPosition(position);

    if (handle != null) {
      // Start resizing
      setState(() {
        _magnifierState = _magnifierState.copyWith(
          isResizing: true,
          resizeHandle: handle,
        );
      });
    } else if (_magnifierState.selectedArea != null &&
               _magnifierState.isPointInSelectedArea(position)) {
      // Do nothing - user tapped inside the selection
    } else {
      // Start new selection
      setState(() {
        _magnifierState = _magnifierState.copyWith(
          startPoint: position,
          currentPoint: position,
          isSelecting: true,
          clearSelectedArea: true,
        );
        _magnifierAreaNotifier.value = null;
      });
    }
  }

  void _handleMagnifierPointerMove(PointerMoveEvent event) {
    final tool = toolNotifier.value;
    if (!tool.magnifier) return;

    final position = event.localPosition;

    if (_magnifierState.isSelecting) {
      // Update selection area
      setState(() {
        _magnifierState = _magnifierState.copyWith(
          currentPoint: position,
        );
        _magnifierAreaNotifier.value = _magnifierState.getSelectionRect();
      });
    } else if (_magnifierState.isResizing && _magnifierState.selectedArea != null) {
      // Resize the selected area
      final currentArea = _magnifierState.selectedArea!;
      Rect newArea;

      switch (_magnifierState.resizeHandle) {
        case 'topLeft':
          newArea = Rect.fromLTRB(
            position.dx,
            position.dy,
            currentArea.right,
            currentArea.bottom,
          );
          break;
        case 'topRight':
          newArea = Rect.fromLTRB(
            currentArea.left,
            position.dy,
            position.dx,
            currentArea.bottom,
          );
          break;
        case 'bottomLeft':
          newArea = Rect.fromLTRB(
            position.dx,
            currentArea.top,
            currentArea.right,
            position.dy,
          );
          break;
        case 'bottomRight':
          newArea = Rect.fromLTRB(
            currentArea.left,
            currentArea.top,
            position.dx,
            position.dy,
          );
          break;
        default:
          newArea = currentArea;
      }

      setState(() {
        _magnifierState = _magnifierState.copyWith(
          selectedArea: newArea,
        );
        _magnifierAreaNotifier.value = newArea;
      });
    }
  }

  void _handleMagnifierPointerUp(PointerUpEvent event) {
    final tool = toolNotifier.value;
    if (!tool.magnifier) return;

    if (_magnifierState.isSelecting) {
      final selectionRect = _magnifierState.getSelectionRect();
      if (selectionRect != null && selectionRect.width > 10 && selectionRect.height > 10) {
        setState(() {
          _magnifierState = _magnifierState.copyWith(
            selectedArea: selectionRect,
            isSelecting: false,
            clearStartPoint: true,
            clearCurrentPoint: true,
          );
          _magnifierAreaNotifier.value = null;
          _showMagnifiedView = true;
          _magnifiedRect = selectionRect;
        });
      }
    } else if (_magnifierState.isResizing) {
      final resizedArea = _magnifierState.selectedArea;
      if (resizedArea != null && resizedArea.width > 10 && resizedArea.height > 10) {
        setState(() {
          _showMagnifiedView = true;
          _magnifiedRect = resizedArea;
        });
      }
      setState(() {
        _magnifierState = _magnifierState.copyWith(
          isResizing: false,
          clearResizeHandle: true,
        );
      });
    }
  }

  Future<void> _showCropImage(String imageFileName) async {
    if (widget.zipFilePath == null) {
      print('⚠️ Book file path is null!');
      return;
    }

    try {
      final zipBytes = await File(widget.zipFilePath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Mevcut sayfadaki tüm crop'ları al
      final cropsForPage = widget.cropData!.getCropsForPage(_currentPage);

      // Tüm resim dosyalarını yükle
      final List<MapEntry<String, Uint8List>> imageList = [];
      int initialIndex = 0;

      for (int i = 0; i < cropsForPage.length; i++) {
        final crop = cropsForPage[i];
        ArchiveFile? imageFile;

        for (final file in archive) {
          if (file.isFile && file.name == crop.imageFile) {
            imageFile = file;
            break;
          }
        }

        if (imageFile != null) {
          final imageBytes = imageFile.content as Uint8List;
          imageList.add(MapEntry(crop.imageFile, imageBytes));

          // Tıklanan resmin index'ini bul
          if (crop.imageFile == imageFileName) {
            initialIndex = imageList.length - 1;
          }
        }
      }

      if (imageList.isEmpty) {
        print('⚠️ No images found on this page');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sayfa üzerinde resim bulunamadı'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (!mounted) return;

      // Use new ImageGalleryDialog component
      showDialog(
        context: context,
        builder: (context) => ImageGalleryDialog(
          imageList: imageList,
          initialIndex: initialIndex,
          cropData: widget.cropData!,
          cropsForPage: cropsForPage,
          pdfController: widget.controller,
        ),
      );

      print('✅ Image gallery displayed with ${imageList.length} images');
    } catch (e) {
      print('❌ Error loading images: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resimler yüklenirken hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildCropButtons() {
    if (widget.cropData == null) {
      print('⚠️ No crop data available');
      return const SizedBox.shrink();
    }

    final cropsForPage = widget.cropData!.getCropsForPage(_currentPage);
    print('🔍 Page $_currentPage: Found ${cropsForPage.length} objects');

    if (cropsForPage.isEmpty) {
      print('⚠️ No objects on page $_currentPage');
      return const SizedBox.shrink();
    }

    return FutureBuilder<PdfDocument>(
      future: widget.controller.document,
      builder: (context, docSnapshot) {
        if (!docSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<PdfPage>(
          future: docSnapshot.data!.getPage(_currentPage),
          builder: (context, pageSnapshot) {
            if (!pageSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final pdfPage = pageSnapshot.data!;
            final pdfWidth = pdfPage.width;
            final pdfHeight = pdfPage.height;

            final cropReferenceSize = widget.cropData!.getReferenceSizeForPage(
              _currentPage,
            );
            final cropRefWidth = cropReferenceSize.width;
            final cropRefHeight = cropReferenceSize.height;

            if (cropsForPage.isNotEmpty) {
              print('═══════════════════════════════════════');
              print('📄 PDF Size: ${pdfWidth.toStringAsFixed(1)}x${pdfHeight.toStringAsFixed(1)}');
              print('🖼️  Crop Reference: ${cropRefWidth.toStringAsFixed(1)}x${cropRefHeight.toStringAsFixed(1)}');
              print('🔢 Questions on page $_currentPage: ${cropsForPage.length}');
              print('═══════════════════════════════════════');
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final renderedWidth = constraints.maxWidth;
                final renderedHeight = constraints.maxHeight;

                if (pdfWidth == 0 ||
                    pdfHeight == 0 ||
                    renderedWidth == 0 ||
                    renderedHeight == 0) {
                  return const SizedBox.shrink();
                }

                if (cropRefWidth == 0 || cropRefHeight == 0) {
                  print('⚠️  Crop reference size is zero!');
                  return const SizedBox.shrink();
                }

                final pdfAspectRatio = pdfWidth / pdfHeight;
                final containerAspectRatio = renderedWidth / renderedHeight;

                double actualPdfWidth;
                double actualPdfHeight;
                double offsetX = 0;
                double offsetY = 0;

                if (containerAspectRatio > pdfAspectRatio) {
                  actualPdfHeight = renderedHeight;
                  actualPdfWidth = actualPdfHeight * pdfAspectRatio;
                  offsetX = (renderedWidth - actualPdfWidth) / 2;
                } else {
                  actualPdfWidth = renderedWidth;
                  actualPdfHeight = actualPdfWidth / pdfAspectRatio;
                  offsetY = (renderedHeight - actualPdfHeight) / 2;
                }

                final cropToPdfScaleX = pdfWidth / cropRefWidth;
                final cropToPdfScaleY = pdfHeight / cropRefHeight;

                final pdfToRenderScaleX = actualPdfWidth / pdfWidth;
                final pdfToRenderScaleY = actualPdfHeight / pdfHeight;

                final totalScaleX = cropToPdfScaleX * pdfToRenderScaleX;
                final totalScaleY = cropToPdfScaleY * pdfToRenderScaleY;

                if (cropsForPage.isNotEmpty) {
                  print(
                    '📐 Container: ${renderedWidth.toStringAsFixed(1)}x${renderedHeight.toStringAsFixed(1)}',
                  );
                  print(
                    '📊 Actual PDF Render: ${actualPdfWidth.toStringAsFixed(1)}x${actualPdfHeight.toStringAsFixed(1)}',
                  );
                  print(
                    '📍 Offset: (${offsetX.toStringAsFixed(1)}, ${offsetY.toStringAsFixed(1)})',
                  );
                  print(
                    '🔄 Crop→PDF Scale: ${cropToPdfScaleX.toStringAsFixed(3)}x${cropToPdfScaleY.toStringAsFixed(3)}',
                  );
                  print(
                    '📊 Total Scale: ${totalScaleX.toStringAsFixed(3)}x${totalScaleY.toStringAsFixed(3)}',
                  );
                }

                return ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: cropsForPage.map((crop) {

                      // Tüm crop koordinatlarını göster
                      print(
                        '🔍 Q${crop.questionNumber}: x1=${crop.coordinates.x1}, y1=${crop.coordinates.y1}, x2=${crop.coordinates.x2}, y2=${crop.coordinates.y2}, width=${crop.coordinates.width}, height=${crop.coordinates.height}',
                      );

                      // YENİ ÇÖZÜM: Soru numarasının TAM KONUMUNU kullan!
                      double buttonLeft, buttonTop;

                      if (crop.questionNumberDetails != null &&
                          crop.questionNumberDetails!.location != null) {
                        // Soru numarası konumu var - butonu onun yanına koy
                        final qNumLoc = crop.questionNumberDetails!.location!;
                        final qNumX = qNumLoc.x.toDouble();
                        final qNumY = qNumLoc.y.toDouble();

                        // Soru numarası pozisyonunu ekrana çevir
                        final qNumScreenX = (qNumX / cropRefWidth) * actualPdfWidth + offsetX;
                        final qNumScreenY = (qNumY / cropRefHeight) * actualPdfHeight + offsetY;

                        // Butonu soru numarasının SOL TARAFINA koy
                        buttonLeft = qNumScreenX - 35; // 35px sola (30px buton + 5px boşluk)
                        buttonTop = qNumScreenY;

                        print(
                          '  ✨ QuestionNum Location: ($qNumX,$qNumY) → Screen(${qNumScreenX.toStringAsFixed(1)},${qNumScreenY.toStringAsFixed(1)})',
                        );
                      } else {
                        // Soru numarası konumu yok - eski yöntem (crop sol üst köşesi)
                        final cropX = crop.coordinates.x1.toDouble();
                        final cropY = crop.coordinates.y1.toDouble();

                        buttonLeft = (cropX / cropRefWidth) * actualPdfWidth + offsetX;
                        buttonTop = (cropY / cropRefHeight) * actualPdfHeight + offsetY;

                        print(
                          '  ⚠️  No question number location, using crop top-left',
                        );
                      }

                      print(
                        '  🎯 Button Position: (${buttonLeft.toStringAsFixed(1)},${buttonTop.toStringAsFixed(1)})',
                      );

                      // Butonun boyutu
                      const buttonSize = 30.0;

                      // Sadece PDF alanı içindeki butonları göster
                      if (buttonLeft < offsetX ||
                          buttonLeft > offsetX + actualPdfWidth ||
                          buttonTop < offsetY ||
                          buttonTop > offsetY + actualPdfHeight) {
                        return const SizedBox.shrink();
                      }

                      // DEBUG: Crop alanını göster (turuncu kutu)
                      final cropScreenX = (crop.coordinates.x1.toDouble() / cropRefWidth) * actualPdfWidth + offsetX;
                      final cropScreenY = (crop.coordinates.y1.toDouble() / cropRefHeight) * actualPdfHeight + offsetY;
                      final cropWidth = (crop.coordinates.width / cropRefWidth) * actualPdfWidth;
                      final cropHeight = (crop.coordinates.height / cropRefHeight) * actualPdfHeight;

                      return Stack(
                        children: [
                          // DEBUG: Crop alanını renkli translucent box ile göster
                          Positioned(
                            left: cropScreenX,
                            top: cropScreenY,
                            child: Container(
                              width: cropWidth,
                              height: cropHeight,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.orange, width: 3),
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                              child: Center(
                                child: Text(
                                  'Q${crop.questionNumber ?? "?"}',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Buton
                          Positioned(
                            left: buttonLeft,
                            top: buttonTop,
                            child: GestureDetector(
                              onTap: () {
                                print('Question ${crop.questionNumber} clicked!');
                                _showCropImage(crop.imageFile);
                              },
                              child: Container(
                                width: buttonSize,
                                height: buttonSize,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    "${crop.questionNumber ?? '?'}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tool = toolNotifier.value;

    final mainContent = Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

          if (isCtrlPressed) {
            final delta = pointerSignal.scrollDelta.dy;
            final currentScale = transformationController.value
                .getMaxScaleOnAxis();

            double zoomFactor;
            if (delta < 0) {
              zoomFactor = 1.1;
            } else {
              zoomFactor = 0.9;
            }

            final newScale = (currentScale * zoomFactor).clamp(
              _minZoom,
              _maxZoom,
            );

            if (newScale != currentScale) {
              transformationController.value = Matrix4.identity()
                ..scaleByVector3(Vector3(newScale, newScale, 1));
            }
          }
        }
      },
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

            if (isCtrlPressed) {
              switch (event.logicalKey) {
                case LogicalKeyboardKey.keyZ:
                  if (_history.canUndo(_currentPage)) {
                    undo();
                  }
                  break;
                case LogicalKeyboardKey.keyY:
                  if (_history.canRedo(_currentPage)) {
                    redo();
                  }
                  break;
                case LogicalKeyboardKey.arrowLeft:
                  rotateLeft();
                  break;
                case LogicalKeyboardKey.arrowRight:
                  rotateRight();
                  break;
                case LogicalKeyboardKey.keyR:
                  resetRotation();
                  break;
              }
            }
          }
        },
        child: MouseRegion(
          cursor: tool.mouse
              ? SystemMouseCursors.move
              : tool.grab
              ? SystemMouseCursors.grab
              : tool.pencil
              ? SystemMouseCursors.precise
              : tool.highlighter
              ? SystemMouseCursors.precise
              : tool.shape
              ? SystemMouseCursors.cell
              : tool.eraser
              ? SystemMouseCursors.click
              : tool.selection
              ? SystemMouseCursors.precise
              : tool.magnifier
              ? SystemMouseCursors.zoomIn
              : SystemMouseCursors.basic,
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: transformationController,
                minScale: _minZoom,
                maxScale: _maxZoom,
                boundaryMargin: const EdgeInsets.all(20),
                // GestureDetector kullandığımız için panEnabled false olmalı
                // Aksi halde gesture çakışması oluşur
                panEnabled: false,
                // Zoom her zaman aktif ama GestureDetector engelleyebilir
                scaleEnabled: true,
                child: Builder(
                  builder: (context) {
                    final pdfContent = Transform.rotate(
                      angle: _rotationAngle,
                      child: Stack(
                        children: [
                          ValueListenableBuilder<double>(
                            valueListenable: _pdfScaleNotifier,
                            builder: (context, scale, child) {
                              final quality = (scale * 6).clamp(4.0, 12.0);

                              return PdfView(
                                controller: widget.controller,
                                renderer: (page) {
                                  return page.render(
                                    width: (page.width * quality).toDouble(),
                                    height: (page.height * quality).toDouble(),
                                    format: PdfPageImageFormat.png,
                                    backgroundColor: '#FFFFFF',
                                  );
                                },
                              );
                            },
                          ),
                          Positioned.fill(
                            child: ValueListenableBuilder(
                              valueListenable: _repaintNotifier,
                              builder: (_, __, ___) {
                                return CustomPaint(
                                  painter: DrawingPainter(strokes: _strokes),
                                  size: Size.infinite,
                                  child: Container(),
                                );
                              },
                            ),
                          ),
                          if (widget.cropData != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: false,
                                child: _buildCropButtons(),
                              ),
                            ),
                        ],
                      ),
                    );

                    // Pointer count tracking için Listener ekle
                    final wrappedContent = Listener(
                      onPointerDown: (event) {
                        setState(() {
                          _activePointers++;
                          print(
                            "👆 Pointer down: $_activePointers active pointers",
                          );
                        });
                      },
                      onPointerUp: (event) {
                        setState(() {
                          _activePointers--;
                          print(
                            "👇 Pointer up: $_activePointers active pointers",
                          );
                        });
                      },
                      onPointerCancel: (event) {
                        setState(() {
                          _activePointers--;
                          print(
                            "❌ Pointer cancel: $_activePointers active pointers",
                          );
                        });
                      },
                      child: pdfContent,
                    );

                    // Sadece çizim araçları aktifken GestureDetector kullan
                    // Mouse/grab modunda InteractiveViewer'ın kendi özelliklerini kullan
                    if (tool.pencil ||
                        tool.eraser ||
                        tool.highlighter ||
                        tool.shape) {
                      return GestureDetector(
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        onScaleEnd: _handleScaleEnd,
                        behavior: HitTestBehavior.opaque,
                        child: wrappedContent,
                      );
                    } else if (tool.grab || tool.mouse) {
                      // Mouse/grab için swipe detect için GestureDetector
                      return GestureDetector(
                        onScaleStart: _handleScaleStart,
                        onScaleUpdate: _handleScaleUpdate,
                        onScaleEnd: _handleScaleEnd,
                        behavior: HitTestBehavior.translucent,
                        child: wrappedContent,
                      );
                    } else {
                      // Diğer modlarda (magnifier dahil) GestureDetector yok
                      return wrappedContent;
                    }
                  },
                ),
              ),
              ValueListenableBuilder<ToolState>(
                valueListenable: toolNotifier,
                builder: (context, currentTool, child) {
                  if (!currentTool.selection) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: Listener(
                      onPointerDown: _handlePointerDown,
                      onPointerMove: _handlePointerMove,
                      onPointerUp: _handlePointerUp,
                      behavior: HitTestBehavior.translucent,
                      child: ValueListenableBuilder<Rect?>(
                        valueListenable: selectedAreaNotifier,
                        builder: (context, selectedRect, child) {
                          if (selectedRect == null) {
                            return Container(color: Colors.transparent);
                          }
                          return CustomPaint(
                            painter: _SelectionPainter(selectedRect),
                            size: Size.infinite,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
              ValueListenableBuilder<ToolState>(
                valueListenable: toolNotifier,
                builder: (context, currentTool, child) {
                  if (!currentTool.magnifier) {
                    return const SizedBox.shrink();
                  }
                  return Positioned.fill(
                    child: Listener(
                      onPointerDown: _handleMagnifierPointerDown,
                      onPointerMove: _handleMagnifierPointerMove,
                      onPointerUp: _handleMagnifierPointerUp,
                      behavior: HitTestBehavior.translucent,
                      child: ValueListenableBuilder<Rect?>(
                        valueListenable: _magnifierAreaNotifier,
                        builder: (context, magnifierRect, child) {
                          if (magnifierRect == null || magnifierRect == Rect.zero) {
                            return Container(color: Colors.transparent);
                          }
                          return CustomPaint(
                            painter: MagnifierPainter(
                              selectedArea: magnifierRect,
                              magnification: 2.0,
                            ),
                            size: Size.infinite,
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    // Return main content with magnified overlay if needed
    return Stack(
      children: [
        RepaintBoundary(
          key: _repaintBoundaryKey,
          child: mainContent,
        ),
        if (_showMagnifiedView && _magnifiedRect != null)
          MagnifiedContentOverlay(
            selectedArea: _magnifiedRect!,
            contentKey: _repaintBoundaryKey,
            magnification: 2.0,
            onClose: () {
              setState(() {
                _showMagnifiedView = false;
                _magnifiedRect = null;
                _magnifierState = MagnifierState();
              });
            },
          ),
      ],
    );
  }
}

class _SelectionPainter extends CustomPainter {
  final Rect rect;

  _SelectionPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}

class _SwipeableImageDialog extends StatefulWidget {
  final List<MapEntry<String, Uint8List>> imageList;
  final int initialIndex;
  final CropData cropData;
  final List<CropItem> cropsForPage;
  final PdfController pdfController;

  const _SwipeableImageDialog({
    required this.imageList,
    required this.initialIndex,
    required this.cropData,
    required this.cropsForPage,
    required this.pdfController,
  });

  @override
  State<_SwipeableImageDialog> createState() => _SwipeableImageDialogState();
}

class _SwipeableImageDialogState extends State<_SwipeableImageDialog> {
  late PageController _pageController;
  late int _currentIndex;
  late List<CropItem> _sortedCrops; // Question number'a göre sıralanmış

  @override
  void initState() {
    super.initState();

    // Crop'ları question_number'a göre sırala
    _sortedCrops = List.from(widget.cropsForPage);
    _sortedCrops.sort((a, b) {
      if (a.questionNumber == null && b.questionNumber == null) return 0;
      if (a.questionNumber == null) return 1;
      if (b.questionNumber == null) return -1;
      return a.questionNumber!.compareTo(b.questionNumber!);
    });

    // Başlangıç index'ini sıralanmış listede bul
    final initialImageFile = widget.imageList[widget.initialIndex].key;
    _currentIndex = _sortedCrops.indexWhere((crop) => crop.imageFile == initialImageFile);
    if (_currentIndex == -1) _currentIndex = 0;

    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.image,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _sortedCrops[_currentIndex].questionNumber != null
                          ? 'Soru ${_sortedCrops[_currentIndex].questionNumber}'
                          : _sortedCrops[_currentIndex].imageFile.split('/').last,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  // Sayfa göstergesi
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${_sortedCrops.length}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
            // PageView ile swipeable image gallery (question number sırasına göre)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemCount: _sortedCrops.length,
                itemBuilder: (context, index) {
                  // Sıralanmış crop listesinden resmi al
                  final crop = _sortedCrops[index];
                  final imageEntry = widget.imageList.firstWhere(
                    (entry) => entry.key == crop.imageFile,
                  );

                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.memory(
                        imageEntry.value,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
            // Alt navigasyon butonları (question number sırasına göre)
            if (_sortedCrops.length > 1)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: _currentIndex > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                    ),
                    const SizedBox(width: 24),
                    Text(
                      'Soru numarasına göre sıralı',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: _currentIndex < _sortedCrops.length - 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
