import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' as vector;

/// 3D Şekiller modu - Döndürülebilir, zoom yapılabilir 3D geometrik şekiller
class Shapes3DMode extends StatefulWidget {
  final VoidCallback? onClose;

  const Shapes3DMode({super.key, this.onClose});

  @override
  State<Shapes3DMode> createState() => _Shapes3DModeState();
}

class _Shapes3DModeState extends State<Shapes3DMode> {
  Shape3DType _selectedShape = Shape3DType.cube;
  Color _selectedColor = Colors.blue;
  double _rotationX = 0.3;
  double _rotationY = 0.3;
  double _rotationZ = 0.0;
  double _zoom = 1.0;
  Offset _position = Offset.zero;
  bool _showWireframe = false;
  bool _showAxes = true;
  bool _autoRotate = false;

  // Renk seçenekleri
  static const List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.cyan,
    Colors.pink,
    Colors.yellow,
    Colors.brown,
    Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    if (_autoRotate) {
      _startAutoRotation();
    }
  }

  void _startAutoRotation() {
    Future.delayed(const Duration(milliseconds: 16), () {
      if (mounted && _autoRotate) {
        setState(() {
          _rotationY = (_rotationY + 0.02) % (math.pi * 2);
        });
        _startAutoRotation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerOffset = Offset(screenSize.width / 2 + _position.dx, screenSize.height / 2 + _position.dy);

    return Stack(
      children: [
        // 3D Render alanı
        Positioned.fill(
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                if (details.delta.dx.abs() > details.delta.dy.abs()) {
                  _rotationY = (_rotationY + details.delta.dx * 0.01) % (math.pi * 2);
                } else {
                  _rotationX = (_rotationX - details.delta.dy * 0.01) % (math.pi * 2);
                }
              });
            },
            child: CustomPaint(
              painter: Shape3DPainter(
                shapeType: _selectedShape,
                color: _selectedColor,
                rotationX: _rotationX,
                rotationY: _rotationY,
                rotationZ: _rotationZ,
                zoom: _zoom,
                center: centerOffset,
                showWireframe: _showWireframe,
                showAxes: _showAxes,
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
            width: 220,
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
                    '3D Şekiller',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Şekil seçimi
                  const Text('Şekil Seç (8 Çeşit)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 1.2,
                    children: Shape3DType.values.map((type) {
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
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                type.icon,
                                color: isSelected ? Colors.white : Colors.black,
                                size: 20,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                type.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
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
                    spacing: 8,
                    runSpacing: 8,
                    children: _colors.map((color) {
                      final isSelected = color == _selectedColor;
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
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),

                  // Rotasyon kontrolleri
                  const Text('Rotasyon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),

                  // X Rotasyonu
                  Row(
                    children: [
                      const Text('X:', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: _rotationX % (math.pi * 2),
                          min: 0,
                          max: math.pi * 2,
                          onChanged: (value) {
                            setState(() {
                              _rotationX = value;
                              _autoRotate = false;
                            });
                          },
                        ),
                      ),
                      Text('${((_rotationX % (math.pi * 2)) * 180 / math.pi).toInt()}°', style: const TextStyle(fontSize: 10)),
                    ],
                  ),

                  // Y Rotasyonu
                  Row(
                    children: [
                      const Text('Y:', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: _rotationY % (math.pi * 2),
                          min: 0,
                          max: math.pi * 2,
                          onChanged: (value) {
                            setState(() {
                              _rotationY = value;
                              _autoRotate = false;
                            });
                          },
                        ),
                      ),
                      Text('${((_rotationY % (math.pi * 2)) * 180 / math.pi).toInt()}°', style: const TextStyle(fontSize: 10)),
                    ],
                  ),

                  // Z Rotasyonu
                  Row(
                    children: [
                      const Text('Z:', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: _rotationZ % (math.pi * 2),
                          min: 0,
                          max: math.pi * 2,
                          onChanged: (value) {
                            setState(() {
                              _rotationZ = value;
                              _autoRotate = false;
                            });
                          },
                        ),
                      ),
                      Text('${((_rotationZ % (math.pi * 2)) * 180 / math.pi).toInt()}°', style: const TextStyle(fontSize: 10)),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Otomatik rotasyon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _autoRotate,
                        onChanged: (value) {
                          setState(() {
                            _autoRotate = value ?? false;
                            if (_autoRotate) {
                              _startAutoRotation();
                            }
                          });
                        },
                      ),
                      const Text('Otomatik Döndür', style: TextStyle(fontSize: 10)),
                    ],
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),

                  // Zoom kontrolü
                  const Text('Zoom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _zoom = (_zoom - 0.1).clamp(0.3, 3.0);
                          });
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                        iconSize: 20,
                      ),
                      Expanded(
                        child: Slider(
                          value: _zoom,
                          min: 0.3,
                          max: 3.0,
                          onChanged: (value) {
                            setState(() {
                              _zoom = value;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _zoom = (_zoom + 0.1).clamp(0.3, 3.0);
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        iconSize: 20,
                      ),
                    ],
                  ),
                  Center(
                    child: Text('${(_zoom * 100).toInt()}%', style: const TextStyle(fontSize: 11)),
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),

                  // Görünüm seçenekleri
                  const Text('Görünüm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _showWireframe,
                        onChanged: (value) {
                          setState(() {
                            _showWireframe = value ?? false;
                          });
                        },
                      ),
                      const Text('Wireframe', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _showAxes,
                        onChanged: (value) {
                          setState(() {
                            _showAxes = value ?? true;
                          });
                        },
                      ),
                      const Text('Eksenler', style: TextStyle(fontSize: 10)),
                    ],
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1),
                  const SizedBox(height: 6),

                  // Reset butonu
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _rotationX = 0.3;
                        _rotationY = 0.3;
                        _rotationZ = 0.0;
                        _zoom = 1.0;
                        _position = Offset.zero;
                        _autoRotate = false;
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Sıfırla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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
                  '🎲 3D Şekiller',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Sürükleyerek döndürün',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  '• Slider\'larla hassas ayar yapın',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  '• Zoom yaparak yakınlaştırın',
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

/// 3D Şekil türleri
enum Shape3DType {
  cube,
  sphere,
  pyramid,
  cylinder,
  cone,
  torus,
  octahedron,
  dodecahedron,
}

extension Shape3DTypeExtension on Shape3DType {
  String get name {
    switch (this) {
      case Shape3DType.cube:
        return 'Küp';
      case Shape3DType.sphere:
        return 'Küre';
      case Shape3DType.pyramid:
        return 'Piramit';
      case Shape3DType.cylinder:
        return 'Silindir';
      case Shape3DType.cone:
        return 'Koni';
      case Shape3DType.torus:
        return 'Halka';
      case Shape3DType.octahedron:
        return 'Sekizyüzlü';
      case Shape3DType.dodecahedron:
        return 'Onikiyüzlü';
    }
  }

  IconData get icon {
    switch (this) {
      case Shape3DType.cube:
        return Icons.view_in_ar;
      case Shape3DType.sphere:
        return Icons.sports_soccer;
      case Shape3DType.pyramid:
        return Icons.landscape;
      case Shape3DType.cylinder:
        return Icons.battery_full;
      case Shape3DType.cone:
        return Icons.change_history;
      case Shape3DType.torus:
        return Icons.donut_large;
      case Shape3DType.octahedron:
        return Icons.diamond;
      case Shape3DType.dodecahedron:
        return Icons.pets;
    }
  }
}

/// 3D Şekilleri çizen painter
class Shape3DPainter extends CustomPainter {
  final Shape3DType shapeType;
  final Color color;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double zoom;
  final Offset center;
  final bool showWireframe;
  final bool showAxes;

  Shape3DPainter({
    required this.shapeType,
    required this.color,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.zoom,
    required this.center,
    required this.showWireframe,
    required this.showAxes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = showWireframe ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 2.0;

    // Eksen çizgileri
    if (showAxes) {
      _drawAxes(canvas);
    }

    switch (shapeType) {
      case Shape3DType.cube:
        _drawCube(canvas, paint);
        break;
      case Shape3DType.sphere:
        _drawSphere(canvas, paint);
        break;
      case Shape3DType.pyramid:
        _drawPyramid(canvas, paint);
        break;
      case Shape3DType.cylinder:
        _drawCylinder(canvas, paint);
        break;
      case Shape3DType.cone:
        _drawCone(canvas, paint);
        break;
      case Shape3DType.torus:
        _drawTorus(canvas, paint);
        break;
      case Shape3DType.octahedron:
        _drawOctahedron(canvas, paint);
        break;
      case Shape3DType.dodecahedron:
        _drawDodecahedron(canvas, paint);
        break;
    }
  }

  void _drawAxes(Canvas canvas) {
    final axisLength = 100.0 * zoom;

    // X ekseni (kırmızı)
    final xEnd = _project(vector.Vector3(axisLength, 0, 0));
    canvas.drawLine(
      center,
      Offset(center.dx + xEnd.dx, center.dy + xEnd.dy),
      Paint()..color = Colors.red..strokeWidth = 2,
    );

    // Y ekseni (yeşil)
    final yEnd = _project(vector.Vector3(0, axisLength, 0));
    canvas.drawLine(
      center,
      Offset(center.dx + yEnd.dx, center.dy + yEnd.dy),
      Paint()..color = Colors.green..strokeWidth = 2,
    );

    // Z ekseni (mavi)
    final zEnd = _project(vector.Vector3(0, 0, axisLength));
    canvas.drawLine(
      center,
      Offset(center.dx + zEnd.dx, center.dy + zEnd.dy),
      Paint()..color = Colors.blue..strokeWidth = 2,
    );
  }

  Offset _project(vector.Vector3 point) {
    // 3D noktayı 2D'ye projeksiyon
    final rotated = _rotate(point);
    final scale = 200.0 * zoom / (200.0 + rotated.z);
    return Offset(rotated.x * scale, -rotated.y * scale);
  }

  vector.Vector3 _rotate(vector.Vector3 point) {
    // X ekseni etrafında rotasyon
    var p = point;
    var cosX = math.cos(rotationX);
    var sinX = math.sin(rotationX);
    var y = p.y * cosX - p.z * sinX;
    var z = p.y * sinX + p.z * cosX;
    p = vector.Vector3(p.x, y, z);

    // Y ekseni etrafında rotasyon
    var cosY = math.cos(rotationY);
    var sinY = math.sin(rotationY);
    var x = p.x * cosY + p.z * sinY;
    z = -p.x * sinY + p.z * cosY;
    p = vector.Vector3(x, p.y, z);

    // Z ekseni etrafında rotasyon
    var cosZ = math.cos(rotationZ);
    var sinZ = math.sin(rotationZ);
    x = p.x * cosZ - p.y * sinZ;
    y = p.x * sinZ + p.y * cosZ;

    return vector.Vector3(x, y, z);
  }

  void _drawCube(Canvas canvas, Paint paint) {
    final size = 80.0;
    final vertices = [
      vector.Vector3(-size, -size, -size),
      vector.Vector3(size, -size, -size),
      vector.Vector3(size, size, -size),
      vector.Vector3(-size, size, -size),
      vector.Vector3(-size, -size, size),
      vector.Vector3(size, -size, size),
      vector.Vector3(size, size, size),
      vector.Vector3(-size, size, size),
    ];

    final projected = vertices.map(_project).toList();

    // Yüzleri çiz
    final faces = [
      [0, 1, 2, 3], // Arka
      [4, 5, 6, 7], // Ön
      [0, 1, 5, 4], // Alt
      [2, 3, 7, 6], // Üst
      [0, 3, 7, 4], // Sol
      [1, 2, 6, 5], // Sağ
    ];

    for (var face in faces) {
      final path = Path();
      path.moveTo(center.dx + projected[face[0]].dx, center.dy + projected[face[0]].dy);
      for (var i = 1; i < face.length; i++) {
        path.lineTo(center.dx + projected[face[i]].dx, center.dy + projected[face[i]].dy);
      }
      path.close();

      if (!showWireframe) {
        canvas.drawPath(path, paint..color = color.withValues(alpha: 0.7));
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  void _drawSphere(Canvas canvas, Paint paint) {
    final radius = 80.0;
    final segments = 20;
    final rings = 16;

    for (var i = 0; i < rings; i++) {
      final lat1 = (i * math.pi / rings) - math.pi / 2;
      final lat2 = ((i + 1) * math.pi / rings) - math.pi / 2;

      for (var j = 0; j < segments; j++) {
        final lon1 = j * 2 * math.pi / segments;
        final lon2 = (j + 1) * 2 * math.pi / segments;

        final v1 = vector.Vector3(
          radius * math.cos(lat1) * math.cos(lon1),
          radius * math.sin(lat1),
          radius * math.cos(lat1) * math.sin(lon1),
        );
        final v2 = vector.Vector3(
          radius * math.cos(lat1) * math.cos(lon2),
          radius * math.sin(lat1),
          radius * math.cos(lat1) * math.sin(lon2),
        );
        final v3 = vector.Vector3(
          radius * math.cos(lat2) * math.cos(lon2),
          radius * math.sin(lat2),
          radius * math.cos(lat2) * math.sin(lon2),
        );
        final v4 = vector.Vector3(
          radius * math.cos(lat2) * math.cos(lon1),
          radius * math.sin(lat2),
          radius * math.cos(lat2) * math.sin(lon1),
        );

        final p1 = _project(v1);
        final p2 = _project(v2);
        final p3 = _project(v3);
        final p4 = _project(v4);

        final path = Path()
          ..moveTo(center.dx + p1.dx, center.dy + p1.dy)
          ..lineTo(center.dx + p2.dx, center.dy + p2.dy)
          ..lineTo(center.dx + p3.dx, center.dy + p3.dy)
          ..lineTo(center.dx + p4.dx, center.dy + p4.dy)
          ..close();

        if (!showWireframe) {
          final brightness = (math.sin(lat1) + 1) / 2;
          canvas.drawPath(path, paint..color = color.withValues(alpha: brightness * 0.7 + 0.3));
        }
        canvas.drawPath(path, paint..style = PaintingStyle.stroke);
      }
    }
  }

  void _drawPyramid(Canvas canvas, Paint paint) {
    final size = 80.0;
    final height = 100.0;

    final vertices = [
      vector.Vector3(0, -height, 0), // Tepe
      vector.Vector3(-size, size / 2, -size), // Taban köşeleri
      vector.Vector3(size, size / 2, -size),
      vector.Vector3(size, size / 2, size),
      vector.Vector3(-size, size / 2, size),
    ];

    final projected = vertices.map(_project).toList();

    // Yüzleri çiz
    final faces = [
      [0, 1, 2], // Yüz 1
      [0, 2, 3], // Yüz 2
      [0, 3, 4], // Yüz 3
      [0, 4, 1], // Yüz 4
      [1, 2, 3, 4], // Taban
    ];

    for (var face in faces) {
      final path = Path();
      path.moveTo(center.dx + projected[face[0]].dx, center.dy + projected[face[0]].dy);
      for (var i = 1; i < face.length; i++) {
        path.lineTo(center.dx + projected[face[i]].dx, center.dy + projected[face[i]].dy);
      }
      path.close();

      if (!showWireframe) {
        canvas.drawPath(path, paint..color = color.withValues(alpha: 0.7));
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  void _drawCylinder(Canvas canvas, Paint paint) {
    final radius = 60.0;
    final height = 100.0;
    final segments = 20;

    for (var i = 0; i < segments; i++) {
      final angle1 = i * 2 * math.pi / segments;
      final angle2 = (i + 1) * 2 * math.pi / segments;

      final v1 = vector.Vector3(radius * math.cos(angle1), -height / 2, radius * math.sin(angle1));
      final v2 = vector.Vector3(radius * math.cos(angle2), -height / 2, radius * math.sin(angle2));
      final v3 = vector.Vector3(radius * math.cos(angle2), height / 2, radius * math.sin(angle2));
      final v4 = vector.Vector3(radius * math.cos(angle1), height / 2, radius * math.sin(angle1));

      final p1 = _project(v1);
      final p2 = _project(v2);
      final p3 = _project(v3);
      final p4 = _project(v4);

      final path = Path()
        ..moveTo(center.dx + p1.dx, center.dy + p1.dy)
        ..lineTo(center.dx + p2.dx, center.dy + p2.dy)
        ..lineTo(center.dx + p3.dx, center.dy + p3.dy)
        ..lineTo(center.dx + p4.dx, center.dy + p4.dy)
        ..close();

      if (!showWireframe) {
        canvas.drawPath(path, paint..color = color.withValues(alpha: 0.7));
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  void _drawCone(Canvas canvas, Paint paint) {
    final radius = 80.0;
    final height = 120.0;
    final segments = 20;

    final apex = vector.Vector3(0, -height / 2, 0);

    for (var i = 0; i < segments; i++) {
      final angle1 = i * 2 * math.pi / segments;
      final angle2 = (i + 1) * 2 * math.pi / segments;

      final v1 = vector.Vector3(radius * math.cos(angle1), height / 2, radius * math.sin(angle1));
      final v2 = vector.Vector3(radius * math.cos(angle2), height / 2, radius * math.sin(angle2));

      final p0 = _project(apex);
      final p1 = _project(v1);
      final p2 = _project(v2);

      final path = Path()
        ..moveTo(center.dx + p0.dx, center.dy + p0.dy)
        ..lineTo(center.dx + p1.dx, center.dy + p1.dy)
        ..lineTo(center.dx + p2.dx, center.dy + p2.dy)
        ..close();

      if (!showWireframe) {
        canvas.drawPath(path, paint..color = color.withValues(alpha: 0.7));
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  void _drawTorus(Canvas canvas, Paint paint) {
    final majorRadius = 70.0;
    final minorRadius = 25.0;
    final majorSegments = 20;
    final minorSegments = 12;

    for (var i = 0; i < majorSegments; i++) {
      for (var j = 0; j < minorSegments; j++) {
        final u1 = i * 2 * math.pi / majorSegments;
        final u2 = (i + 1) * 2 * math.pi / majorSegments;
        final v1 = j * 2 * math.pi / minorSegments;
        final v2 = (j + 1) * 2 * math.pi / minorSegments;

        final vertices = [
          _torusVertex(majorRadius, minorRadius, u1, v1),
          _torusVertex(majorRadius, minorRadius, u2, v1),
          _torusVertex(majorRadius, minorRadius, u2, v2),
          _torusVertex(majorRadius, minorRadius, u1, v2),
        ];

        final projected = vertices.map(_project).toList();

        final path = Path()
          ..moveTo(center.dx + projected[0].dx, center.dy + projected[0].dy)
          ..lineTo(center.dx + projected[1].dx, center.dy + projected[1].dy)
          ..lineTo(center.dx + projected[2].dx, center.dy + projected[2].dy)
          ..lineTo(center.dx + projected[3].dx, center.dy + projected[3].dy)
          ..close();

        if (!showWireframe) {
          canvas.drawPath(path, paint..color = color.withValues(alpha: 0.7));
        }
        canvas.drawPath(path, paint..style = PaintingStyle.stroke);
      }
    }
  }

  vector.Vector3 _torusVertex(double majorRadius, double minorRadius, double u, double v) {
    return vector.Vector3(
      (majorRadius + minorRadius * math.cos(v)) * math.cos(u),
      minorRadius * math.sin(v),
      (majorRadius + minorRadius * math.cos(v)) * math.sin(u),
    );
  }

  void _drawOctahedron(Canvas canvas, Paint paint) {
    final size = 80.0;
    final vertices = [
      vector.Vector3(0, -size, 0),
      vector.Vector3(-size, 0, 0),
      vector.Vector3(0, 0, -size),
      vector.Vector3(size, 0, 0),
      vector.Vector3(0, 0, size),
      vector.Vector3(0, size, 0),
    ];

    final faces = [
      [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1],
      [5, 2, 1], [5, 3, 2], [5, 4, 3], [5, 1, 4],
    ];

    _drawFaces(canvas, paint, vertices, faces);
  }

  void _drawDodecahedron(Canvas canvas, Paint paint) {
    final phi = (1 + math.sqrt(5)) / 2;
    final size = 50.0;

    final vertices = [
      vector.Vector3(size, size, size),
      vector.Vector3(size, size, -size),
      vector.Vector3(size, -size, size),
      vector.Vector3(size, -size, -size),
      vector.Vector3(-size, size, size),
      vector.Vector3(-size, size, -size),
      vector.Vector3(-size, -size, size),
      vector.Vector3(-size, -size, -size),
      vector.Vector3(0, size / phi, size * phi),
      vector.Vector3(0, size / phi, -size * phi),
      vector.Vector3(0, -size / phi, size * phi),
      vector.Vector3(0, -size / phi, -size * phi),
      vector.Vector3(size / phi, size * phi, 0),
      vector.Vector3(size / phi, -size * phi, 0),
      vector.Vector3(-size / phi, size * phi, 0),
      vector.Vector3(-size / phi, -size * phi, 0),
      vector.Vector3(size * phi, 0, size / phi),
      vector.Vector3(size * phi, 0, -size / phi),
      vector.Vector3(-size * phi, 0, size / phi),
      vector.Vector3(-size * phi, 0, -size / phi),
    ];

    final faces = [
      [0, 8, 10, 2, 16],
      [0, 16, 17, 1, 12],
      [0, 12, 14, 4, 8],
      [1, 17, 3, 11, 9],
      [1, 9, 5, 14, 12],
      [2, 10, 6, 15, 13],
      [2, 13, 3, 17, 16],
      [3, 13, 15, 7, 11],
      [4, 14, 5, 19, 18],
      [4, 18, 6, 10, 8],
      [5, 9, 11, 7, 19],
      [6, 18, 19, 7, 15],
    ];

    _drawFaces(canvas, paint, vertices, faces);
  }

  void _drawFaces(Canvas canvas, Paint paint, List<vector.Vector3> vertices, List<List<int>> faces) {
    final projected = vertices.map(_project).toList();

    for (var face in faces) {
      final path = Path();
      path.moveTo(center.dx + projected[face[0]].dx, center.dy + projected[face[0]].dy);
      for (var i = 1; i < face.length; i++) {
        path.lineTo(center.dx + projected[face[i]].dx, center.dy + projected[face[i]].dy);
      }
      path.close();

      if (!showWireframe) {
        canvas.drawPath(path, paint..color = color.withValues(alpha: 0.7));
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(Shape3DPainter oldDelegate) {
    return true;
  }
}
