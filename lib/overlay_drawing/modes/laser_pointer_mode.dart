import 'package:flutter/material.dart';
import 'dart:async';

/// Laser pointer / Gösterge modu
class LaserPointerMode extends StatefulWidget {
  final VoidCallback? onClose;
  final GlobalKey? panelKey;

  const LaserPointerMode({super.key, this.onClose, this.panelKey});

  @override
  State<LaserPointerMode> createState() => _LaserPointerModeState();
}

class _LaserPointerModeState extends State<LaserPointerMode> {
  Offset? _pointerPosition;
  Color _pointerColor = Colors.red;
  double _pointerSize = 24.0;
  bool _showRipple = true;
  bool _showTrail = true;
  final List<TrailPoint> _trail = [];
  Timer? _trailTimer;

  // Renk seçenekleri
  static const List<Color> _colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.cyan,
  ];

  // Boyut seçenekleri
  static const List<double> _sizes = [16.0, 20.0, 24.0, 32.0, 40.0];

  @override
  void initState() {
    super.initState();
    // Trail temizleme timer'ı
    _trailTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_trail.isNotEmpty && _showTrail) {
        setState(() {
          // Eski trail noktalarını sil
          _trail.removeWhere((point) {
            return DateTime.now().difference(point.timestamp).inMilliseconds >
                500;
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _trailTimer?.cancel();
    super.dispose();
  }

  void _onPointerMove(PointerEvent event) {
    setState(() {
      _pointerPosition = event.localPosition;
      if (_showTrail) {
        _trail.add(
          TrailPoint(position: event.localPosition, timestamp: DateTime.now()),
        );
      }
    });
  }

  void _onPointerExit(PointerEvent event) {
    setState(() {
      _pointerPosition = null;
      _trail.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onPointerMove,
      onExit: _onPointerExit,
      child: Stack(
        children: [
          // Laser pointer overlay
          Positioned.fill(
            child: CustomPaint(
              painter: LaserPointerPainter(
                pointerPosition: _pointerPosition,
                pointerColor: _pointerColor,
                pointerSize: _pointerSize,
                showRipple: _showRipple,
                trail: _showTrail ? _trail : [],
              ),
              size: Size.infinite,
            ),
          ),

          // Kontrol paneli (sağ üst)
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              key: widget.panelKey,
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
                    'Laser Pointer',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),

                  // Renk seçimi
                  const Text('Renk', style: TextStyle(fontSize: 10)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _colors.map((color) {
                      final isSelected = color == _pointerColor;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _pointerColor = color;
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: isSelected ? 8 : 4,
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

                  // Boyut seçimi
                  const Text('Boyut', style: TextStyle(fontSize: 10)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _sizes.map((size) {
                      final isSelected = (size - _pointerSize).abs() < 0.1;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _pointerSize = size;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Container(
                              width: size / 2,
                              height: size / 2,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : _pointerColor,
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

                  // Efekt seçenekleri
                  const Text('Efektler', style: TextStyle(fontSize: 10)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _showRipple,
                        onChanged: (value) {
                          setState(() {
                            _showRipple = value ?? true;
                          });
                        },
                      ),
                      const Text('Dalgalanma', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _showTrail,
                        onChanged: (value) {
                          setState(() {
                            _showTrail = value ?? true;
                            if (!_showTrail) {
                              _trail.clear();
                            }
                          });
                        },
                      ),
                      const Text('İz Bırak', style: TextStyle(fontSize: 10)),
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🔴 Laser Pointer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Mouse ile ekranda istediğiniz yeri gösterin',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  Text(
                    '• Sunum ve eğitimler için ideal',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrailPoint {
  final Offset position;
  final DateTime timestamp;

  TrailPoint({required this.position, required this.timestamp});
}

class LaserPointerPainter extends CustomPainter {
  final Offset? pointerPosition;
  final Color pointerColor;
  final double pointerSize;
  final bool showRipple;
  final List<TrailPoint> trail;

  LaserPointerPainter({
    this.pointerPosition,
    required this.pointerColor,
    required this.pointerSize,
    required this.showRipple,
    required this.trail,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pointerPosition == null) return;

    // Trail (iz) çiz
    if (trail.isNotEmpty) {
      for (int i = 0; i < trail.length; i++) {
        final point = trail[i];
        final age = DateTime.now().difference(point.timestamp).inMilliseconds;
        final opacity = 1.0 - (age / 500.0);

        if (opacity > 0) {
          final trailPaint = Paint()
            ..color = pointerColor.withValues(alpha: opacity * 0.3)
            ..style = PaintingStyle.fill;

          canvas.drawCircle(
            point.position,
            pointerSize * 0.6 * opacity,
            trailPaint,
          );
        }
      }
    }

    // Dalgalanma efekti (ripple)
    if (showRipple) {
      final ripplePaint = Paint()
        ..color = pointerColor.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      // Birden fazla dalgalanma halkası
      for (int i = 1; i <= 3; i++) {
        canvas.drawCircle(pointerPosition!, pointerSize * i * 0.8, ripplePaint);
      }
    }

    // Dış parlama
    final glowPaint = Paint()
      ..color = pointerColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.drawCircle(pointerPosition!, pointerSize * 1.2, glowPaint);

    // Ana laser noktası
    final pointerPaint = Paint()
      ..color = pointerColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pointerPosition!, pointerSize / 2, pointerPaint);

    // İç beyaz nokta (parlama efekti)
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pointerPosition!, pointerSize / 4, innerPaint);
  }

  @override
  bool shouldRepaint(LaserPointerPainter oldDelegate) {
    return true;
  }
}
