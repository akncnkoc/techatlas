import 'package:flutter/material.dart';

/// Izgara/Grid modu - Ekrana ızgara ekleme
class GridMode extends StatefulWidget {
  final VoidCallback? onClose;

  const GridMode({super.key, this.onClose});

  @override
  State<GridMode> createState() => _GridModeState();
}

class _GridModeState extends State<GridMode> {
  double _gridSize = 50.0;
  Color _gridColor = Colors.grey;
  double _gridOpacity = 0.5;
  double _strokeWidth = 1.0;
  GridType _gridType = GridType.square;
  bool _showDots = false;
  bool _showNumbers = false;

  // Izgara boyutları
  static const List<double> _gridSizes = [25.0, 50.0, 75.0, 100.0, 150.0, 200.0];

  // Renk seçenekleri
  static const List<Color> _colors = [
    Colors.grey,
    Colors.black,
    Colors.white,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.yellow,
    Colors.purple,
  ];

  // Kalınlık seçenekleri
  static const List<double> _strokeWidths = [0.5, 1.0, 2.0, 3.0];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Izgara overlay
        Positioned.fill(
          child: CustomPaint(
            painter: GridPainter(
              gridSize: _gridSize,
              gridColor: _gridColor.withValues(alpha: _gridOpacity),
              strokeWidth: _strokeWidth,
              gridType: _gridType,
              showDots: _showDots,
              showNumbers: _showNumbers,
            ),
            size: Size.infinite,
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
                  'Izgara',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),

                // Izgara tipi
                const Text('Tip', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GridTypeButton(
                      icon: Icons.grid_4x4,
                      label: 'Kare',
                      isSelected: _gridType == GridType.square,
                      onPressed: () {
                        setState(() {
                          _gridType = GridType.square;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _GridTypeButton(
                      icon: Icons.grid_on,
                      label: 'Nokta',
                      isSelected: _gridType == GridType.dot,
                      onPressed: () {
                        setState(() {
                          _gridType = GridType.dot;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Izgara boyutu
                const Text('Boyut', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _gridSizes.map((size) {
                    final isSelected = (size - _gridSize).abs() < 0.1;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _gridSize = size;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${size.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Renk seçimi
                const Text('Renk', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _colors.map((color) {
                    final isSelected = color == _gridColor;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _gridColor = color;
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

                // Şeffaflık
                const Text('Şeffaflık', style: TextStyle(fontSize: 10)),
                Slider(
                  value: _gridOpacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${(_gridOpacity * 100).toInt()}%',
                  onChanged: (value) {
                    setState(() {
                      _gridOpacity = value;
                    });
                  },
                ),

                const SizedBox(height: 4),

                // Çizgi kalınlığı
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
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Container(
                            width: width * 4,
                            height: width * 4,
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

                // Ekstra seçenekler
                const Text('Seçenekler', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _showNumbers,
                      onChanged: (value) {
                        setState(() {
                          _showNumbers = value ?? false;
                        });
                      },
                    ),
                    const Text('Koordinatlar', style: TextStyle(fontSize: 10)),
                  ],
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '⊞ Izgara Modu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Çizim ve tasarım için rehber',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                Text(
                  '• Izgara boyutu: ${_gridSize.toInt()}px',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum GridType {
  square,
  dot,
}

class GridPainter extends CustomPainter {
  final double gridSize;
  final Color gridColor;
  final double strokeWidth;
  final GridType gridType;
  final bool showDots;
  final bool showNumbers;

  GridPainter({
    required this.gridSize,
    required this.gridColor,
    required this.strokeWidth,
    required this.gridType,
    required this.showDots,
    required this.showNumbers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (gridType == GridType.square) {
      _paintSquareGrid(canvas, size);
    } else {
      _paintDotGrid(canvas, size);
    }

    if (showNumbers) {
      _paintGridNumbers(canvas, size);
    }
  }

  void _paintSquareGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Dikey çizgiler
    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Yatay çizgiler
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _paintDotGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.fill;

    final dotSize = strokeWidth * 2;

    for (double x = 0; x <= size.width; x += gridSize) {
      for (double y = 0; y <= size.height; y += gridSize) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  void _paintGridNumbers(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: gridColor,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    int col = 0;
    for (double x = 0; x <= size.width; x += gridSize) {
      final textSpan = TextSpan(text: '$col', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + 4, 4));
      col++;
    }

    int row = 0;
    for (double y = 0; y <= size.height; y += gridSize) {
      final textSpan = TextSpan(text: '$row', style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y + 4));
      row++;
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.gridSize != gridSize ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gridType != gridType ||
        oldDelegate.showNumbers != showNumbers;
  }
}

class _GridTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _GridTypeButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
