import 'package:flutter/material.dart';

/// Vurgulayıcı kalem modu - Yarı şeffaf renkli işaretleyici
class HighlighterMode extends StatefulWidget {
  final VoidCallback? onClose;

  const HighlighterMode({super.key, this.onClose});

  @override
  State<HighlighterMode> createState() => _HighlighterModeState();
}

class _HighlighterModeState extends State<HighlighterMode> {
  final List<HighlightStroke> _strokes = [];
  List<HighlightPoint> _currentPoints = [];
  Color _selectedColor = Colors.yellow.withValues(alpha: 0.5);
  double _strokeWidth = 20.0;

  // Vurgulayıcı renkleri (yarı şeffaf)
  static final List<Color> _colors = [
    Colors.yellow.withValues(alpha: 0.5),
    Colors.green.withValues(alpha: 0.5),
    Colors.blue.withValues(alpha: 0.5),
    Colors.pink.withValues(alpha: 0.5),
    Colors.orange.withValues(alpha: 0.5),
    Colors.purple.withValues(alpha: 0.5),
    Colors.cyan.withValues(alpha: 0.5),
    Colors.red.withValues(alpha: 0.5),
  ];

  // Kalem boyutları (geniş vurgulayıcılar)
  static const List<double> _strokeWidths = [10.0, 15.0, 20.0, 25.0, 30.0, 40.0];

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentPoints = [
        HighlightPoint(
          offset: details.localPosition,
          color: _selectedColor,
          width: _strokeWidth,
        ),
      ];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPoints.add(
        HighlightPoint(
          offset: details.localPosition,
          color: _selectedColor,
          width: _strokeWidth,
        ),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (_currentPoints.isNotEmpty) {
        _strokes.add(
          HighlightStroke(
            points: List.from(_currentPoints),
            color: _selectedColor,
            width: _strokeWidth,
          ),
        );
        _currentPoints = [];
      }
    });
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentPoints = [];
    });
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
              painter: HighlighterPainter(
                strokes: _strokes,
                currentPoints: _currentPoints,
                currentColor: _selectedColor,
                currentWidth: _strokeWidth,
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
                  'Vurgulayıcı',
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
                  spacing: 8,
                  runSpacing: 8,
                  children: _colors.map((color) {
                    final isSelected = color.value == _selectedColor.value;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade400,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Genişlik seçimi
                const Text('Genişlik', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Column(
                  children: _strokeWidths.map((width) {
                    final isSelected = (width - _strokeWidth).abs() < 0.1;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _strokeWidth = width;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 100,
                            height: width,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              borderRadius: BorderRadius.circular(width / 2),
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

                // Geri al butonu
                ElevatedButton.icon(
                  onPressed: _strokes.isEmpty ? null : _undo,
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
                  onPressed: _strokes.isEmpty ? null : _clear,
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
                  '💡 Vurgulayıcı Modu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Metinleri yarı şeffaf renklerle vurgulayın',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                Text(
                  '• Geniş fırça uçları ile kolay işaretleme',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class HighlightPoint {
  final Offset offset;
  final Color color;
  final double width;

  HighlightPoint({
    required this.offset,
    required this.color,
    required this.width,
  });
}

class HighlightStroke {
  final List<HighlightPoint> points;
  final Color color;
  final double width;

  HighlightStroke({
    required this.points,
    required this.color,
    required this.width,
  });
}

class HighlighterPainter extends CustomPainter {
  final List<HighlightStroke> strokes;
  final List<HighlightPoint> currentPoints;
  final Color currentColor;
  final double currentWidth;

  HighlighterPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Tamamlanmış stroke'ları çiz
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.width);
    }

    // Aktif stroke'u çiz
    if (currentPoints.isNotEmpty) {
      _drawStroke(canvas, currentPoints, currentColor, currentWidth);
    }
  }

  void _drawStroke(Canvas canvas, List<HighlightPoint> points, Color color, double width) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..color = color;

    final path = Path();
    path.moveTo(points.first.offset.dx, points.first.offset.dy);

    for (int i = 1; i < points.length; i++) {
      final p1 = points[i - 1].offset;
      final p2 = points[i].offset;

      // Smooth curve için quadratic bezier
      final midPoint = Offset(
        (p1.dx + p2.dx) / 2,
        (p1.dy + p2.dy) / 2,
      );

      path.quadraticBezierTo(p1.dx, p1.dy, midPoint.dx, midPoint.dy);
    }

    // Son noktaya
    if (points.length > 1) {
      final lastPoint = points.last.offset;
      path.lineTo(lastPoint.dx, lastPoint.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HighlighterPainter oldDelegate) {
    return true;
  }
}
