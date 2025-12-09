import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Cetvel/Düz çizgi çizme modu
class RulerMode extends StatefulWidget {
  final VoidCallback? onClose;

  const RulerMode({super.key, this.onClose});

  @override
  State<RulerMode> createState() => _RulerModeState();
}

class _RulerModeState extends State<RulerMode> {
  final List<RulerLine> _lines = [];
  Offset? _startPoint;
  Offset? _currentPoint;
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;
  bool _showAngle = true;
  bool _showLength = true;

  // Renk paleti
  static const List<Color> _colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.pink,
    Colors.black,
    Colors.white,
  ];

  // Kalınlık seçenekleri
  static const List<double> _strokeWidths = [1.0, 2.0, 3.0, 5.0, 8.0, 12.0];

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _startPoint = details.localPosition;
      _currentPoint = details.localPosition;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPoint = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_startPoint != null && _currentPoint != null) {
      // Çok kısa çizgileri ekleme
      final distance = math.sqrt(
        math.pow(_currentPoint!.dx - _startPoint!.dx, 2) +
            math.pow(_currentPoint!.dy - _startPoint!.dy, 2),
      );

      if (distance > 10) {
        setState(() {
          _lines.add(
            RulerLine(
              start: _startPoint!,
              end: _currentPoint!,
              color: _selectedColor,
              strokeWidth: _strokeWidth,
            ),
          );
        });
      }

      setState(() {
        _startPoint = null;
        _currentPoint = null;
      });
    }
  }

  double _calculateAngle(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx) * 180 / math.pi;
    return angle < 0 ? angle + 360 : angle;
  }

  double _calculateLength(Offset start, Offset end) {
    return math.sqrt(
      math.pow(end.dx - start.dx, 2) + math.pow(end.dy - start.dy, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Çizim alanı
        Positioned.fill(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: CustomPaint(
              painter: RulerPainter(
                lines: _lines,
                currentStart: _startPoint,
                currentEnd: _currentPoint,
                currentColor: _selectedColor,
                currentWidth: _strokeWidth,
                showAngle: _showAngle,
                showLength: _showLength,
              ),
              size: Size.infinite,
            ),
          ),
        ),

        // Kontrol paneli (sağ üst)
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cetvel / Düz Çizgi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),

                // Renk seçimi
                const Text('Renk', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _colors.map((color) {
                    final isSelected = color == _selectedColor;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Kalınlık seçimi
                const Text('Kalınlık', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _strokeWidths.map((width) {
                    final isSelected = (width - _strokeWidth).abs() < 0.1;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _strokeWidth = width;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Container(
                            width: width * 2,
                            height: width * 2,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Gösterim seçenekleri
                const Text('Göster', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _showAngle,
                      onChanged: (value) {
                        setState(() {
                          _showAngle = value ?? true;
                        });
                      },
                    ),
                    const Text('Açı', style: TextStyle(fontSize: 10)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _showLength,
                      onChanged: (value) {
                        setState(() {
                          _showLength = value ?? true;
                        });
                      },
                    ),
                    const Text('Uzunluk', style: TextStyle(fontSize: 10)),
                  ],
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Geri al butonu
                ElevatedButton.icon(
                  onPressed: _lines.isEmpty ? null : () {
                    setState(() {
                      _lines.removeLast();
                    });
                  },
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Geri Al'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                // Temizle butonu
                ElevatedButton.icon(
                  onPressed: _lines.isEmpty ? null : () {
                    setState(() {
                      _lines.clear();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Temizle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                // Kapat butonu
                ElevatedButton.icon(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Modu Kapat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bilgi mesajı (sol alt)
        Positioned(
          left: 20,
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '📏 Cetvel Modu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Sürükleyerek düz çizgiler çizin',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                Text(
                  '• Açı ve uzunluk bilgilerini görün',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),

        // Aktif çizgi bilgisi (üst orta)
        if (_startPoint != null && _currentPoint != null)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showAngle) ...[
                      const Icon(Icons.rotate_right, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_calculateAngle(_startPoint!, _currentPoint!).toStringAsFixed(1)}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if (_showLength) ...[
                      const Icon(Icons.straighten, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_calculateLength(_startPoint!, _currentPoint!).toStringAsFixed(0)} px',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class RulerLine {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  RulerLine({
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });
}

class RulerPainter extends CustomPainter {
  final List<RulerLine> lines;
  final Offset? currentStart;
  final Offset? currentEnd;
  final Color currentColor;
  final double currentWidth;
  final bool showAngle;
  final bool showLength;

  RulerPainter({
    required this.lines,
    this.currentStart,
    this.currentEnd,
    required this.currentColor,
    required this.currentWidth,
    required this.showAngle,
    required this.showLength,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Tamamlanmış çizgileri çiz
    for (final line in lines) {
      _drawLine(canvas, line.start, line.end, line.color, line.strokeWidth);
    }

    // Aktif çizgiyi çiz
    if (currentStart != null && currentEnd != null) {
      _drawLine(canvas, currentStart!, currentEnd!, currentColor, currentWidth);
    }
  }

  void _drawLine(Canvas canvas, Offset start, Offset end, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, paint);

    // Ok uçları (isteğe bağlı)
    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Başlangıç noktası
    canvas.drawCircle(start, width * 1.5, arrowPaint);

    // Bitiş noktası
    canvas.drawCircle(end, width * 1.5, arrowPaint);
  }

  @override
  bool shouldRepaint(RulerPainter oldDelegate) {
    return true;
  }
}
