import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Geometrik şekiller çizme modu
class ShapesMode extends StatefulWidget {
  final VoidCallback? onClose;

  const ShapesMode({super.key, this.onClose});

  @override
  State<ShapesMode> createState() => _ShapesModeState();
}

class _ShapesModeState extends State<ShapesMode> {
  final List<DrawnShape> _shapes = [];
  Offset? _startPoint;
  Offset? _currentPoint;
  ShapeType _selectedShape = ShapeType.rectangle;
  Color _selectedColor = Colors.blue;
  double _strokeWidth = 3.0;
  bool _fillShape = false;

  // Renk paleti
  static const List<Color> _colors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.cyan,
    Colors.brown,
    Colors.teal,
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
      setState(() {
        _shapes.add(
          DrawnShape(
            type: _selectedShape,
            start: _startPoint!,
            end: _currentPoint!,
            color: _selectedColor,
            strokeWidth: _strokeWidth,
            filled: _fillShape,
          ),
        );
        _startPoint = null;
        _currentPoint = null;
      });
    }
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
              painter: ShapesPainter(
                shapes: _shapes,
                currentShape: _startPoint != null && _currentPoint != null
                    ? DrawnShape(
                        type: _selectedShape,
                        start: _startPoint!,
                        end: _currentPoint!,
                        color: _selectedColor,
                        strokeWidth: _strokeWidth,
                        filled: _fillShape,
                      )
                    : null,
              ),
              size: Size.infinite,
            ),
          ),
        ),

        // Kontrol paneli (sağ üst)
        Positioned(
          right: 10,
          top: 10,
          bottom: 10,
          child: Container(
            width: 200,
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Şekil Araçları',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Şekil seçimi - Grid formatında
                  const Text('Şekil Seç (16 Çeşit)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 1,
                    children: ShapeType.values.map((type) {
                      final isSelected = type == _selectedShape;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedShape = type;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                type.icon,
                                color: isSelected ? Colors.white : Colors.black,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
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
                    spacing: 6,
                    runSpacing: 6,
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

                  // Kalınlık
                  const Text('Kalınlık', style: TextStyle(fontSize: 10)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _strokeWidths.map((width) {
                      final isSelected = width == _strokeWidth;
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

                  // Dolu/Boş seçimi
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _fillShape,
                        onChanged: (value) {
                          setState(() {
                            _fillShape = value ?? false;
                          });
                        },
                      ),
                      const Text('Dolu Çiz', style: TextStyle(fontSize: 10)),
                    ],
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),

                  // Geri al butonu
                  ElevatedButton.icon(
                    onPressed: _shapes.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _shapes.removeLast();
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
                    onPressed: _shapes.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _shapes.clear();
                            });
                          },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Hepsini Sil'),
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
                  '🔷 Geometrik Şekiller (16 Çeşit)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Dikdörtgen, Daire, Elips, Çizgi',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  '• Ok, Çift Ok, Üçgenler',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  '• Beşgen, Altıgen, Yıldız',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  '• Kalp, Baklava, Yamuk, Paralelkenar, Bulut',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Şekil türleri
enum ShapeType {
  rectangle,
  circle,
  ellipse,
  line,
  arrow,
  doubleArrow,
  triangle,
  rightTriangle,
  pentagon,
  hexagon,
  star,
  heart,
  diamond,
  trapezoid,
  parallelogram,
  cloud,
}

extension ShapeTypeExtension on ShapeType {
  String get name {
    switch (this) {
      case ShapeType.rectangle:
        return 'Dikdörtgen';
      case ShapeType.circle:
        return 'Daire';
      case ShapeType.ellipse:
        return 'Elips';
      case ShapeType.line:
        return 'Çizgi';
      case ShapeType.arrow:
        return 'Ok';
      case ShapeType.doubleArrow:
        return 'Çift Ok';
      case ShapeType.triangle:
        return 'Üçgen';
      case ShapeType.rightTriangle:
        return 'Dik Üçgen';
      case ShapeType.pentagon:
        return 'Beşgen';
      case ShapeType.hexagon:
        return 'Altıgen';
      case ShapeType.star:
        return 'Yıldız';
      case ShapeType.heart:
        return 'Kalp';
      case ShapeType.diamond:
        return 'Baklava';
      case ShapeType.trapezoid:
        return 'Yamuk';
      case ShapeType.parallelogram:
        return 'Paralelkenar';
      case ShapeType.cloud:
        return 'Bulut';
    }
  }

  IconData get icon {
    switch (this) {
      case ShapeType.rectangle:
        return Icons.crop_square;
      case ShapeType.circle:
        return Icons.circle_outlined;
      case ShapeType.ellipse:
        return Icons.panorama_fish_eye;
      case ShapeType.line:
        return Icons.show_chart;
      case ShapeType.arrow:
        return Icons.arrow_forward;
      case ShapeType.doubleArrow:
        return Icons.swap_horiz;
      case ShapeType.triangle:
        return Icons.details;
      case ShapeType.rightTriangle:
        return Icons.signal_cellular_alt;
      case ShapeType.pentagon:
        return Icons.pentagon_outlined;
      case ShapeType.hexagon:
        return Icons.hexagon_outlined;
      case ShapeType.star:
        return Icons.star_border;
      case ShapeType.heart:
        return Icons.favorite_border;
      case ShapeType.diamond:
        return Icons.diamond_outlined;
      case ShapeType.trapezoid:
        return Icons.crop_landscape;
      case ShapeType.parallelogram:
        return Icons.crop_free;
      case ShapeType.cloud:
        return Icons.cloud_outlined;
    }
  }
}

/// Çizilmiş şekil
class DrawnShape {
  final ShapeType type;
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;
  final bool filled;

  DrawnShape({
    required this.type,
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
    required this.filled,
  });
}

/// Şekilleri çizen painter
class ShapesPainter extends CustomPainter {
  final List<DrawnShape> shapes;
  final DrawnShape? currentShape;

  ShapesPainter({
    required this.shapes,
    this.currentShape,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Tamamlanmış şekilleri çiz
    for (final shape in shapes) {
      _drawShape(canvas, shape);
    }

    // Aktif şekli çiz
    if (currentShape != null) {
      _drawShape(canvas, currentShape!);
    }
  }

  void _drawShape(Canvas canvas, DrawnShape shape) {
    final paint = Paint()
      ..color = shape.color
      ..strokeWidth = shape.strokeWidth
      ..style = shape.filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    switch (shape.type) {
      case ShapeType.rectangle:
        final rect = Rect.fromPoints(shape.start, shape.end);
        canvas.drawRect(rect, paint);
        break;

      case ShapeType.circle:
        final center = Offset(
          (shape.start.dx + shape.end.dx) / 2,
          (shape.start.dy + shape.end.dy) / 2,
        );
        final radius = math.sqrt(
          math.pow(shape.end.dx - shape.start.dx, 2) +
              math.pow(shape.end.dy - shape.start.dy, 2),
        ) / 2;
        canvas.drawCircle(center, radius, paint);
        break;

      case ShapeType.line:
        canvas.drawLine(shape.start, shape.end, paint);
        break;

      case ShapeType.arrow:
        // Ok çizgisi
        canvas.drawLine(shape.start, shape.end, paint);

        // Ok başı
        final angle = math.atan2(
          shape.end.dy - shape.start.dy,
          shape.end.dx - shape.start.dx,
        );
        final arrowLength = 20.0;
        final arrowAngle = 30 * math.pi / 180;

        final arrowPoint1 = Offset(
          shape.end.dx - arrowLength * math.cos(angle - arrowAngle),
          shape.end.dy - arrowLength * math.sin(angle - arrowAngle),
        );
        final arrowPoint2 = Offset(
          shape.end.dx - arrowLength * math.cos(angle + arrowAngle),
          shape.end.dy - arrowLength * math.sin(angle + arrowAngle),
        );

        canvas.drawLine(shape.end, arrowPoint1, paint);
        canvas.drawLine(shape.end, arrowPoint2, paint);
        break;

      case ShapeType.triangle:
        final path = Path()
          ..moveTo(
            (shape.start.dx + shape.end.dx) / 2,
            shape.start.dy,
          )
          ..lineTo(shape.start.dx, shape.end.dy)
          ..lineTo(shape.end.dx, shape.end.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.ellipse:
        final rect = Rect.fromPoints(shape.start, shape.end);
        canvas.drawOval(rect, paint);
        break;

      case ShapeType.doubleArrow:
        // Çift yönlü ok
        canvas.drawLine(shape.start, shape.end, paint);

        // İlk ok başı (başlangıç)
        final angle1 = math.atan2(
          shape.end.dy - shape.start.dy,
          shape.end.dx - shape.start.dx,
        );
        final arrowLength = 20.0;
        final arrowAngle = 30 * math.pi / 180;

        final startArrow1 = Offset(
          shape.start.dx + arrowLength * math.cos(angle1 - arrowAngle),
          shape.start.dy + arrowLength * math.sin(angle1 - arrowAngle),
        );
        final startArrow2 = Offset(
          shape.start.dx + arrowLength * math.cos(angle1 + arrowAngle),
          shape.start.dy + arrowLength * math.sin(angle1 + arrowAngle),
        );

        canvas.drawLine(shape.start, startArrow1, paint);
        canvas.drawLine(shape.start, startArrow2, paint);

        // İkinci ok başı (bitiş)
        final endArrow1 = Offset(
          shape.end.dx - arrowLength * math.cos(angle1 - arrowAngle),
          shape.end.dy - arrowLength * math.sin(angle1 - arrowAngle),
        );
        final endArrow2 = Offset(
          shape.end.dx - arrowLength * math.cos(angle1 + arrowAngle),
          shape.end.dy - arrowLength * math.sin(angle1 + arrowAngle),
        );

        canvas.drawLine(shape.end, endArrow1, paint);
        canvas.drawLine(shape.end, endArrow2, paint);
        break;

      case ShapeType.rightTriangle:
        // Dik üçgen
        final path = Path()
          ..moveTo(shape.start.dx, shape.start.dy)
          ..lineTo(shape.end.dx, shape.start.dy)
          ..lineTo(shape.end.dx, shape.end.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.pentagon:
        // Beşgen
        final centerX = (shape.start.dx + shape.end.dx) / 2;
        final centerY = (shape.start.dy + shape.end.dy) / 2;
        final radius = math.sqrt(
          math.pow(shape.end.dx - shape.start.dx, 2) +
              math.pow(shape.end.dy - shape.start.dy, 2),
        ) / 2;

        final path = Path();
        for (int i = 0; i < 5; i++) {
          final angle = (i * 2 * math.pi / 5) - math.pi / 2;
          final x = centerX + radius * math.cos(angle);
          final y = centerY + radius * math.sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.hexagon:
        // Altıgen
        final centerX = (shape.start.dx + shape.end.dx) / 2;
        final centerY = (shape.start.dy + shape.end.dy) / 2;
        final radius = math.sqrt(
          math.pow(shape.end.dx - shape.start.dx, 2) +
              math.pow(shape.end.dy - shape.start.dy, 2),
        ) / 2;

        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (i * 2 * math.pi / 6) - math.pi / 2;
          final x = centerX + radius * math.cos(angle);
          final y = centerY + radius * math.sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.star:
        // Yıldız
        final centerX = (shape.start.dx + shape.end.dx) / 2;
        final centerY = (shape.start.dy + shape.end.dy) / 2;
        final outerRadius = math.sqrt(
          math.pow(shape.end.dx - shape.start.dx, 2) +
              math.pow(shape.end.dy - shape.start.dy, 2),
        ) / 2;
        final innerRadius = outerRadius / 2.5;

        final path = Path();
        for (int i = 0; i < 10; i++) {
          final radius = i.isEven ? outerRadius : innerRadius;
          final angle = (i * math.pi / 5) - math.pi / 2;
          final x = centerX + radius * math.cos(angle);
          final y = centerY + radius * math.sin(angle);

          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.heart:
        // Kalp şekli
        final centerX = (shape.start.dx + shape.end.dx) / 2;
        final centerY = (shape.start.dy + shape.end.dy) / 2;
        final width = (shape.end.dx - shape.start.dx).abs();
        final height = (shape.end.dy - shape.start.dy).abs();

        final path = Path();
        path.moveTo(centerX, centerY + height * 0.3);

        // Sol üst kalp lobu
        path.cubicTo(
          centerX - width * 0.5,
          centerY - height * 0.1,
          centerX - width * 0.5,
          centerY - height * 0.4,
          centerX,
          centerY - height * 0.1,
        );

        // Sağ üst kalp lobu
        path.cubicTo(
          centerX + width * 0.5,
          centerY - height * 0.4,
          centerX + width * 0.5,
          centerY - height * 0.1,
          centerX,
          centerY + height * 0.3,
        );

        path.close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.diamond:
        // Baklava dilimi
        final centerX = (shape.start.dx + shape.end.dx) / 2;
        final centerY = (shape.start.dy + shape.end.dy) / 2;
        final width = (shape.end.dx - shape.start.dx).abs() / 2;
        final height = (shape.end.dy - shape.start.dy).abs() / 2;

        final path = Path()
          ..moveTo(centerX, centerY - height) // Üst
          ..lineTo(centerX + width, centerY) // Sağ
          ..lineTo(centerX, centerY + height) // Alt
          ..lineTo(centerX - width, centerY) // Sol
          ..close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.trapezoid:
        // Yamuk
        final topWidth = (shape.end.dx - shape.start.dx) * 0.6;
        final centerX = (shape.start.dx + shape.end.dx) / 2;

        final path = Path()
          ..moveTo(centerX - topWidth / 2, shape.start.dy) // Üst sol
          ..lineTo(centerX + topWidth / 2, shape.start.dy) // Üst sağ
          ..lineTo(shape.end.dx, shape.end.dy) // Alt sağ
          ..lineTo(shape.start.dx, shape.end.dy) // Alt sol
          ..close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.parallelogram:
        // Paralelkenar
        final width = shape.end.dx - shape.start.dx;
        final offset = width * 0.2;

        final path = Path()
          ..moveTo(shape.start.dx + offset, shape.start.dy)
          ..lineTo(shape.end.dx, shape.start.dy)
          ..lineTo(shape.end.dx - offset, shape.end.dy)
          ..lineTo(shape.start.dx, shape.end.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case ShapeType.cloud:
        // Bulut şekli
        final centerX = (shape.start.dx + shape.end.dx) / 2;
        final centerY = (shape.start.dy + shape.end.dy) / 2;
        final width = (shape.end.dx - shape.start.dx).abs();
        final height = (shape.end.dy - shape.start.dy).abs();

        final path = Path();

        // Ana bulut gövdesi (birden fazla daire ile)
        final mainRadius = height * 0.3;

        // Sol daire
        path.addOval(Rect.fromCircle(
          center: Offset(centerX - width * 0.25, centerY),
          radius: mainRadius * 0.8,
        ));

        // Orta daire (en büyük)
        path.addOval(Rect.fromCircle(
          center: Offset(centerX, centerY - height * 0.1),
          radius: mainRadius,
        ));

        // Sağ daire
        path.addOval(Rect.fromCircle(
          center: Offset(centerX + width * 0.25, centerY),
          radius: mainRadius * 0.8,
        ));

        // Alt düzleştirme
        path.addRect(Rect.fromLTRB(
          centerX - width * 0.4,
          centerY,
          centerX + width * 0.4,
          centerY + height * 0.2,
        ));

        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(ShapesPainter oldDelegate) {
    return true;
  }
}
