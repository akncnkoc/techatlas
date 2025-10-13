import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'stroke.dart';
import 'drawing_painter.dart';
import 'tool_state.dart';
import 'drawing_history.dart';
import 'page_time_tracker.dart';
import 'dart:math' show cos, sin;

class PdfViewerWithDrawing extends StatefulWidget {
  final PdfController controller;
  const PdfViewerWithDrawing({super.key, required this.controller});

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
      grab: false,
      shape: false,
      selection: false,
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
  final ValueNotifier<String> _currentPageTimeNotifier = ValueNotifier<String>('0sn');

  int _currentPage = 1;
  final TransformationController transformationController =
      TransformationController();
  final double _minZoom = 0.5;
  final double _maxZoom = 4.0;
  bool _isDrawing = false;
  bool _isPanning = false;
  double _rotationAngle = 0.0;
  double _lastRotation = 0.0;
  Offset? _shapeStartPoint;

  // Swipe detection için
  Offset? _panStartPosition;
  Offset? _panLastPosition;
  DateTime? _panStartTime;
  static const double _swipeVelocityThreshold = 1200.0; // pixels per second (arttırıldı)
  static const double _swipeDistanceThreshold = 150.0; // minimum distance (arttırıldı)

  // Selection için (ekran koordinatlarında)
  final ValueNotifier<Rect?> selectedAreaNotifier = ValueNotifier<Rect?>(null);
  Offset? _selectionStart;
  Offset? _selectionStartScreen; // Ekran koordinatı

  // PDF rendering kalitesi için
  double _lastRenderedScale = 1.0;
  final ValueNotifier<double> _pdfScaleNotifier = ValueNotifier<double>(1.0);

  @override
  void initState() {
    super.initState();
    widget.controller.pageListenable.addListener(_onPageChanged);
    transformationController.addListener(_onTransformChanged);

    // Zaman takibi başlat
    _timeTracker = PageTimeTracker(onUpdate: _updateTimeDisplay);
    _timeTracker.onPageChanged(_currentPage);
    _timeTracker.startTimer();

    // Başlangıç durumunu kaydet
    _saveToHistory();
  }

