import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'stroke.dart';
import 'drawing_painter.dart';
import 'tool_state.dart';

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
      eraser: false,
      pencil: true,
      grab: false,
      shape: false,
      selectedShape: ShapeType.rectangle,
      color: Colors.red,
      width: 3.0,
    ),
  );

  int _currentPage = 1;
  final TransformationController _transformationController =
      TransformationController();
  final double _minZoom = 0.5;
  final double _maxZoom = 4.0;
  bool _isDrawing = false;
  bool _isPanning = false;
  double _rotationAngle = 0.0;
  double _lastRotation = 0.0;
  Offset? _shapeStartPoint;

  @override
  void initState() {
    super.initState();
    widget.controller.pageListenable.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = widget.controller.pageListenable.value;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      _repaintNotifier.value++;
    }
  }

  @override
  void dispose() {
    widget.controller.pageListenable.removeListener(_onPageChanged);
    _transformationController.dispose();
    super.dispose();
  }

  List<Stroke> get _strokes => _pageStrokes[_currentPage] ??= [];

  void _handleScaleStart(ScaleStartDetails details) {
    _lastRotation = 0.0;
    final tool = toolNotifier.value;

    // Handle single-pointer gestures
    if (details.pointerCount == 1) {
      if (tool.grab) {
        _isPanning = true;
      } else if (tool.shape) {
        _startShape(details.localFocalPoint);
      } else if (tool.pencil || tool.eraser) {
        _startStroke(details.localFocalPoint);
      }
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final tool = toolNotifier.value;

    // Handle two-finger rotation
    if (details.pointerCount == 2 &&
        !tool.pencil &&
        !tool.eraser &&
        !tool.shape) {
      final rotationDelta = details.rotation - _lastRotation;
      _rotationAngle += rotationDelta;
      _lastRotation = details.rotation;
      setState(() {});
      return;
    }

    // Handle single-pointer gestures
    if (details.pointerCount == 1) {
      if (tool.grab && _isPanning) {
        // Manual panning for grab tool
        final currentTransform = _transformationController.value;
        final newTransform = Matrix4.copy(currentTransform)
          ..translateByVector3(
            Vector3(details.focalPointDelta.dx, details.focalPointDelta.dy, 0),
          );
        _transformationController.value = newTransform;
      } else if (tool.shape) {
        _updateShape(details.localFocalPoint);
      } else if (tool.pencil || tool.eraser) {
        _updateStroke(details.localFocalPoint);
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    final tool = toolNotifier.value;

    if (tool.grab) {
      _isPanning = false;
    } else if (tool.shape) {
      _endShape();
    } else if (tool.pencil || tool.eraser) {
      _endStroke();
    }

    _lastRotation = 0.0;
  }

  void _startShape(Offset position) {
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
  }

  void _updateShape(Offset position) {
    if (_activeStroke != null && _shapeStartPoint != null) {
      _activeStroke!.points[1] = position;
      _repaintNotifier.value++;
    }
  }

  void _endShape() {
    _activeStroke = null;
    _shapeStartPoint = null;
    _isDrawing = false;
    _repaintNotifier.value++;
  }

  void _startStroke(Offset position) {
    _isDrawing = true;

    final tool = toolNotifier.value;

    if (tool.eraser) {
      _eraseAt(position, tool.width);
      return;
    }

    _activeStroke = Stroke(color: tool.color, width: tool.width, erase: false);
    _activeStroke!.points.add(position);
    _strokes.add(_activeStroke!);

    _repaintNotifier.value++;
  }

  void _updateStroke(Offset position) {
    if (!_isDrawing && _activeStroke == null) return;

    final tool = toolNotifier.value;

    if (tool.eraser) {
      _eraseAt(position, tool.width);
    } else {
      _activeStroke?.points.add(position);
    }

    _repaintNotifier.value++;
  }

  void _endStroke() {
    _activeStroke = null;
    _isDrawing = false;
    _repaintNotifier.value++;
  }

  void _eraseAt(Offset position, double radius) {
    _strokes.removeWhere((stroke) {
      return stroke.points.any(
        (point) => (point - position).distance < radius * 1.5,
      );
    });
  }

  void clearCurrentPage() {
    _strokes.clear();
    setState(() {
      _repaintNotifier.value++;
    });
  }

  void _zoomToPoint(double newScale, Offset focalPoint) {
    final currentTransform = _transformationController.value;
    final currentScale = currentTransform.getMaxScaleOnAxis();

    final scaleChange = newScale / currentScale;

    final currentTranslation = Offset(
      currentTransform.getTranslation().x,
      currentTransform.getTranslation().y,
    );

    final newTranslation = Offset(
      currentTranslation.dx - (focalPoint.dx * (scaleChange - 1)),
      currentTranslation.dy - (focalPoint.dy * (scaleChange - 1)),
    );

    final newTransform = Matrix4.identity()
      ..translateByVector3(Vector3(newTranslation.dx, newTranslation.dy, 0))
      ..scaleByDouble(newScale, newScale, 1, 1);

    _transformationController.value = newTransform;
  }

  void zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale < _maxZoom) {
      final newScale = (currentScale * 1.2).clamp(_minZoom, _maxZoom);

      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final viewportCenter = Offset(
          renderBox.size.width / 2,
          renderBox.size.height / 2,
        );

        _zoomToPoint(newScale, viewportCenter);
      }
    }
  }

  void zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > _minZoom) {
      final newScale = (currentScale / 1.2).clamp(_minZoom, _maxZoom);

      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final viewportCenter = Offset(
          renderBox.size.width / 2,
          renderBox.size.height / 2,
        );

        _zoomToPoint(newScale, viewportCenter);
      }
    }
  }

  void resetZoom() {
    _transformationController.value = Matrix4.identity();
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

  double get zoomLevel => _transformationController.value.getMaxScaleOnAxis();

  void setPencil(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      pencil: value,
      eraser: false,
      grab: false,
      shape: false,
    );
  }

  void setEraser(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      eraser: value,
      pencil: false,
      grab: false,
      shape: false,
    );
  }

  void setGrab(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      grab: value,
      pencil: false,
      eraser: false,
      shape: false,
    );
  }

  void setShape(bool value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      shape: value,
      pencil: false,
      eraser: false,
      grab: false,
    );
  }

  void setSelectedShape(ShapeType shapeType) {
    toolNotifier.value = toolNotifier.value.copyWith(
      selectedShape: shapeType,
      shape: true,
      pencil: false,
      eraser: false,
      grab: false,
    );
  }

  void setColor(Color value) {
    toolNotifier.value = toolNotifier.value.copyWith(
      color: value,
      pencil: !toolNotifier.value.shape,
      shape: toolNotifier.value.shape,
      eraser: false,
      grab: false,
    );
  }

  void setWidth(double value) {
    toolNotifier.value = toolNotifier.value.copyWith(width: value);
  }

  @override
  Widget build(BuildContext context) {
    final tool = toolNotifier.value;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

              if (isCtrlPressed) {
                final delta = pointerSignal.scrollDelta.dy;
                final currentScale = _transformationController.value
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
                  final RenderBox? renderBox =
                      context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final localPosition = renderBox.globalToLocal(
                      pointerSignal.position,
                    );
                    _zoomToPoint(newScale, localPosition);
                  }
                }
              }
            }
          },
          child: KeyboardListener(
            focusNode: FocusNode()..requestFocus(),
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                final isCtrlPressed =
                    HardwareKeyboard.instance.isControlPressed;

                if (isCtrlPressed) {
                  switch (event.logicalKey) {
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
              cursor: tool.grab
                  ? SystemMouseCursors.grab
                  : tool.pencil
                  ? SystemMouseCursors.precise
                  : tool.shape
                  ? SystemMouseCursors.cell
                  : tool.eraser
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: _minZoom,
                maxScale: _maxZoom,
                boundaryMargin: const EdgeInsets.all(20),
                panEnabled: tool.grab,
                scaleEnabled: true,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: GestureDetector(
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onScaleEnd: _handleScaleEnd,
                    child: Transform.rotate(
                      angle: _rotationAngle,
                      child: Stack(
                        children: [
                          PdfView(controller: widget.controller),
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
              ),
            ),
          ),
        );
      },
    );
  }
}
