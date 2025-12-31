import 'dart:io';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:archive/archive.dart';

import 'package:provider/provider.dart';
import 'stroke.dart';
import 'drawing_painter.dart';
import 'tool_state.dart';
import 'drawing_history.dart';
import 'page_time_tracker.dart';
import 'magnifier_overlay.dart';
import 'magnified_content_overlay.dart';
import 'drawing_provider.dart';
import 'package:techatlas/viewer/solution_panel.dart';

import 'package:techatlas/viewer/widgets/drawable_content_widget.dart';
import '../models/crop_data.dart';

import 'dart:math' as math;

// Import new components and utilities
import '../core/constants/app_constants.dart';
import '../core/utils/matrix_utils.dart' as custom_matrix;
import '../core/extensions/pdf_viewer_controller_extensions.dart';

class PdfViewerWithDrawing extends StatefulWidget {
  final PdfViewerController controller;
  final Future<PdfDocument> documentRef;
  final CropData? cropData;
  final String? zipFilePath;
  final Uint8List? zipBytes; // Web platformu için zip bytes

  const PdfViewerWithDrawing({
    super.key,
    required this.controller,
    required this.documentRef,
    this.cropData,
    this.zipFilePath,
    this.zipBytes,
  });

  @override
  State<PdfViewerWithDrawing> createState() => PdfViewerWithDrawingState();
}

class PdfViewerWithDrawingState extends State<PdfViewerWithDrawing> {
  final Map<int, List<Stroke>> _pageStrokes = {};
  Stroke? _activeStroke;
  final ValueNotifier<int> _repaintNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _historyNotifier = ValueNotifier<int>(0);

  // Optimize: Batch repaint updates
  int _pointsSinceLastRepaint = 0;
  static const int _repaintBatchSize =
      3; // Repaint every 3 points instead of every point
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

  // int _activePointers = 0; // Aktif parmak sayısı
  // bool _wasMultiTouch = false; // Çoklu dokunma kontrolü

  // Crop data page indexing check
  bool? _isCropDataZeroBased;

  bool get _isZeroBased {
    if (_isCropDataZeroBased != null) return _isCropDataZeroBased!;
    if (widget.cropData == null || widget.cropData!.objects.isEmpty) {
      _isCropDataZeroBased = false; // Default to 1-based if no data
      return false;
    }
    // Check if any page number is 0
    _isCropDataZeroBased = widget.cropData!.objects.any(
      (c) => c.pageNumber == 0,
    );
    return _isCropDataZeroBased!;
  }

