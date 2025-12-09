import 'package:flutter/material.dart';

/// Spot ışık modu - Ekranın bir kısmını vurgular, geri kalanını karartır
class SpotlightMode extends StatefulWidget {
  final VoidCallback? onClose;

  const SpotlightMode({super.key, this.onClose});

  @override
  State<SpotlightMode> createState() => _SpotlightModeState();
}

class _SpotlightModeState extends State<SpotlightMode> {
  Offset _spotPosition = const Offset(400, 300);
  double _spotRadius = 150.0;
  bool _isDragging = false;

  // Spotlight şekli
  SpotlightShape _shape = SpotlightShape.circle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _spotPosition = details.localPosition;
          _isDragging = true;
        });
      },
      onPanEnd: (_) {
        setState(() {
          _isDragging = false;
        });
      },
      child: Stack(
        children: [
          // Karanlık overlay + spotlight
          CustomPaint(
            painter: SpotlightPainter(
              spotPosition: _spotPosition,
              spotRadius: _spotRadius,
              shape: _shape,
            ),
            size: Size.infinite,
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
                children: [
                  const Text(
                    'Spot Işık',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Boyut kontrolü
                  const Text('Boyut', style: TextStyle(fontSize: 10)),
                  SizedBox(
                    width: 150,
                    child: Slider(
                      value: _spotRadius,
                      min: 50,
                      max: 500,
                      onChanged: (value) {
                        setState(() {
                          _spotRadius = value;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Şekil seçimi
                  const Text('Şekil', style: TextStyle(fontSize: 10)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShapeButton(
                        icon: Icons.circle_outlined,
                        isSelected: _shape == SpotlightShape.circle,
                        onPressed: () {
                          setState(() {
                            _shape = SpotlightShape.circle;
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      _ShapeButton(
                        icon: Icons.crop_square_rounded,
                        isSelected: _shape == SpotlightShape.rectangle,
                        onPressed: () {
                          setState(() {
                            _shape = SpotlightShape.rectangle;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),

                  // Kapat butonu
                  ElevatedButton.icon(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Kapat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bilgi metni (sol alt)
          Positioned(
            left: 20,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 Spot ışığı hareket ettirmek için fareyi sürükleyin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum SpotlightShape {
  circle,
  rectangle,
}

/// Spotlight painter
class SpotlightPainter extends CustomPainter {
  final Offset spotPosition;
  final double spotRadius;
  final SpotlightShape shape;

  SpotlightPainter({
    required this.spotPosition,
    required this.spotRadius,
    required this.shape,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Karanlık overlay
    final darkPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Tüm ekranı karart
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      darkPaint,
    );

    // Spotlight alanını temizle (şeffaf yap)
    final clearPaint = Paint()
      ..blendMode = BlendMode.clear;

    if (shape == SpotlightShape.circle) {
      // Dairesel spotlight
      canvas.drawCircle(spotPosition, spotRadius, clearPaint);

      // Spotlight kenar çizgisi
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(spotPosition, spotRadius, borderPaint);
    } else {
      // Dikdörtgen spotlight
      final rect = Rect.fromCenter(
        center: spotPosition,
        width: spotRadius * 2,
        height: spotRadius * 1.5,
      );
      canvas.drawRect(rect, clearPaint);

      // Spotlight kenar çizgisi
      final borderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.spotPosition != spotPosition ||
        oldDelegate.spotRadius != spotRadius ||
        oldDelegate.shape != shape;
  }
}

class _ShapeButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _ShapeButton({
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black,
      ),
    );
  }
}
