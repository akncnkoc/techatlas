import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ScratchpadWidget extends StatefulWidget {
  final VoidCallback? onClose;

  const ScratchpadWidget({super.key, this.onClose});

  @override
  State<ScratchpadWidget> createState() => _ScratchpadWidgetState();
}

class _ScratchpadWidgetState extends State<ScratchpadWidget> {
  final List<DrawingPoint> _points = [];
  Color _currentColor = Colors.black;
  double _strokeWidth = 3.0;
  Offset _position = Offset(100, 100);
  double width = 500;
  double height = 600;
  final GlobalKey _canvasKey = GlobalKey();

  void _clearCanvas() {
    setState(() {
      _points.clear();
    });
  }

  void _expandCanvas(double maxWidth, double maxHeight) {
    setState(() {
      width = clampDouble(2000, 500, maxWidth - 20);
      height = clampDouble(2000, 600, maxHeight - 80 - 100);
      _position = Offset(20, 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: IgnorePointer(
            ignoring: false,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: scheme.surface,
              child: SizedBox(
                width: width,
                height: height,
                child: Column(
                  children: [
                    // Header (Draggable)
                    GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          _position = Offset(
                            (_position.dx + details.delta.dx).clamp(
                              0,
                              MediaQuery.of(context).size.width - 500,
                            ),
                            (_position.dy + details.delta.dy).clamp(
                              0,
                              MediaQuery.of(context).size.height - 600,
                            ),
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note,
                              color: scheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Not Defteri',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.expand, size: 20),
                              onPressed: () => _expandCanvas(
                                MediaQuery.of(context).size.width,
                                MediaQuery.of(context).size.height,
                              ),
                              tooltip: 'Genişlet',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: _clearCanvas,
                              tooltip: 'Temizle',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                if (widget.onClose != null) {
                                  widget.onClose!();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              tooltip: 'Kapat',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Color & Width Controls
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        border: Border(
                          bottom: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Renk:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...[
                            Colors.black,
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                          ].map((color) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _currentColor = color),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _currentColor == color
                                          ? scheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          const Text(
                            'Kalınlık:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _strokeWidth,
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: _strokeWidth.toInt().toString(),
                              onChanged: (value) =>
                                  setState(() => _strokeWidth = value),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Canvas (White area for drawing)
                    Expanded(
                      child: Container(
                        key: _canvasKey,
                        color: Colors.white,
                        margin: const EdgeInsets.all(8),
                        child: ClipRect(
                          child: GestureDetector(
                            onPanStart: (details) {
                              final RenderBox? renderBox =
                                  _canvasKey.currentContext?.findRenderObject()
                                      as RenderBox?;
                              if (renderBox != null) {
                                final localPosition = renderBox.globalToLocal(
                                  details.globalPosition,
                                );
                                final size = renderBox.size;

                                // Sadece beyaz alan içinde çizim yap
                                if (localPosition.dx >= 0 &&
                                    localPosition.dx <= size.width &&
                                    localPosition.dy >= 0 &&
                                    localPosition.dy <= size.height) {
                                  setState(() {
                                    _points.add(
                                      DrawingPoint(
                                        offset: localPosition,
                                        paint: Paint()
                                          ..color = _currentColor
                                          ..strokeWidth = _strokeWidth
                                          ..strokeCap = StrokeCap.round,
                                      ),
                                    );
                                  });
                                }
                              }
                            },
                            onPanUpdate: (details) {
                              final RenderBox? renderBox =
                                  _canvasKey.currentContext?.findRenderObject()
                                      as RenderBox?;
                              if (renderBox != null) {
                                final localPosition = renderBox.globalToLocal(
                                  details.globalPosition,
                                );
                                final size = renderBox.size;

                                // Sadece beyaz alan içinde çizim yap
                                if (localPosition.dx >= 0 &&
                                    localPosition.dx <= size.width &&
                                    localPosition.dy >= 0 &&
                                    localPosition.dy <= size.height) {
                                  setState(() {
                                    _points.add(
                                      DrawingPoint(
                                        offset: localPosition,
                                        paint: Paint()
                                          ..color = _currentColor
                                          ..strokeWidth = _strokeWidth
                                          ..strokeCap = StrokeCap.round,
                                      ),
                                    );
                                  });
                                }
                              }
                            },
                            onPanEnd: (details) {
                              setState(() {
                                _points.add(
                                  DrawingPoint(offset: null, paint: Paint()),
                                );
                              });
                            },
                            child: CustomPaint(
                              painter: _DrawingPainter(_points),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DrawingPoint {
  final Offset? offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;

  _DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].offset != null && points[i + 1].offset != null) {
        canvas.drawLine(
          points[i].offset!,
          points[i + 1].offset!,
          points[i].paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