  @override
  void didUpdateWidget(PdfViewerWithDrawing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cropData != oldWidget.cropData) {
      _isCropDataZeroBased = null;
    }
  }

  // Palm rejection: Track if stylus is currently active
  bool _isStylusActive = false;
  DateTime? _lastStylusTime;
  static const Duration _palmRejectionWindow = Duration(milliseconds: 500);

  // RepaintBoundary key for capturing content
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // DrawingProvider listener
  DrawingProvider? _drawingProvider;
  double _lastProviderZoom = 1.0;
  late final FocusNode _focusNode;
  double _lastProviderRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Request focus after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    // pdfrx: Controller listener now tracks page changes via onPageChanged callback
    // or by listening to controller changes and checking pageNumber
    widget.controller.addListener(_onPageChanged);
    transformationController.addListener(_onTransformChanged);

    _timeTracker = PageTimeTracker(onUpdate: _updateTimeDisplay);
    _timeTracker.onPageChanged(_currentPage);
    _timeTracker.startTimer();

    _saveToHistory();

    // Listen to DrawingProvider changes after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _drawingProvider = context.read<DrawingProvider>();
        _drawingProvider!.addListener(_onDrawingProviderChanged);
        // Initialize current page from controller when ready
        if (widget.controller.isReady && widget.controller.pageNumber != null) {
          _currentPage = widget.controller.pageNumber!;
          _drawingProvider?.setCurrentPage(_currentPage);
        }
      }
    });
  }

  void _onDrawingProviderChanged() {
    if (_drawingProvider == null) return;

    // Handle zoom changes
    final newZoom = _drawingProvider!.zoomLevel;
    if ((newZoom - _lastProviderZoom).abs() > 0.01) {
      _lastProviderZoom = newZoom;
      setState(() {
        transformationController.value = Matrix4.identity()
          ..scaleByVector3(Vector3(newZoom, newZoom, 1.0));
      });
    }

    // Handle rotation changes
    final newRotation = _drawingProvider!.rotationAngle;
    if ((newRotation - _lastProviderRotation).abs() > 0.01) {
      _lastProviderRotation = newRotation;
      setState(() {
        _rotationAngle = newRotation;
      });
    }
  }

  void _onPageChanged() {
    // pdfrx: Check if page number has changed
    if (!widget.controller.isReady || widget.controller.pageNumber == null) {
      return;
    }

    final page = widget.controller.pageNumber!;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      _drawingProvider?.setCurrentPage(page); // Update provider
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
    widget.controller.removeListener(_onPageChanged);
    transformationController.removeListener(_onTransformChanged);
    transformationController.dispose();
    _repaintNotifier.dispose();
    _historyNotifier.dispose();
    selectedAreaNotifier.dispose();
    _magnifierAreaNotifier.dispose();
    _pdfScaleNotifier.dispose();
    _canUndoNotifier.dispose();
    _canRedoNotifier.dispose();
    _timeTracker.dispose();
    _drawingProvider?.removeListener(_onDrawingProviderChanged);
    _currentPageTimeNotifier.dispose();
    _focusNode.dispose();
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

    // 2 parmak: Zoom için başlangıç transformu ve focal point'i kaydet
    if (details.pointerCount == 2) {
      _scaleStartTransform = Matrix4.copy(transformationController.value);
      _scaleStartFocalPoint = details.localFocalPoint;

      return;
    }

    // Sadece 1 parmak işlemlerini yönet
    if (details.pointerCount == 1) {
      if (tool.grab || tool.mouse) {
        _isPanning = true;
        _panStartPosition = details.localFocalPoint;
      } else if (tool.shape || tool.pencil || tool.eraser || tool.highlighter) {
        if (_rotationAngle != 0.0) {
          return;
        }
        if (tool.shape) {
          _startShape(details.localFocalPoint);
        } else {
          _startStroke(details.localFocalPoint);
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
      if (_panStartPosition != null && _panLastPosition != null) {
        final distance = _panLastPosition! - _panStartPosition!;

        // Use fling velocity from gesture details for more accurate swipe detection
        final velocity = details.velocity.pixelsPerSecond.dy;

        // Dikey swipe - dy kullan (yatay yerine)
        final isVerticalSwipe = distance.dy.abs() > distance.dx.abs() * 1.2;

        final isFastEnough = velocity.abs() > _swipeVelocityThreshold;
        final isLongEnough = distance.dy.abs() > _swipeDistanceThreshold;

        // Check if zoomed in
        final currentScale = transformationController.value.getMaxScaleOnAxis();
        final isZoomedIn = currentScale > 1.05;

        if (isVerticalSwipe && isFastEnough && isLongEnough && !isZoomedIn) {
          setState(() {
            transformationController.value = Matrix4.identity();
            _lastRenderedScale = 1.0;
            _pdfScaleNotifier.value = 1.0;
          });

          // Yukarı kaydırma (negatif velocity) -> Sonraki sayfa
          // Aşağı kaydırma (pozitif velocity) -> Önceki sayfa
          if (velocity < 0) {
            widget.controller.nextPage();
          } else {
            widget.controller.previousPage();
          }
        }
      }

      _isPanning = false;
      _panStartPosition = null;
      _panLastPosition = null;
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

    // Palm rejection: Check if this is a stylus or touch
    final isStylus = event.kind == PointerDeviceKind.stylus;
    final isTouch = event.kind == PointerDeviceKind.touch;

    // If stylus is detected, mark it as active
    if (isStylus) {
      _isStylusActive = true;
      _lastStylusTime = DateTime.now();
    }

    // Reject touch input if stylus was recently active (palm rejection)
    if (isTouch && _isStylusActive && _lastStylusTime != null) {
      final timeSinceStylus = DateTime.now().difference(_lastStylusTime!);
      if (timeSinceStylus < _palmRejectionWindow) {
        return;
      }
    }

    if (_rotationAngle != 0.0) {
      return;
    }

    if (tool.shape) {
      _startShape(event.localPosition);
    } else if (tool.pencil || tool.eraser || tool.highlighter) {
      _startStroke(event.localPosition);
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

    // Reset stylus active state when stylus is lifted
    if (event.kind == PointerDeviceKind.stylus) {
      // Keep stylus active for a short window after lifting
      // This helps reject palm touches that happen right after drawing
    }

    // Palm rejection: Ignore touch events when stylus is active
    final isTouch = event.kind == PointerDeviceKind.touch;
    if (isTouch && _isStylusActive && _lastStylusTime != null) {
      final timeSinceStylus = DateTime.now().difference(_lastStylusTime!);
      if (timeSinceStylus < _palmRejectionWindow) {
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
        case ShapeType.triangle:
          strokeType = StrokeType.triangle;
          break;
        case ShapeType.star:
          strokeType = StrokeType.star;
          break;
        case ShapeType.pentagon:
          strokeType = StrokeType.pentagon;
          break;
        case ShapeType.hexagon:
          strokeType = StrokeType.hexagon;
          break;
        case ShapeType.ellipse:
          strokeType = StrokeType.ellipse;
          break;
        case ShapeType.doubleArrow:
          strokeType = StrokeType.doubleArrow;
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
      _historyNotifier.value++;
    });
    _saveToHistory();
  }

  void _startStroke(Offset position) {
    final transformedPosition = _transformPoint(position);

    // İlk çizimse boş durumu kaydet
    if (!_history.canUndo(_currentPage) && !_history.canRedo(_currentPage)) {
      _saveToHistory();
    }

    setState(() {
      _isDrawing = true;
      _pointsSinceLastRepaint = 0; // Reset batch counter for new stroke

      final tool = toolNotifier.value;

      if (tool.eraser) {
        _activeStroke = Stroke(
          color: tool.color,
          width: tool.width,
          erase: true,
        );
        _activeStroke!.points.add(transformedPosition);
        _eraseAt(
          transformedPosition,
          tool.width * 15,
        ); // Daha büyük silgi alanı

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
    });
  }

  void _updateStroke(Offset position) {
    if (!_isDrawing && _activeStroke == null) return;

    final transformedPosition = _transformPoint(position);
    final tool = toolNotifier.value;

    if (tool.eraser) {
      _activeStroke?.addPoint(transformedPosition);
      _eraseAt(transformedPosition, tool.width * 15); // Daha büyük silgi alanı

      // Optimize: Batch repaint - update every 3 points instead of every point
      _pointsSinceLastRepaint++;
      if (_pointsSinceLastRepaint >= _repaintBatchSize) {
        _repaintNotifier.value++;
        _pointsSinceLastRepaint = 0;
      }
    } else {
      // Add all points during active drawing for real-time smoothness
      // No distance check - we want immediate feedback
      _activeStroke?.addPoint(transformedPosition);

      // Optimize: Batch repaint - update every 3 points instead of every point
      _pointsSinceLastRepaint++;
      if (_pointsSinceLastRepaint >= _repaintBatchSize) {
        _repaintNotifier.value++;
        _pointsSinceLastRepaint = 0;
      }
    }
  }

  void _endStroke() {
    // Reset batch counter and force final repaint
    _pointsSinceLastRepaint = 0;

    setState(() {
      // No simplification - keep all points for maximum quality
      _activeStroke = null;
      _isDrawing = false;
      _repaintNotifier.value++; // Clear active stroke
      _historyNotifier.value++; // Update history layer
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

        // Optimize: Use squared distance to avoid expensive sqrt()
        final eraserRadiusSq =
            eraserRadius * eraserRadius * 0.64; // 0.8^2 = 0.64

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

    // Invalidate cache since we modified past strokes
    setState(() {
      _repaintNotifier.value++; // Trigger repaint
    });
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
        // Optimize: Reduce points from radius*2 to max(16, radius/5)
        // This gives 16-200 points instead of 100-2000 points
        final steps = (radius / 5).ceil().clamp(16, 200);

        for (int i = 0; i < steps; i++) {
          final angle = (i / steps) * 2 * math.pi;
          expandedPoints.add(
            Offset(
              center.dx + radius * math.cos(angle),
              center.dy + radius * math.sin(angle),
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
          final angle = (i / steps) * 2 * math.pi;
          expandedPoints.add(
            Offset(
              center.dx + radiusX * math.cos(angle),
              center.dy + radiusY * math.sin(angle),
            ),
          );
        }
        break;

      case StrokeType.triangle:
        final start = p1;
        final end = p2;
        final top = Offset((start.dx + end.dx) / 2, start.dy);
        final bottomRight = Offset(end.dx, end.dy);
        final bottomLeft = Offset(start.dx, end.dy);

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
          final angle = (i * math.pi / points) - math.pi / 2;
          final r = (i.isEven ? radius : radius * innerRadiusRatio);
          final current = Offset(
            center.dx + r * math.cos(angle),
            center.dy + r * math.sin(angle),
          );

          final nextAngle = ((i + 1) * math.pi / points) - math.pi / 2;
          final nextR = ((i + 1).isEven ? radius : radius * innerRadiusRatio);
          final next = Offset(
            center.dx + nextR * math.cos(nextAngle),
            center.dy + nextR * math.sin(nextAngle),
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
      final angle = (i * 2 * math.pi / sides) - math.pi / 2;
      final nextAngle = ((i + 1) * 2 * math.pi / sides) - math.pi / 2;

      final current = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      final next = Offset(
        center.dx + radius * math.cos(nextAngle),
        center.dy + radius * math.sin(nextAngle),
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

  void clearCurrentPage() {
    _strokes.clear();
    setState(() {
      _repaintNotifier.value++;
      _historyNotifier.value++;
    });
    _saveToHistory();
  }

  void undo() {
    final previousState = _history.undo(_currentPage);
    if (previousState != null) {
      setState(() {
        _pageStrokes[_currentPage] = previousState;
        _repaintNotifier.value++;
        _historyNotifier.value++;
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
        _historyNotifier.value++;
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

    final position = _transformPoint(event.localPosition);
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

    final position = _transformPoint(event.localPosition);

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
    // Web'de zipBytes, mobil/desktop'ta zipFilePath kullan
    if (widget.zipFilePath == null && widget.zipBytes == null) {
      return;
    }

    try {
      // Zip bytes'ı al (web'den veya dosyadan)
      final Uint8List zipBytesData;
      if (widget.zipBytes != null) {
        // Web platformu - bytes kullan
        zipBytesData = widget.zipBytes!;
      } else {
        // Mobil/Desktop - dosyadan oku
        zipBytesData = await File(widget.zipFilePath!).readAsBytes();
      }

      final archive = ZipDecoder().decodeBytes(zipBytesData);

      // Mevcut sayfadaki tüm crop'ları al
      final targetPage = _isZeroBased ? _currentPage - 1 : _currentPage;
      final cropsForPage = widget.cropData!.getCropsForPage(targetPage);

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
          zipBytes: widget.zipBytes,
        ),
      );
    } catch (e) {
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
      return const SizedBox.shrink();
    }

    final targetPage = _isZeroBased ? _currentPage - 1 : _currentPage;
    final cropsForPage = widget.cropData!.getCropsForPage(targetPage);

    if (cropsForPage.isEmpty) {
      return const SizedBox.shrink();
    }

    // pdfrx: Use documentRef instead of controller.document
    return FutureBuilder<PdfDocument>(
      future: widget.documentRef,
      builder: (context, docSnapshot) {
        if (!docSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        // pdfrx: Use pages list (0-indexed)
        final pdfPage = docSnapshot.data!.pages[_currentPage - 1];
        final pdfWidth = pdfPage.width;
        final pdfHeight = pdfPage.height;

        final cropReferenceSize = widget.cropData!.getReferenceSizeForPage(
          targetPage,
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
                clipBehavior: Clip.none,
                children: cropsForPage.map((crop) {
                  final scaleX = actualPdfWidth / cropRefWidth;
                  final scaleY = actualPdfHeight / cropRefHeight;

                  final cropScreenX = crop.coordinates.x1 * scaleX + offsetX;
                  final cropScreenY = crop.coordinates.y1 * scaleY + offsetY;

                  const buttonSize = 38.0;
                  final buttonLeft = cropScreenX - buttonSize / 2;
                  final buttonTop = cropScreenY - buttonSize / 2;

                  if (buttonLeft < offsetX - buttonSize ||
                      buttonLeft > offsetX + actualPdfWidth ||
                      buttonTop < offsetY - buttonSize ||
                      buttonTop > offsetY + actualPdfHeight) {
                    return const SizedBox.shrink();
                  }

                  final hasAnswerChoice =
                      (crop.solutionMetadata?.answerChoice != null ||
                      crop.userSolution?.answerChoice != null);
                  final hasExplanation =
                      (crop.solutionMetadata?.explanation != null &&
                          crop.solutionMetadata!.explanation!
                              .trim()
                              .isNotEmpty) ||
                      (crop.userSolution?.explanation != null &&
                          crop.userSolution!.explanation!.trim().isNotEmpty);
                  final hasDrawing =
                      (crop.solutionMetadata?.drawingFile != null &&
                          crop.solutionMetadata!.drawingFile!
                              .trim()
                              .isNotEmpty) ||
                      (crop.userSolution?.drawingFile != null &&
                          crop.userSolution!.drawingFile!.trim().isNotEmpty);
                  final hasAiSolution =
                      crop.solutionMetadata?.aiSolution != null ||
                      crop.userSolution?.aiSolution != null;

                  final hasSolution =
                      hasAnswerChoice ||
                      hasExplanation ||
                      hasDrawing ||
                      hasAiSolution;

                  return Stack(
                    children: [
                      // Buton
                      Positioned(
                        left: buttonLeft,
                        top: buttonTop,
                        child: GestureDetector(
                          onTap: () {
                            _showCropImage(crop.imageFile);
                          },
                          child: Container(
                            width: buttonSize,
                            height: buttonSize,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: hasSolution
                                    ? [
                                        Colors.green.shade500,
                                        Colors.green.shade700,
                                      ]
                                    : [
                                        Colors.blue.shade500,
                                        Colors.blue.shade700,
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (hasSolution
                                              ? Colors.green.shade700
                                              : Colors.blue.shade700)
                                          .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Inner glow effect
                                Center(
                                  child: Container(
                                    width: buttonSize - 8,
                                    height: buttonSize - 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.white.withValues(alpha: 0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Number text
                                Center(
                                  child: Text(
                                    "?",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Solution indicator badge
                                if (hasSolution)
                                  Positioned(
                                    right: -1,
                                    top: -1,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.amber.shade300,
                                            Colors.amber.shade500,
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.amber.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
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
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ToolState>(
      valueListenable: toolNotifier,
      builder: (context, tool, _) {
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
        focusNode: _focusNode,
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
              ValueListenableBuilder<Matrix4>(
                valueListenable: transformationController,
                builder: (context, matrix, child) {
                  // final currentScale = matrix.getMaxScaleOnAxis();
                  return InteractiveViewer(
                    transformationController: transformationController,
                    minScale: _minZoom,
                    maxScale: _maxZoom,
                    boundaryMargin: EdgeInsets.zero,
                    panEnabled: !tool.pencil &&
                        !tool.eraser &&
                        !tool.highlighter &&
                        !tool.shape,
                    scaleEnabled: true,
                    onInteractionEnd: (details) {
                      // Swipe detection logic
                      if (details.velocity.pixelsPerSecond.dy.abs() > 200) {
                        final velocity = details.velocity.pixelsPerSecond.dy;
                        if (velocity < 0) {
                          // Swipe Up -> Next Page
                          widget.controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          // Swipe Down -> Previous Page
                          widget.controller.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      }
                    },
                    child: Listener(
                      onPointerDown: (event) {
                        // setState(() {
                        //   _activePointers++;
                        //   if (_activePointers > 1) {
                        //     _wasMultiTouch = true;
                        //   } else if (_activePointers == 1) {
                        //     // Yeni gesture başlıyor
                        //     _wasMultiTouch = false;
                        //   }
                        // });
                      },
                      onPointerUp: (event) {
                        // setState(() {
                        //   _activePointers--;
                        // });
                      },
                      onPointerCancel: (event) {
                        // setState(() {
                        //   _activePointers--;
                        // });
                      },
                      child: child!,
                    ),
                  );
                },
                child: Transform.rotate(
                  angle: _rotationAngle,
                  child: Stack(
                    children: [
                      // pdfrx: Use FutureBuilder to load document then wrap in PdfDocumentRefDirect
                      FutureBuilder<PdfDocument>(
                        future: widget.documentRef,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: Text('Failed to load PDF'),
                            );
                          }
                          return IgnorePointer(
                            child: PdfViewer(
                              PdfDocumentRefDirect(snapshot.data!),
                              controller: widget.controller,
                              params: PdfViewerParams(
                                boundaryMargin: EdgeInsets.zero,
                                minScale: 0.1, // Allow zooming out for fitZoom
                                maxScale: 20.0, // Allow zooming in if needed
                                layoutPages: (pages, params) {
                                  // Tek sayfa dikey düzen - sayfalar ekran genişliğine sığacak şekilde
                                  if (pages.isEmpty) {
                                    return PdfPageLayout(
                                      pageLayouts: [],
                                      documentSize: Size.zero,
                                    );
                                  }

                                  final margin = params.margin;

                                  // Tüm sayfaların maksimum genişliğini bul
                                  final maxWidth = pages.fold<double>(
                                    0.0,
                                    (prev, page) =>
                                        prev > page.width ? prev : page.width,
                                  );

                                  final pageLayouts = <Rect>[];
                                  double y = margin;

                                  for (var page in pages) {
                                    // Sayfayı genişliğe göre ölçekle
                                    final pageHeight =
                                        page.height * maxWidth / page.width;
                                    pageLayouts.add(
                                      Rect.fromLTWH(
                                        margin,
                                        y,
                                        maxWidth,
                                        pageHeight,
                                      ),
                                    );
                                    y += pageHeight + margin;
                                  }

                                  return PdfPageLayout(
                                    pageLayouts: pageLayouts,
                                    documentSize: Size(
                                      maxWidth + margin * 2,
                                      y,
                                    ),
                                  );
                                },
                                // Başlangıç zoom seviyesini ekran genişliğine göre ayarla
                                calculateInitialZoom:
                                    (document, controller, fitZoom, coverZoom) {
                                      // fitZoom kullan - sayfa ekran genişliğine sığar
                                      return fitZoom;
                                    },
                                // Disable inner pan to avoid conflict
                                panEnabled: false,
                                scrollByMouseWheel:
                                    2.0, // Increased sensitivity
                                onViewerReady: (document, controller) {
                                  // Viewer hazır olduğunda ilk sayfa bilgisini ayarla
                                  if (mounted &&
                                      controller.pageNumber != null &&
                                      controller.pageNumber != _currentPage) {
                                    setState(
                                      () =>
                                          _currentPage = controller.pageNumber!,
                                    );
                                  }
                                },
                                onPageChanged: (pageNumber) {
                                  if (pageNumber != null &&
                                      pageNumber != _currentPage &&
                                      mounted) {
                                    // Controller hazır olana kadar bekle
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(
                                              () => _currentPage = pageNumber,
                                            );
                                            _repaintNotifier.value++;
                                            _updateUndoRedoState();
                                            _timeTracker.onPageChanged(
                                              pageNumber,
                                            );
                                          }
                                        });
                                  }
                                },
                                backgroundColor: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      // Layer 1: History (Static) - Wrapped in RepaintBoundary
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: ValueListenableBuilder<int>(
                            valueListenable: _historyNotifier,
                            builder: (_, __, ___) {
                              return CustomPaint(
                                painter: HistoryPainter(
                                  strokes: _strokes,
                                  repaintVersion: _historyNotifier.value,
                                ),
                                size: Size.infinite,
                                isComplex: true,
                                willChange: false,
                              );
                            },
                          ),
                        ),
                      ),
                      // Layer 2: Active Stroke (Dynamic)
                      Positioned.fill(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _repaintNotifier,
                          builder: (_, __, ___) {
                            return CustomPaint(
                              painter: ActiveStrokePainter(
                                activeStroke: _activeStroke,
                              ),
                              size: Size.infinite,
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
              // Drawing Listener OUTSIDE InteractiveViewer for stylus support
              if (tool.pencil || tool.eraser || tool.highlighter || tool.shape)
                Positioned.fill(
                  child: GestureDetector(
                    // Block InteractiveViewer panning by claiming the gesture
                    onScaleStart: (_) {},
                    onScaleUpdate: (_) {},
                    onScaleEnd: (_) {},
                    behavior: HitTestBehavior.translucent,
                    child: Listener(
                      onPointerDown: _handleDrawingPointerDown,
                      onPointerMove: _handleDrawingPointerMove,
                      onPointerUp: _handleDrawingPointerUp,
                      onPointerCancel: _handleDrawingPointerCancel,
                      behavior: HitTestBehavior.translucent,
                    ),
                  ),
                ),
              // Grab swipe detection OUTSIDE InteractiveViewer (mouse mode uses native InteractiveViewer panning)
              if (tool.grab)
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

                          // Transform content-space rect to screen-space for display
                          final screenSpaceRect =
                              custom_matrix.MatrixUtils.transformRect(
                                transformationController.value,
                                magnifierRect,
                              );

                          return CustomPaint(
                            painter: MagnifierPainter(
                              selectedArea: screenSpaceRect,
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
          Builder(
            builder: (context) {
              // Transform content-space rect to screen-space rect
              final screenSpaceRect = custom_matrix.MatrixUtils.transformRect(
                transformationController.value,
                _magnifiedRect!,
              );

              return Positioned.fill(
                child: MagnifiedContentOverlay(
                  selectedArea: screenSpaceRect,
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
              );
            },
          ),
      ],
    );
      },
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
  final PdfViewerController pdfController;
  final ValueNotifier<ToolState> toolNotifier;
  final String? zipFilePath;
  final Uint8List? zipBytes; // Web platformu için

  const _SwipeableImageDialog({
    required this.imageList,
    required this.initialIndex,
    required this.cropData,
    required this.cropsForPage,
    required this.pdfController,
    required this.toolNotifier,
    this.zipFilePath,
    this.zipBytes,
  });

  @override
  State<_SwipeableImageDialog> createState() => _SwipeableImageDialogState();
}

class _SwipeableImageDialogState extends State<_SwipeableImageDialog> {
  late int _currentIndex;
  late List<CropItem> _sortedCrops; // Question number'a göre sıralanmış

  // Whiteboard state
  bool _showWhiteboard = false;
  bool _isSolutionExpanded = false;
  final GlobalKey<DrawableContentWidgetState> _whiteboardKey = GlobalKey();
  final ValueNotifier<ToolState> _whiteboardToolNotifier = ValueNotifier(
    const ToolState(
      pencil: true,
      eraser: false,
      highlighter: false,
      grab: false,
      mouse: false,
      shape: false,
      selection: false,
      magnifier: false,
      selectedShape: ShapeType.rectangle,
      color: Colors.black,
      width: 2.0,
    ),
  );

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
  }

  @override
  void dispose() {
    _whiteboardToolNotifier.dispose();
    super.dispose();
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isSelected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.blue
                  : Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildColorPickerForWhiteboard(Color currentColor) {
    return Tooltip(
      message: 'Renk Seç',
      child: InkWell(
        onTap: () {
          _showColorPickerDialog(currentColor, (color) {
            _whiteboardToolNotifier.value = _whiteboardToolNotifier.value
                .copyWith(color: color);
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: _buildColorPreview(currentColor),
      ),
    );
  }

  Widget _buildColorPreview(Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  void _showColorPickerDialog(
    Color currentColor,
    Function(Color) onColorSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renk Seç'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  Colors.red,
                  Colors.blue,
                  Colors.green,
                  Colors.yellow,
                  Colors.orange,
                  Colors.purple,
                  Colors.pink,
                  Colors.black,
                  Colors.white,
                  Colors.brown,
                ].map((color) {
                  return InkWell(
                    onTap: () {
                      onColorSelected(color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == currentColor
                              ? Colors.blue
                              : Colors.grey,
                          width: color == currentColor ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionToggleButton({bool rotate = false}) {
    final scheme = Theme.of(context).colorScheme;
    final maxSize = MediaQuery.of(context).size.width;
    return Container(
      width: !rotate ? maxSize : 48,
      height: rotate ? double.infinity : 48,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          left: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isSolutionExpanded = !_isSolutionExpanded;
            });
          },
          child: rotate
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Çözümü Göster',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: scheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Çözümü Göster',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
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
                          : "Soru",
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
                  // Left Side - Image
                  Expanded(
                    flex: 2,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                          child: InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.memory(
                              widget.imageList
                                  .firstWhere(
                                    (entry) =>
                                        entry.key ==
                                        _sortedCrops[_currentIndex].imageFile,
                                  )
                                  .value,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // Whiteboard Toggle Button (Top Right of Image)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _showWhiteboard = !_showWhiteboard;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surface.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _showWhiteboard
                                      ? Icons.space_dashboard
                                      : Icons.space_dashboard_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_sortedCrops.length > 1)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              width: MediaQuery.of(context).size.width * 0.45,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
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
                                            setState(() {
                                              _currentIndex--;
                                            });
                                          }
                                        : null,
                                  ),
                                  const SizedBox(width: 24),
                                  Text(
                                    'Soru numarasına göre sıralı',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios),
                                    onPressed:
                                        _currentIndex < _sortedCrops.length - 1
                                        ? () {
                                            setState(() {
                                              _currentIndex++;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Middle - Whiteboard (Conditional)
                  if (_showWhiteboard)
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            left: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            ),
                            right: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Stack(
                          children: [
                            DrawableContentWidget(
                              key: _whiteboardKey,
                              toolNotifier: _whiteboardToolNotifier,
                              isDrawingEnabled: true,
                              child: Container(color: Colors.white),
                            ),
                            // Toolbar
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ValueListenableBuilder<ToolState>(
                                    valueListenable: _whiteboardToolNotifier,
                                    builder: (context, toolState, child) {
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildToolButton(
                                            icon: Icons.edit,
                                            isSelected: toolState.pencil,
                                            tooltip: 'Kalem',
                                            onTap: () {
                                              _whiteboardToolNotifier.value =
                                                  toolState.copyWith(
                                                    pencil: true,
                                                    eraser: false,
                                                  );
                                            },
                                          ),
                                          const SizedBox(width: 4),
                                          _buildToolButton(
                                            icon: Icons.cleaning_services,
                                            isSelected: toolState.eraser,
                                            tooltip: 'Silgi',
                                            onTap: () {
                                              _whiteboardToolNotifier.value =
                                                  toolState.copyWith(
                                                    pencil: false,
                                                    eraser: true,
                                                  );
                                            },
                                          ),
                                          Container(
                                            width: 1,
                                            height: 24,
                                            color: Colors.white24,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                          ),
                                          _buildColorPickerForWhiteboard(
                                            toolState.color,
                                          ),
                                          Container(
                                            width: 1,
                                            height: 24,
                                            color: Colors.white24,
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                          ),
                                          _buildToolButton(
                                            icon: Icons.delete_forever,
                                            isSelected: false,
                                            tooltip: 'Temizle',
                                            onTap: () {
                                              _whiteboardKey.currentState
                                                  ?.clearDrawing();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Divider
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),

                  // Right Side - Solution Section (Toggle)
                  // Right Side - Solution Section (Toggle)
                  if (_isSolutionExpanded)
                    Expanded(
                      flex: 1,
                      child: Stack(
                        children: [
                          SolutionPanel(
                            crop: _sortedCrops[_currentIndex],
                            zipFilePath: widget.zipFilePath,
                            zipBytes: widget.zipBytes,
                          ),
                          // Close button for solution panel
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() {
                                  _isSolutionExpanded = false;
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildSolutionToggleButton(rotate: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
