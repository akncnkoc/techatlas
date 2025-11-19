import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'stroke.dart';
import 'drawing_painter.dart';
import 'tool_state.dart';
import 'drawing_history.dart';
import 'page_time_tracker.dart';
import 'magnifier_overlay.dart';
import 'magnified_content_overlay.dart';
import '../models/crop_data.dart';
import 'widgets/solution_detail_dialog.dart';
import 'dart:math' show cos, sin;

// Import new components and utilities
import '../core/constants/app_constants.dart';
import '../core/utils/matrix_utils.dart' as custom_matrix;

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
      width: 0.7,
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
  static const double _swipeVelocityThreshold =
      AppConstants.swipeVelocityThreshold;
  static const double _swipeDistanceThreshold =
      AppConstants.swipeDistanceThreshold;

  final ValueNotifier<Rect?> selectedAreaNotifier = ValueNotifier<Rect?>(null);
  Offset? _selectionStartScreen;

  // Magnifier state
  MagnifierState _magnifierState = MagnifierState();
  final ValueNotifier<Rect?> _magnifierAreaNotifier = ValueNotifier<Rect?>(
    null,
  );
  bool _showMagnifiedView = false;
  Rect? _magnifiedRect;

  double _lastRenderedScale = 1.0;
  final ValueNotifier<double> _pdfScaleNotifier = ValueNotifier<double>(1.0);

  int _activePointers = 0; // Aktif parmak sayısı

  // Palm rejection: Track if stylus is currently active
  bool _isStylusActive = false;
  DateTime? _lastStylusTime;
  static const Duration _palmRejectionWindow = Duration(milliseconds: 500);

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
    // GestureDetector is OUTSIDE InteractiveViewer
    // So we receive screen coordinates and need to convert to content coordinates
    // This requires inverse of the transformation matrix
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
    if (details.pointerCount == 2 &&
        _scaleStartTransform != null &&
        _scaleStartFocalPoint != null) {
      final scaleChange = details.scale;

      // Zoom limitlerini kontrol et
      final startScale = custom_matrix.MatrixUtils.getScale(
        _scaleStartTransform!,
      );
      final newScale = (startScale * scaleChange).clamp(_minZoom, _maxZoom);

      // Use custom MatrixUtils for zoom transformation
      transformationController.value =
          custom_matrix.MatrixUtils.createZoomTransform(
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
        // InteractiveViewer handles panning itself now (panEnabled = true)
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

  // New pointer handlers for better stylus support
  void _handleDrawingPointerDown(PointerDownEvent event) {
    final tool = toolNotifier.value;

    print(
      "🖊️ Drawing PointerDown: kind=${event.kind}, device=${event.device}, position=${event.localPosition}",
    );

    // Palm rejection: Check if this is a stylus or touch
    final isStylus = event.kind == PointerDeviceKind.stylus;
    final isTouch = event.kind == PointerDeviceKind.touch;

    // If stylus is detected, mark it as active
    if (isStylus) {
      _isStylusActive = true;
      _lastStylusTime = DateTime.now();
      print("✅ Stylus detected - palm rejection active");
    }

    // Reject touch input if stylus was recently active (palm rejection)
    if (isTouch && _isStylusActive && _lastStylusTime != null) {
      final timeSinceStylus = DateTime.now().difference(_lastStylusTime!);
      if (timeSinceStylus < _palmRejectionWindow) {
        print("🚫 Palm rejection: Ignoring touch input (stylus active)");
        return;
      }
    }

    if (_rotationAngle != 0.0) {
      print("⚠️ Rotation is not zero, skipping draw");
      return;
    }

    if (tool.shape) {
      _startShape(event.localPosition);
      print("📐 Shape started with ${event.kind}");
    } else if (tool.pencil || tool.eraser || tool.highlighter) {
      _startStroke(event.localPosition);
      print("✏️ Stroke started with ${event.kind}");
    }
  }

  void _handleDrawingPointerMove(PointerMoveEvent event) {
    if (!_isDrawing && _activeStroke == null) return;

    // Palm rejection: Ignore touch events when stylus is active
    final isTouch = event.kind == PointerDeviceKind.touch;
    if (isTouch && _isStylusActive && _lastStylusTime != null) {
      final timeSinceStylus = DateTime.now().difference(_lastStylusTime!);
      if (timeSinceStylus < _palmRejectionWindow) {
        return; // Silently ignore palm touches
      }
    }

    final tool = toolNotifier.value;

    if (tool.shape) {
      _updateShape(event.localPosition);
    } else if (tool.pencil || tool.eraser || tool.highlighter) {
      _updateStroke(event.localPosition);
    }
  }

  void _handleDrawingPointerUp(PointerUpEvent event) {
    final tool = toolNotifier.value;

    print("🖊️ Drawing PointerUp: kind=${event.kind}");

    // Reset stylus active state when stylus is lifted
    if (event.kind == PointerDeviceKind.stylus) {
      // Keep stylus active for a short window after lifting
      // This helps reject palm touches that happen right after drawing
      print("📝 Stylus lifted - palm rejection window active");
    }

    // Palm rejection: Ignore touch events when stylus is active
    final isTouch = event.kind == PointerDeviceKind.touch;
    if (isTouch && _isStylusActive && _lastStylusTime != null) {
      final timeSinceStylus = DateTime.now().difference(_lastStylusTime!);
      if (timeSinceStylus < _palmRejectionWindow) {
        print("🚫 Palm rejection: Ignoring touch up event");
        return;
      }
    }

    if (tool.shape) {
      _endShape();
    } else if (tool.pencil || tool.eraser || tool.highlighter) {
      _endStroke();
    }
  }

  void _handleDrawingPointerCancel(PointerCancelEvent event) {
    print("❌ Drawing PointerCancel: kind=${event.kind}");

    // Clean up if drawing was cancelled
    if (_isDrawing || _activeStroke != null) {
      setState(() {
        _activeStroke = null;
        _isDrawing = false;
        _shapeStartPoint = null;
      });
    }
  }

  void _startShape(Offset position) {
    final transformedPosition = _transformPoint(position);

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
    print("🖊️ _startStroke called at screen position: $position");
    final transformedPosition = _transformPoint(position);
    print("🔄 Transformed to content position: $transformedPosition");
    print("📊 Current transform matrix: ${transformationController.value}");
    print(
      "🔍 Current scale: ${transformationController.value.getMaxScaleOnAxis()}",
    );

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
      _repaintNotifier.value++;
    } else {
      // Add all points during active drawing for real-time smoothness
      // No distance check - we want immediate feedback
      _activeStroke?.points.add(transformedPosition);
      _repaintNotifier.value++;
    }
  }

  void _endStroke() {
    setState(() {
      // No simplification - keep all points for maximum quality
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
    transformationController.value = Matrix4.identity()
      ..scaleByVector3(Vector3(newScale, newScale, 1));
  }

  void zoomOut() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(_minZoom, _maxZoom);
    transformationController.value = Matrix4.identity()
      ..scaleByVector3(Vector3(newScale, newScale, 1));
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
        _magnifierState = _magnifierState.copyWith(currentPoint: position);
        _magnifierAreaNotifier.value = _magnifierState.getSelectionRect();
      });
    } else if (_magnifierState.isResizing &&
        _magnifierState.selectedArea != null) {
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
        _magnifierState = _magnifierState.copyWith(selectedArea: newArea);
        _magnifierAreaNotifier.value = newArea;
      });
    }
  }

  void _handleMagnifierPointerUp(PointerUpEvent event) {
    final tool = toolNotifier.value;
    if (!tool.magnifier) return;

    if (_magnifierState.isSelecting) {
      final selectionRect = _magnifierState.getSelectionRect();
      if (selectionRect != null &&
          selectionRect.width > 10 &&
          selectionRect.height > 10) {
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
      if (resizedArea != null &&
          resizedArea.width > 10 &&
          resizedArea.height > 10) {
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

      // ÇİZİMLE DESTEKLİ DİYALOG
      showDialog(
        context: context,
        builder: (context) => _SwipeableImageDialog(
          imageList: imageList,
          initialIndex: initialIndex,
          cropData: widget.cropData!,
          cropsForPage: cropsForPage,
          pdfController: widget.controller,
          toolNotifier: toolNotifier,
          zipFilePath: widget.zipFilePath,
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

                return ClipRect(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: cropsForPage.map((crop) {
                      // Yeni JSON ile referans: page_dimensions -> getReferenceSizeForPage
                      // Top-left kökenli koordinat varsayımı (sayfa görüntüsü koordinatları)
                      final scaleX = actualPdfWidth / cropRefWidth;
                      final scaleY = actualPdfHeight / cropRefHeight;

                      final cropScreenX =
                          crop.coordinates.x1 * scaleX + offsetX;
                      final cropScreenY =
                          crop.coordinates.y1 * scaleY + offsetY;

                      const buttonSize = 30.0;
                      final buttonLeft = cropScreenX - buttonSize / 2;
                      final buttonTop = cropScreenY - buttonSize / 2;

                      if (buttonLeft < offsetX - buttonSize ||
                          buttonLeft > offsetX + actualPdfWidth ||
                          buttonTop < offsetY - buttonSize ||
                          buttonTop > offsetY + actualPdfHeight) {
                        return const SizedBox.shrink();
                      }

                      // Check if there's any actual solution data
                      final hasAnswerChoice =
                          (crop.solutionMetadata?.answerChoice != null ||
                          crop.userSolution?.answerChoice != null);
                      final hasExplanation =
                          (crop.solutionMetadata?.explanation != null &&
                              crop.solutionMetadata!.explanation!
                                  .trim()
                                  .isNotEmpty) ||
                          (crop.userSolution?.explanation != null &&
                              crop.userSolution!.explanation!
                                  .trim()
                                  .isNotEmpty);
                      final hasDrawing =
                          (crop.solutionMetadata?.drawingFile != null &&
                              crop.solutionMetadata!.drawingFile!
                                  .trim()
                                  .isNotEmpty) ||
                          (crop.userSolution?.drawingFile != null &&
                              crop.userSolution!.drawingFile!
                                  .trim()
                                  .isNotEmpty);
                      final hasAiSolution =
                          crop.solutionMetadata?.aiSolution != null ||
                          crop.userSolution?.aiSolution != null;

                      final hasSolution =
                          hasAnswerChoice ||
                          hasExplanation ||
                          hasDrawing ||
                          hasAiSolution;
                      final buttonColor = hasSolution
                          ? Colors.green.shade600
                          : Colors.blue.shade600;

                      return Stack(
                        children: [
                          // Buton
                          Positioned(
                            left: buttonLeft,
                            top: buttonTop,
                            child: GestureDetector(
                              onTap: () {
                                print(
                                  'Question ${crop.questionNumber} clicked!',
                                );
                                // Show crop image with answer section
                                _showCropImage(crop.imageFile);
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: buttonSize,
                                    height: buttonSize,
                                    decoration: BoxDecoration(
                                      color: buttonColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
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
                                  // Solution indicator badge
                                  if (hasSolution)
                                    Positioned(
                                      right: -2,
                                      top: -2,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: buttonColor,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 8,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                ],
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
                panEnabled: tool.mouse || tool.grab,
                scaleEnabled: true,
                child: Listener(
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
                      print("👇 Pointer up: $_activePointers active pointers");
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
                  child: Transform.rotate(
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
                  ),
                ),
              ),
              // Drawing Listener OUTSIDE InteractiveViewer for stylus support
              if (tool.pencil || tool.eraser || tool.highlighter || tool.shape)
                Positioned.fill(
                  child: Listener(
                    onPointerDown: _handleDrawingPointerDown,
                    onPointerMove: _handleDrawingPointerMove,
                    onPointerUp: _handleDrawingPointerUp,
                    onPointerCancel: _handleDrawingPointerCancel,
                    behavior: HitTestBehavior.translucent,
                  ),
                ),
              // Mouse/grab swipe detection OUTSIDE InteractiveViewer
              if (tool.grab || tool.mouse)
                Positioned.fill(
                  child: GestureDetector(
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onScaleEnd: _handleScaleEnd,
                    behavior: HitTestBehavior.translucent,
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
                          if (magnifierRect == null ||
                              magnifierRect == Rect.zero) {
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
        RepaintBoundary(key: _repaintBoundaryKey, child: mainContent),
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

// Legend kaldırıldı (debug amaçlıydı)

class _SwipeableImageDialog extends StatefulWidget {
  final List<MapEntry<String, Uint8List>> imageList;
  final int initialIndex;
  final CropData cropData;
  final List<CropItem> cropsForPage;
  final PdfController pdfController;
  final ValueNotifier<ToolState> toolNotifier;
  final String? zipFilePath;

  const _SwipeableImageDialog({
    required this.imageList,
    required this.initialIndex,
    required this.cropData,
    required this.cropsForPage,
    required this.pdfController,
    required this.toolNotifier,
    this.zipFilePath,
  });

  @override
  State<_SwipeableImageDialog> createState() => _SwipeableImageDialogState();
}

class _SwipeableImageDialogState extends State<_SwipeableImageDialog> {
  late PageController _pageController;
  late int _currentIndex;
  late List<CropItem> _sortedCrops; // Question number'a göre sıralanmış

  // Drawing state per image index
  final Map<int, List<Stroke>> _strokesPerIndex = {};
  Stroke? _activeStroke;
  final ValueNotifier<int> _repaintNotifier = ValueNotifier<int>(0);
  final TransformationController _ivController = TransformationController();
  final double _minZoom = AppConstants.minZoom;
  final double _maxZoom = AppConstants.maxZoom;

  // Palm rejection for dialog
  bool _dialogStylusActive = false;
  DateTime? _dialogLastStylusTime;
  static const Duration _dialogPalmRejectionWindow = Duration(milliseconds: 500);

  // Answer section expansion state
  bool _isAnswerExpanded = false;

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
    _currentIndex = _sortedCrops.indexWhere(
      (crop) => crop.imageFile == initialImageFile,
    );
    if (_currentIndex == -1) _currentIndex = 0;

    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _repaintNotifier.dispose();
    _ivController.dispose();
    super.dispose();
  }

  List<Stroke> get _strokes => _strokesPerIndex[_currentIndex] ??= [];

  Offset _transformPoint(Offset point) {
    return custom_matrix.MatrixUtils.transformPoint(_ivController.value, point);
  }

  void _startStroke(Offset position) {
    final transformed = _transformPoint(position);
    final tool = widget.toolNotifier.value;

    if (tool.eraser) {
      _activeStroke = Stroke(color: tool.color, width: tool.width, erase: true);
      _activeStroke!.points.add(transformed);
      _eraseAt(transformed, tool.width);
      _repaintNotifier.value++;
      return;
    }

    _activeStroke = Stroke(
      color: tool.color,
      width: tool.width,
      erase: false,
      isHighlighter: tool.highlighter,
    );
    _activeStroke!.points.add(transformed);
    _strokes.add(_activeStroke!);
    _repaintNotifier.value++;
  }

  void _updateStroke(Offset position) {
    if (_activeStroke == null) return;
    final transformed = _transformPoint(position);
    final tool = widget.toolNotifier.value;

    if (tool.eraser) {
      _activeStroke!.points.add(transformed);
      _eraseAt(transformed, tool.width);
    } else {
      // Add all points during active drawing for real-time smoothness
      // No distance check - we want immediate feedback
      _activeStroke!.points.add(transformed);
    }

    // Always repaint for smooth real-time feedback
    _repaintNotifier.value++;
  }

  void _endStroke() {
    // No simplification - keep all points for maximum quality
    _activeStroke = null;
    _repaintNotifier.value++;
  }

  void _eraseAt(Offset position, double eraserRadius) {
    final List<Stroke> newStrokes = [];
    for (final stroke in _strokes) {
      if (stroke.erase) continue;
      final List<Offset> remaining = [];
      final List<List<Offset>> segments = [];
      for (final point in stroke.points) {
        final distance = (point - position).distance;
        if (distance >= eraserRadius * 1.2) {
          remaining.add(point);
        } else {
          if (remaining.isNotEmpty) {
            segments.add(List.from(remaining));
            remaining.clear();
          }
        }
      }
      if (remaining.isNotEmpty) segments.add(remaining);
      for (final seg in segments) {
        if (seg.length > 1) {
          final ns = Stroke(
            color: stroke.color,
            width: stroke.width,
            erase: false,
          );
          ns.points.addAll(seg);
          newStrokes.add(ns);
        }
      }
    }
    _strokes.removeWhere((s) => !s.erase);
    _strokes.addAll(newStrokes);
  }


  // New pointer handlers for better stylus support in dialog
  void _onPointerDown(PointerDownEvent event) {
    final tool = widget.toolNotifier.value;

    print(
      "🖊️ Dialog PointerDown: kind=${event.kind}, device=${event.device}, position=${event.localPosition}",
    );

    // Palm rejection: Check if this is a stylus or touch
    final isStylus = event.kind == PointerDeviceKind.stylus;
    final isTouch = event.kind == PointerDeviceKind.touch;

    // If stylus is detected, mark it as active
    if (isStylus) {
      _dialogStylusActive = true;
      _dialogLastStylusTime = DateTime.now();
      print("✅ Dialog: Stylus detected - palm rejection active");
    }

    // Reject touch input if stylus was recently active (palm rejection)
    if (isTouch && _dialogStylusActive && _dialogLastStylusTime != null) {
      final timeSinceStylus = DateTime.now().difference(_dialogLastStylusTime!);
      if (timeSinceStylus < _dialogPalmRejectionWindow) {
        print("🚫 Dialog: Palm rejection - Ignoring touch input");
        return;
      }
    }

    if (tool.pencil || tool.highlighter || tool.eraser) {
      _startStroke(event.localPosition);
      print("✏️ Dialog stroke started with ${event.kind}");
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_activeStroke == null) return;

    // Palm rejection: Ignore touch events when stylus is active
    final isTouch = event.kind == PointerDeviceKind.touch;
    if (isTouch && _dialogStylusActive && _dialogLastStylusTime != null) {
      final timeSinceStylus = DateTime.now().difference(_dialogLastStylusTime!);
      if (timeSinceStylus < _dialogPalmRejectionWindow) {
        return; // Silently ignore palm touches
      }
    }

    final tool = widget.toolNotifier.value;

    if (tool.pencil || tool.highlighter || tool.eraser) {
      _updateStroke(event.localPosition);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final tool = widget.toolNotifier.value;

    print("🖊️ Dialog PointerUp: kind=${event.kind}");

    // Keep stylus active for palm rejection window after lifting
    if (event.kind == PointerDeviceKind.stylus) {
      print("📝 Dialog: Stylus lifted - palm rejection window active");
    }

    // Palm rejection: Ignore touch events when stylus is active
    final isTouch = event.kind == PointerDeviceKind.touch;
    if (isTouch && _dialogStylusActive && _dialogLastStylusTime != null) {
      final timeSinceStylus = DateTime.now().difference(_dialogLastStylusTime!);
      if (timeSinceStylus < _dialogPalmRejectionWindow) {
        print("🚫 Dialog: Palm rejection - Ignoring touch up event");
        return;
      }
    }

    if (tool.pencil || tool.highlighter || tool.eraser) {
      _endStroke();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    print("❌ Dialog PointerCancel: kind=${event.kind}");

    if (_activeStroke != null) {
      _activeStroke = null;
      _repaintNotifier.value++;
    }
  }

  Future<Uint8List?> _loadDrawingImage(String drawingPath) async {
    if (widget.zipFilePath == null) return null;

    try {
      final zipBytes = await File(widget.zipFilePath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      Uint8List? imageBytes;
      for (final file in archive) {
        if (file.isFile && file.name == drawingPath) {
          imageBytes = file.content as Uint8List;
          break;
        }
      }

      if (imageBytes == null) return null;

      // Get current crop to determine the height to crop from top
      final crop = _sortedCrops[_currentIndex];
      final cropHeight = crop.coordinates.height;

      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Crop from top: keep only the height of the question (solution area)
      // The drawing file has: question at top, solution below
      // We want to show only the part starting from cropHeight (skipping the question)
      final croppedImage = img.copyCrop(
        image,
        x: 0,
        y: cropHeight, // Start from the end of question
        width: image.width,
        height: image.height - cropHeight, // Remaining height (solution part)
      );

      // Encode back to PNG
      return Uint8List.fromList(img.encodePng(croppedImage));
    } catch (e) {
      print('Error loading/cropping drawing: $e');
    }
    return null;
  }

  Widget _buildAnswerSectionHorizontal() {
    final crop = _sortedCrops[_currentIndex];

    // Check if there's any actual solution data
    final hasAnswerChoice =
        (crop.solutionMetadata?.answerChoice != null ||
        crop.userSolution?.answerChoice != null);
    final hasExplanation =
        (crop.solutionMetadata?.explanation != null &&
            crop.solutionMetadata!.explanation!.trim().isNotEmpty) ||
        (crop.userSolution?.explanation != null &&
            crop.userSolution!.explanation!.trim().isNotEmpty);
    final hasDrawing =
        (crop.solutionMetadata?.drawingFile != null &&
            crop.solutionMetadata!.drawingFile!.trim().isNotEmpty) ||
        (crop.userSolution?.drawingFile != null &&
            crop.userSolution!.drawingFile!.trim().isNotEmpty);
    final hasAiSolution =
        crop.solutionMetadata?.aiSolution != null ||
        crop.userSolution?.aiSolution != null;

    final hasSolution =
        hasAnswerChoice || hasExplanation || hasDrawing || hasAiSolution;

    if (!hasSolution) {
      return const Center(
        child: Text(
          'Çözüm bulunamadı',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Çözüm',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Answer choice (large) - check both metadata and userSolution
            if (crop.solutionMetadata?.answerChoice != null ||
                crop.userSolution?.answerChoice != null) ...[
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      crop.solutionMetadata?.answerChoice ??
                          crop.userSolution?.answerChoice ??
                          '',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Solution type badge
            if (crop.solutionMetadata?.solutionType != null) ...[
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(
                      _getSolutionTypeText(
                        crop.solutionMetadata!.solutionType!,
                      ),
                    ),
                    avatar: Icon(
                      _getSolutionTypeIcon(
                        crop.solutionMetadata!.solutionType!,
                      ),
                      size: 16,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  ...crop.solutionMetadata!.solvedBy.map(
                    (method) => Chip(
                      label: Text(_getMethodText(method)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Manual explanation or drawing
            if ((crop.userSolution?.explanation != null &&
                    crop.userSolution!.explanation!.trim().isNotEmpty) ||
                (crop.solutionMetadata?.explanation != null &&
                    crop.solutionMetadata!.explanation!.trim().isNotEmpty) ||
                (crop.userSolution?.drawingFile != null &&
                    crop.userSolution!.drawingFile!.trim().isNotEmpty) ||
                (crop.solutionMetadata?.drawingFile != null &&
                    crop.solutionMetadata!.drawingFile!.trim().isNotEmpty)) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Manuel Çözüm',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Show explanation if exists
                    if ((crop.userSolution?.explanation != null &&
                            crop.userSolution!.explanation!.trim().isNotEmpty) ||
                        (crop.solutionMetadata?.explanation != null &&
                            crop.solutionMetadata!.explanation!
                                .trim()
                                .isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      Text(
                        crop.userSolution?.explanation?.trim() ??
                            crop.solutionMetadata?.explanation?.trim() ??
                            '',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                    // Show drawing file image if exists
                    if ((crop.userSolution?.drawingFile != null &&
                            crop.userSolution!.drawingFile!.trim().isNotEmpty) ||
                        (crop.solutionMetadata?.drawingFile != null &&
                            crop.solutionMetadata!.drawingFile!
                                .trim()
                                .isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<Uint8List?>(
                        future: _loadDrawingImage(
                          crop.userSolution?.drawingFile ??
                              crop.solutionMetadata?.drawingFile ??
                              '',
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (snapshot.hasError || !snapshot.hasData) {
                            return const SizedBox.shrink();
                          }

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // AI Solution
            if (crop.userSolution?.aiSolution != null ||
                crop.solutionMetadata?.aiSolution != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          size: 18,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AI Çözümü',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getConfidenceColor(
                              (crop.userSolution?.aiSolution ??
                                      crop.solutionMetadata!.aiSolution!)
                                  .confidence,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '%${((crop.userSolution?.aiSolution ?? crop.solutionMetadata!.aiSolution!).confidence * 100).toInt()}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getConfidenceColor(
                                (crop.userSolution?.aiSolution ??
                                        crop.solutionMetadata!.aiSolution!)
                                    .confidence,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (crop.userSolution?.aiSolution ??
                              crop.solutionMetadata!.aiSolution!)
                          .reasoning,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if ((crop.userSolution?.aiSolution ??
                                crop.solutionMetadata!.aiSolution!)
                            .steps
                            .isNotEmpty &&
                        (crop.userSolution?.aiSolution ??
                                crop.solutionMetadata!.aiSolution!)
                            .steps
                            .first
                            .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Adımlar:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...(crop.userSolution?.aiSolution ??
                              crop.solutionMetadata!.aiSolution!)
                          .steps
                          .map(
                            (step) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  Expanded(
                                    child: Text(
                                      step,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Detailed Solution Button
            if (crop.userSolution?.hasAnimationData == true ||
                crop.userSolution?.drawingDataFile != null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final zipDir = widget.zipFilePath != null
                        ? File(widget.zipFilePath!).parent.path
                        : '';
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => SolutionDetailDialog(
                        crop: crop,
                        baseDirectory: zipDir,
                        zipFilePath: widget.zipFilePath,
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Animasyonlu Çözümü İzle'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection() {
    final crop = _sortedCrops[_currentIndex];

    // Check if there's any actual solution data
    final hasAnswerChoice =
        (crop.solutionMetadata?.answerChoice != null ||
        crop.userSolution?.answerChoice != null);
    final hasExplanation =
        (crop.solutionMetadata?.explanation != null &&
            crop.solutionMetadata!.explanation!.trim().isNotEmpty) ||
        (crop.userSolution?.explanation != null &&
            crop.userSolution!.explanation!.trim().isNotEmpty);
    final hasDrawing =
        (crop.solutionMetadata?.drawingFile != null &&
            crop.solutionMetadata!.drawingFile!.trim().isNotEmpty) ||
        (crop.userSolution?.drawingFile != null &&
            crop.userSolution!.drawingFile!.trim().isNotEmpty);
    final hasAiSolution =
        crop.solutionMetadata?.aiSolution != null ||
        crop.userSolution?.aiSolution != null;

    final hasSolution =
        hasAnswerChoice || hasExplanation || hasDrawing || hasAiSolution;

    if (!hasSolution) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Always visible
          InkWell(
            onTap: () {
              setState(() {
                _isAnswerExpanded = !_isAnswerExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Çözüm',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  Icon(
                    _isAnswerExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Answer choice (large) - check both metadata and userSolution
                  if (crop.solutionMetadata?.answerChoice != null ||
                      crop.userSolution?.answerChoice != null) ...[
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            crop.solutionMetadata?.answerChoice ??
                                crop.userSolution?.answerChoice ??
                                '',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Solution type badge
                  if (crop.solutionMetadata?.solutionType != null) ...[
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            _getSolutionTypeText(
                              crop.solutionMetadata!.solutionType!,
                            ),
                          ),
                          avatar: Icon(
                            _getSolutionTypeIcon(
                              crop.solutionMetadata!.solutionType!,
                            ),
                            size: 16,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        ...crop.solutionMetadata!.solvedBy.map(
                          (method) => Chip(
                            label: Text(_getMethodText(method)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Manual explanation or drawing - check both metadata and userSolution
                  if ((crop.userSolution?.explanation != null &&
                          crop.userSolution!.explanation!.trim().isNotEmpty) ||
                      (crop.solutionMetadata?.explanation != null &&
                          crop.solutionMetadata!.explanation!
                              .trim()
                              .isNotEmpty) ||
                      (crop.userSolution?.drawingFile != null &&
                          crop.userSolution!.drawingFile!.trim().isNotEmpty) ||
                      (crop.solutionMetadata?.drawingFile != null &&
                          crop.solutionMetadata!.drawingFile!
                              .trim()
                              .isNotEmpty)) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Manuel Çözüm',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          // Show explanation if exists
                          if ((crop.userSolution?.explanation != null &&
                                  crop.userSolution!.explanation!
                                      .trim()
                                      .isNotEmpty) ||
                              (crop.solutionMetadata?.explanation != null &&
                                  crop.solutionMetadata!.explanation!
                                      .trim()
                                      .isNotEmpty)) ...[
                            const SizedBox(height: 8),
                            Text(
                              crop.userSolution?.explanation?.trim() ??
                                  crop.solutionMetadata?.explanation?.trim() ??
                                  '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                          // Show drawing file image if exists
                          if ((crop.userSolution?.drawingFile != null &&
                                  crop.userSolution!.drawingFile!
                                      .trim()
                                      .isNotEmpty) ||
                              (crop.solutionMetadata?.drawingFile != null &&
                                  crop.solutionMetadata!.drawingFile!
                                      .trim()
                                      .isNotEmpty)) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.draw,
                                  size: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Çizim',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FutureBuilder<Uint8List?>(
                              future: _loadDrawingImage(
                                crop.userSolution?.drawingFile ??
                                    crop.solutionMetadata?.drawingFile ??
                                    '',
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                if (snapshot.hasError ||
                                    !snapshot.hasData ||
                                    snapshot.data == null) {
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Çizim yüklenemedi',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 300,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // AI Solution
                  if (crop.userSolution?.aiSolution != null ||
                      crop.solutionMetadata?.aiSolution != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.psychology,
                                size: 16,
                                color: Colors.purple.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AI Çözümü',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getConfidenceColor(
                                    (crop.userSolution?.aiSolution ??
                                            crop.solutionMetadata!.aiSolution!)
                                        .confidence,
                                  ).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '%${((crop.userSolution?.aiSolution ?? crop.solutionMetadata!.aiSolution!).confidence * 100).toInt()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getConfidenceColor(
                                      (crop.userSolution?.aiSolution ??
                                              crop
                                                  .solutionMetadata!
                                                  .aiSolution!)
                                          .confidence,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (crop.userSolution?.aiSolution ??
                                    crop.solutionMetadata!.aiSolution!)
                                .reasoning,
                            style: const TextStyle(fontSize: 12),
                          ),
                          if ((crop.userSolution?.aiSolution ??
                                      crop.solutionMetadata!.aiSolution!)
                                  .steps
                                  .isNotEmpty &&
                              (crop.userSolution?.aiSolution ??
                                      crop.solutionMetadata!.aiSolution!)
                                  .steps
                                  .first
                                  .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Text(
                              'Adımlar:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ...(crop.userSolution?.aiSolution ??
                                    crop.solutionMetadata!.aiSolution!)
                                .steps
                                .map(
                                  (step) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 2,
                                      left: 8,
                                    ),
                                    child: Text(
                                      step,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Detailed Solution Button
                  if (crop.userSolution?.hasAnimationData == true ||
                      crop.userSolution?.drawingDataFile != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final zipDir = widget.zipFilePath != null
                              ? File(widget.zipFilePath!).parent.path
                              : '';
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => SolutionDetailDialog(
                              crop: crop,
                              baseDirectory: zipDir,
                              zipFilePath: widget.zipFilePath,
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_circle_outline, size: 20),
                        label: const Text('Animasyonlu Çözümü İzle'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.tertiary,
                          foregroundColor: Theme.of(context).colorScheme.onTertiary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState: _isAnswerExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  String _getSolutionTypeText(String type) {
    switch (type) {
      case 'manual':
        return 'Manuel';
      case 'ai':
        return 'AI';
      case 'mixed':
        return 'Karma';
      default:
        return type;
    }
  }

  IconData _getSolutionTypeIcon(String type) {
    switch (type) {
      case 'manual':
        return Icons.edit;
      case 'ai':
        return Icons.psychology;
      case 'mixed':
        return Icons.merge_type;
      default:
        return Icons.help;
    }
  }

  String _getMethodText(String method) {
    switch (method) {
      case 'manual':
        return 'Manuel';
      case 'ai':
        return 'AI';
      case 'drawing':
        return 'Çizim';
      default:
        return method;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
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
                          : _sortedCrops[_currentIndex].imageFile
                                .split('/')
                                .last,
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
            // Horizontal Layout: Image on left, Solution on right
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side - Image Gallery
                  Expanded(
                    flex: 2,
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const PageScrollPhysics(),
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

                        final strokes = _strokesPerIndex[index] ??= [];

                        return Stack(
                          children: [
                            InteractiveViewer(
                              transformationController: _ivController,
                              minScale: _minZoom,
                              maxScale: _maxZoom,
                              panEnabled: true,
                              scaleEnabled: true,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.memory(
                                      imageEntry.value,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: _repaintNotifier,
                                      builder: (_, __, ___) {
                                        return CustomPaint(
                                          painter: DrawingPainter(strokes: strokes),
                                          size: Size.infinite,
                                          child: Container(),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Listener OUTSIDE InteractiveViewer for stylus support
                            Positioned.fill(
                              child: Listener(
                                onPointerDown: _onPointerDown,
                                onPointerMove: _onPointerMove,
                                onPointerUp: _onPointerUp,
                                onPointerCancel: _onPointerCancel,
                                behavior: HitTestBehavior.translucent,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Divider
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),

                  // Right Side - Solution Section (Always visible)
                  Expanded(
                    flex: 1,
                    child: _buildAnswerSectionHorizontal(),
                  ),
                ],
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
