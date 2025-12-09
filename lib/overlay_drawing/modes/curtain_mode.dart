import 'package:flutter/material.dart';

/// Perde modu - Ekranı aşamalı olarak açar/kapatır
class CurtainMode extends StatefulWidget {
  final VoidCallback? onClose;

  const CurtainMode({super.key, this.onClose});

  @override
  State<CurtainMode> createState() => _CurtainModeState();
}

class _CurtainModeState extends State<CurtainMode> {
  double _revealPercentage = 0.0; // 0 = tamamen kapalı, 1 = tamamen açık
  CurtainDirection _direction = CurtainDirection.fromTop;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Perde overlay
        CustomPaint(
          painter: CurtainPainter(
            revealPercentage: _revealPercentage,
            direction: _direction,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perde',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),

                // Açma/Kapama kontrolü
                const Text('Açma Oranı', style: TextStyle(fontSize: 10)),
                SizedBox(
                  width: 150,
                  child: Slider(
                    value: _revealPercentage,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      setState(() {
                        _revealPercentage = value;
                      });
                    },
                  ),
                ),
                Text(
                  '${(_revealPercentage * 100).toInt()}%',
                  style: const TextStyle(fontSize: 10),
                ),

                const SizedBox(height: 6),

                // Yön seçimi
                const Text('Yön', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _DirectionButton(
                      label: 'Yukarıdan',
                      icon: Icons.arrow_downward,
                      isSelected: _direction == CurtainDirection.fromTop,
                      onPressed: () {
                        setState(() {
                          _direction = CurtainDirection.fromTop;
                        });
                      },
                    ),
                    _DirectionButton(
                      label: 'Aşağıdan',
                      icon: Icons.arrow_upward,
                      isSelected: _direction == CurtainDirection.fromBottom,
                      onPressed: () {
                        setState(() {
                          _direction = CurtainDirection.fromBottom;
                        });
                      },
                    ),
                    _DirectionButton(
                      label: 'Soldan',
                      icon: Icons.arrow_forward,
                      isSelected: _direction == CurtainDirection.fromLeft,
                      onPressed: () {
                        setState(() {
                          _direction = CurtainDirection.fromLeft;
                        });
                      },
                    ),
                    _DirectionButton(
                      label: 'Sağdan',
                      icon: Icons.arrow_back,
                      isSelected: _direction == CurtainDirection.fromRight,
                      onPressed: () {
                        setState(() {
                          _direction = CurtainDirection.fromRight;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Hızlı butonlar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _revealPercentage = 0.0;
                        });
                      },
                      child: const Text('Kapat'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _revealPercentage = 1.0;
                        });
                      },
                      child: const Text('Aç'),
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
      ],
    );
  }
}

enum CurtainDirection {
  fromTop,
  fromBottom,
  fromLeft,
  fromRight,
}

/// Perde painter
class CurtainPainter extends CustomPainter {
  final double revealPercentage;
  final CurtainDirection direction;

  CurtainPainter({
    required this.revealPercentage,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final curtainPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    Rect curtainRect;

    switch (direction) {
      case CurtainDirection.fromTop:
        // Yukarıdan aşağı açılır
        final revealHeight = size.height * revealPercentage;
        curtainRect = Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height - revealHeight,
        );
        break;

      case CurtainDirection.fromBottom:
        // Aşağıdan yukarı açılır
        final revealHeight = size.height * revealPercentage;
        curtainRect = Rect.fromLTWH(
          0,
          revealHeight,
          size.width,
          size.height - revealHeight,
        );
        break;

      case CurtainDirection.fromLeft:
        // Soldan sağa açılır
        final revealWidth = size.width * revealPercentage;
        curtainRect = Rect.fromLTWH(
          0,
          0,
          size.width - revealWidth,
          size.height,
        );
        break;

      case CurtainDirection.fromRight:
        // Sağdan sola açılır
        final revealWidth = size.width * revealPercentage;
        curtainRect = Rect.fromLTWH(
          revealWidth,
          0,
          size.width - revealWidth,
          size.height,
        );
        break;
    }

    canvas.drawRect(curtainRect, curtainPaint);

    // Perde kenar çizgisi
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(curtainRect, borderPaint);
  }

  @override
  bool shouldRepaint(CurtainPainter oldDelegate) {
    return oldDelegate.revealPercentage != revealPercentage ||
        oldDelegate.direction != direction;
  }
}

class _DirectionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  const _DirectionButton({
    required this.label,
    required this.icon,
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