  void _onPageChanged() {
    final page = widget.controller.pageListenable.value;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      _repaintNotifier.value++;
      // Sayfa değiştiğinde undo/redo durumunu güncelle
      _updateUndoRedoState();
      // Sayfa değiştiğinde zaman takibini güncelle
      _timeTracker.onPageChanged(page);
    }
  }

  void _onTransformChanged() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();

    // Zoom seviyesi %5'den fazla değiştiyse PDF'i yeniden render et
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

  Offset _transformPoint(Offset point) {
    // Transform matrisini tersine çevirerek zoom/pan dönüşümünü geri al
    final Matrix4 invertedMatrix = Matrix4.inverted(
      transformationController.value,
    );
    final Vector3 transformed = invertedMatrix.transform3(
      Vector3(point.dx, point.dy, 0),
    );
    return Offset(transformed.x, transformed.y);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastRotation = 0.0;
    final tool = toolNotifier.value;

    if (details.pointerCount == 1) {
      if (tool.grab || tool.mouse) {
        _isPanning = true;
        _panStartPosition = details.localFocalPoint;
        _panStartTime = DateTime.now();
      } else if (tool.shape) {
        _startShape(_transformPoint(details.localFocalPoint));
      } else if (tool.pencil || tool.eraser) {
        _startStroke(_transformPoint(details.localFocalPoint));
      }
      // Selection artık GestureDetector'dan değil Listener'dan yönetiliyor
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final tool = toolNotifier.value;

    if (details.pointerCount == 2 &&
        !tool.pencil &&
        !tool.eraser &&
        !tool.shape &&
        !tool.selection) {
      final rotationDelta = details.rotation - _lastRotation;
      _rotationAngle += rotationDelta;
      _lastRotation = details.rotation;
      setState(() {});
      return;
    }

    if (details.pointerCount == 1) {
      if ((tool.grab || tool.mouse) && _isPanning) {
        // Son pozisyonu kaydet
        _panLastPosition = details.localFocalPoint;

        final currentTransform = transformationController.value;
        final newTransform = Matrix4.copy(currentTransform)
          ..translateByVector3(
            Vector3(details.focalPointDelta.dx, details.focalPointDelta.dy, 0),
          );
        transformationController.value = newTransform;
      } else if (tool.shape) {
        _updateShape(_transformPoint(details.localFocalPoint));
      } else if (tool.pencil || tool.eraser) {
        _updateStroke(_transformPoint(details.localFocalPoint));
      }
      // Selection artık GestureDetector'dan değil Listener'dan yönetiliyor
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    final tool = toolNotifier.value;

    if ((tool.grab || tool.mouse) && _isPanning) {
      // Swipe detection
      if (_panStartPosition != null &&
          _panLastPosition != null &&
          _panStartTime != null) {
        final distance = _panLastPosition! - _panStartPosition!;
        final duration = DateTime.now().difference(_panStartTime!);
        final velocity = distance.dx.abs() / (duration.inMilliseconds / 1000.0);

        // Hızlı yatay hareket ve yeterli mesafe varsa sayfa değiştir
        if (velocity > _swipeVelocityThreshold &&
            distance.dx.abs() > _swipeDistanceThreshold &&
            distance.dx.abs() > distance.dy.abs() * 2) {
          // Transform ayarlarını animasyonlu sıfırla
          setState(() {
            transformationController.value = Matrix4.identity();
            _lastRenderedScale = 1.0;
            _pdfScaleNotifier.value = 1.0;
          });

          // Sayfa geçiş animasyonu - daha uzun ve akıcı
          if (distance.dx > 0) {
            // Sağa swipe - önceki sayfa
            widget.controller.previousPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          } else {
            // Sola swipe - sonraki sayfa
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
    } else if (tool.pencil || tool.eraser) {
      _endStroke();
    }
    // Selection artık GestureDetector'dan değil Listener'dan yönetiliyor

    _lastRotation = 0.0;
  }

  void _startShape(Offset position) {
    setState(() {
      _isDrawing = true;
      _shapeStartPoint = position;

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
        shapePoints: [position, position],
      );

      _strokes.add(_activeStroke!);
      _repaintNotifier.value++;
    });
  }

  void _updateShape(Offset position) {
    if (_activeStroke != null && _shapeStartPoint != null) {
      _activeStroke!.points[1] = position;
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
    // Şekil tamamlandığında geçmişe kaydet
    _saveToHistory();
  }

  void _startStroke(Offset position) {
    setState(() {
      _isDrawing = true;

      final tool = toolNotifier.value;

      if (tool.eraser) {
        _activeStroke = Stroke(color: tool.color, width: tool.width, erase: true);
        _activeStroke!.points.add(position);
        _eraseAt(position, tool.width);
        return;
      }

      _activeStroke = Stroke(color: tool.color, width: tool.width, erase: false);
      _activeStroke!.points.add(position);
      _strokes.add(_activeStroke!);

      _repaintNotifier.value++;
    });
  }

  void _updateStroke(Offset position) {
    if (!_isDrawing && _activeStroke == null) return;

    final tool = toolNotifier.value;

    if (tool.eraser) {
      _activeStroke?.points.add(position);
      _eraseAt(position, tool.width);
    } else {
      _activeStroke?.points.add(position);
    }

    _repaintNotifier.value++;
  }

  void _endStroke() {
    setState(() {
      _activeStroke = null;
      _isDrawing = false;
      _repaintNotifier.value++;
    });
    // Çizim tamamlandığında geçmişe kaydet
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
    // Temizleme işlemini geçmişe kaydet
    _saveToHistory();
  }

  /// Undo - Geri al
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

  /// Redo - İleri al
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

  /// Undo yapılabilir mi?
  bool get canUndo => _canUndoNotifier.value;

  /// Redo yapılabilir mi?
  bool get canRedo => _canRedoNotifier.value;

  /// Public getter for canUndoNotifier
  ValueNotifier<bool> get canUndoNotifier => _canUndoNotifier;

  /// Public getter for canRedoNotifier
  ValueNotifier<bool> get canRedoNotifier => _canRedoNotifier;

  double get zoomLevel => transformationController.value.getMaxScaleOnAxis();

  void zoomIn() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.2).clamp(_minZoom, _maxZoom);
    transformationController.value = Matrix4.identity()..scale(newScale);
  }

  void zoomOut() {
    final currentScale = transformationController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(_minZoom, _maxZoom);
    transformationController.value = Matrix4.identity()..scale(newScale);
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
      eraser: false,
      grab: false,
      shape: false,
      mouse: false,
      selection: false,
    );
  }

  void setEraser(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      eraser: value,
      pencil: false,
      grab: false,
      shape: false,
      mouse: false,
      selection: false,
    );
  }

  void setGrab(bool value) {
    // Grab artık mouse ile aynı işlevi görüyor
    toolNotifier.value = toolNotifier.value.copyWith(
      mouse: value,
      grab: false,
      pencil: false,
      eraser: false,
      shape: false,
      selection: false,
    );
  }

  void setMouse(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      mouse: value,
      pencil: false,
      eraser: false,
      grab: false,
      shape: false,
      selection: false,
    );
  }

  void setShape(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      shape: value,
      pencil: false,
      eraser: false,
      grab: false,
      mouse: false,
      selection: false,
    );
  }

  void setSelectedShape(ShapeType shapeType) {
    toolNotifier.value = toolNotifier.value.copyWith(
      selectedShape: shapeType,
      shape: true,
      pencil: false,
      eraser: false,
      grab: false,
      mouse: false,
      selection: false,
    );
  }

  void setColor(Color value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      color: value,
      pencil: !toolNotifier.value.shape,
      shape: toolNotifier.value.shape,
      eraser: false,
      grab: false,
      mouse: false,
      selection: false,
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
      eraser: false,
      grab: false,
      shape: false,
    );
    if (!value) {
      selectedAreaNotifier.value = null;
      _selectionStart = null;
    }
  }

  void clearSelection() {
    selectedAreaNotifier.value = null;
    _selectionStart = null;
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
      selectedAreaNotifier.value = Rect.fromPoints(_selectionStartScreen!, event.localPosition);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final tool = toolNotifier.value;
    if (tool.selection) {
      _selectionStartScreen = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = toolNotifier.value;

    return Listener(
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
                ..scale(newScale);
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
                  // Ctrl+Z: Undo
                  if (_history.canUndo(_currentPage)) {
                    undo();
                  }
                  break;
                case LogicalKeyboardKey.keyY:
                  // Ctrl+Y: Redo
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
              : tool.shape
              ? SystemMouseCursors.cell
              : tool.eraser
              ? SystemMouseCursors.click
              : tool.selection
              ? SystemMouseCursors.precise
              : SystemMouseCursors.basic,
          child: Stack(
            children: [
              InteractiveViewer(
                transformationController: transformationController,
                minScale: _minZoom,
                maxScale: _maxZoom,
                boundaryMargin: const EdgeInsets.all(20),
                panEnabled: tool.grab || tool.mouse,
                scaleEnabled: true,
                child: GestureDetector(
                  onScaleStart: _handleScaleStart,
                  onScaleUpdate: _handleScaleUpdate,
                  onScaleEnd: _handleScaleEnd,
                  child: Transform.rotate(
                    angle: _rotationAngle,
                    child: Stack(
                      children: [
                        ValueListenableBuilder<double>(
                          valueListenable: _pdfScaleNotifier,
                          builder: (context, scale, child) {
                            // Zoom seviyesine göre render kalitesini ayarla
                            // Daha yüksek kalite için çarpan ve limitleri artırdık
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
                      ],
                    ),
                  ),
                ),
              ),
              // Selection overlay - InteractiveViewer dışında, ekran koordinatlarında
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
            ],
          ),
        ),
      ),
    );
  }
}

// Selection painter - mavi dikdörtgen çizer
class _SelectionPainter extends CustomPainter {
  final Rect rect;

  _SelectionPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
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
