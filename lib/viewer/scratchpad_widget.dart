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
              borderRadius: BorderRadius.circular(12),
              color: scheme.surface.withValues(alpha: 0.95),
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.surfaceContainerHighest.withValues(
                                alpha: 0.8,
                              ),
                              scheme.surfaceContainerHighest.withValues(
                                alpha: 0.6,
                              ),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.secondary.withValues(alpha: 0.15),
                                    scheme.secondary.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.edit_note_rounded,
                                color: scheme.secondary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Not Defteri',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.expand_rounded, size: 18),
                              onPressed: () => _expandCanvas(
                                MediaQuery.of(context).size.width,
                                MediaQuery.of(context).size.height,
                              ),
                              tooltip: 'Genişlet',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              onPressed: _clearCanvas,
                              tooltip: 'Temizle',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                if (widget.onClose != null) {
                                  widget.onClose!();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              tooltip: 'Kapat',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Color & Width Controls
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.8),
                        border: Border(
                          bottom: BorderSide(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
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
