import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'overlay_drawing/drawing_canvas.dart';
import 'overlay_drawing/drawing_toolbar.dart';
import 'overlay_drawing/drawing_mode.dart';
import 'overlay_drawing/modes/spotlight_mode.dart';
import 'overlay_drawing/modes/curtain_mode.dart';
import 'overlay_drawing/modes/text_mode.dart';
import 'overlay_drawing/modes/shapes_mode.dart';
import 'overlay_drawing/modes/highlighter_mode.dart';
import 'overlay_drawing/modes/ruler_mode.dart';
import 'overlay_drawing/modes/laser_pointer_mode.dart';
import 'overlay_drawing/modes/grid_mode.dart';
import 'overlay_drawing/modes/shapes_3d_mode.dart';
import 'services/bluetooth_input_handler.dart';

@pragma('vm:entry-point')
void drawingPenMain() {
  main();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sadece desktop'ta çalışır
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    // Ekran boyutunu al
    final primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final screenWidth = primaryDisplay.size.width;
    final screenHeight = primaryDisplay.size.height;

    // Transparent, always-on-top, tam ekran window
    WindowOptions windowOptions = WindowOptions(
      size: Size(screenWidth, screenHeight),
      center: false,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      alwaysOnTop: true,
      fullScreen: false,
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setAsFrameless();

      // Linux için özel transparency ayarları
      if (Platform.isLinux) {
        await windowManager.setBackgroundColor(Colors.transparent);
      }

      await windowManager.setAlwaysOnTop(true);
      await windowManager.setPosition(Offset.zero);
      await windowManager.setSize(Size(screenWidth, screenHeight));
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const DrawingPenApp());
}

class DrawingPenApp extends StatelessWidget {
  const DrawingPenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Çizim Kalemi',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const TransparentDrawingOverlay(),
    );
  }
}

/// Transparent overlay window
class TransparentDrawingOverlay extends StatefulWidget {
  const TransparentDrawingOverlay({super.key});

  @override
  State<TransparentDrawingOverlay> createState() => _TransparentDrawingOverlayState();
}

class _TransparentDrawingOverlayState extends State<TransparentDrawingOverlay> {
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;
  bool _isEraser = false;
  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey();
  DrawingMode? _currentMode; // Aktif mod (null = hiçbir mod seçili değil)
  bool _drawingEnabled = true; // Çizim modu açık/kapalı

  // Sürüklenebilir widget pozisyonları
  Offset _modeSelectorPosition = const Offset(16, 16);
  Offset _toolbarPosition = const Offset(80, 16);

  // Bluetooth
  final BluetoothInputHandler _bluetoothHandler = BluetoothInputHandler();
  bool _bluetoothEnabled = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    _bluetoothHandler.stop();
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    // Sadece Windows'ta Bluetooth'u başlat
    if (!kIsWeb && Platform.isWindows) {
      final started = await _bluetoothHandler.start(
        serviceName: 'Drawing Pen Remote',
      );

      if (started) {
        setState(() {
          _bluetoothEnabled = true;
        });

        // Mouse/keyboard event handler'ları ayarla
        _bluetoothHandler.onMouseMove = (position) {
          // TODO: Absolute mouse pozisyonu
          debugPrint('Mouse move: $position');
        };

        _bluetoothHandler.onMouseDelta = (delta) {
          // TODO: Relative mouse hareketi (daha kullanışlı)
          debugPrint('Mouse delta: $delta');
        };

        _bluetoothHandler.onMouseDown = (button) {
          // TODO: Mouse button basıldı
          debugPrint('Mouse down: $button');
        };

        _bluetoothHandler.onMouseUp = (button) {
          // TODO: Mouse button bırakıldı
          debugPrint('Mouse up: $button');
        };

        _bluetoothHandler.onKeyDown = (key) {
          // TODO: Klavye tuşu basıldı
          debugPrint('Key down: $key');
          _handleRemoteKeyPress(key);
        };
      }
    }
  }

  void _handleRemoteKeyPress(String key) {
    // Klavye kısayolları
    switch (key.toLowerCase()) {
      case 'c':
        // Clear canvas
        _canvasKey.currentState?.clear();
        break;
      case 'z':
        // Undo
        _canvasKey.currentState?.undo();
        break;
      case 'e':
        // Toggle eraser
        setState(() {
          _isEraser = !_isEraser;
        });
        break;
      case 'q':
        // Close app
        if (!kIsWeb && Platform.isWindows) {
          windowManager.close();
        }
        break;
    }
  }

  Widget? _buildModeContent() {
    if (_currentMode == null) return null;

    switch (_currentMode!) {
      case DrawingMode.pen:
        // Pen modu artık ayrı bir katmanda, buraya gelmeyecek
        return null;

      case DrawingMode.highlighter:
        return HighlighterMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.text:
        return TextMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.shapes:
        return ShapesMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.shapes3d:
        return Shapes3DMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.ruler:
        return RulerMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.spotlight:
        return SpotlightMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.curtain:
        return CurtainMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.laser:
        return LaserPointerMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.grid:
        return GridMode(
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Aktif mod içeriği (çizim hariç)
          if (_buildModeContent() != null)
            Positioned.fill(
              child: _buildModeContent()!,
            ),

          // Çizim katmanı (her zaman en üstte, açık/kapalı toggle edilebilir)
          if (_drawingEnabled)
            Positioned.fill(
              child: DrawingCanvas(
                key: _canvasKey,
                color: _selectedColor,
                strokeWidth: _strokeWidth,
                isEraser: _isEraser,
              ),
            ),

          // Sürüklenebilir mod seçici (her zaman görünür)
          Positioned(
            left: _modeSelectorPosition.dx,
            top: _modeSelectorPosition.dy,
            child: Draggable(
              feedback: Opacity(
                opacity: 0.8,
                child: _ModeSelector(
                  currentMode: _currentMode,
                  drawingEnabled: _drawingEnabled,
                  onModeChanged: (mode) {},
                  onDrawingToggle: () {},
                ),
              ),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  _modeSelectorPosition = details.offset;
                });
              },
              child: _ModeSelector(
                currentMode: _currentMode,
                drawingEnabled: _drawingEnabled,
                onModeChanged: (mode) {
                  setState(() {
                    _currentMode = mode;
                  });
                },
                onDrawingToggle: () {
                  setState(() {
                    _drawingEnabled = !_drawingEnabled;
                  });
                },
              ),
            ),
          ),

          // Bluetooth status indicator (sağ üst köşe)
          if (_bluetoothEnabled)
            Positioned(
              right: 16,
              top: 16,
              child: BluetoothStatusIndicator(handler: _bluetoothHandler),
            ),

          // Sürüklenebilir toolbar (sadece çizim modu açıkken)
          if (_drawingEnabled)
            Positioned(
              left: _toolbarPosition.dx,
              top: _toolbarPosition.dy,
              child: Draggable(
                feedback: Opacity(
                  opacity: 0.8,
                  child: Material(
                    color: Colors.transparent,
                    child: DrawingToolbar(
                      selectedColor: _selectedColor,
                      strokeWidth: _strokeWidth,
                      isEraser: _isEraser,
                      onColorChanged: (color) {},
                      onStrokeWidthChanged: (width) {},
                      onEraserToggle: () {},
                      onClear: () {},
                      onUndo: () {},
                      onClose: () {},
                    ),
                  ),
                ),
                childWhenDragging: Container(),
                onDragEnd: (details) {
                  setState(() {
                    _toolbarPosition = details.offset;
                  });
                },
                child: DrawingToolbar(
                  selectedColor: _selectedColor,
                  strokeWidth: _strokeWidth,
                  isEraser: _isEraser,
                  onColorChanged: (color) {
                    setState(() {
                      _selectedColor = color;
                      _isEraser = false;
                    });
                  },
                  onStrokeWidthChanged: (width) {
                    setState(() {
                      _strokeWidth = width;
                    });
                  },
                  onEraserToggle: () {
                    setState(() {
                      _isEraser = !_isEraser;
                    });
                  },
                  onClear: () {
                    _canvasKey.currentState?.clear();
                  },
                  onUndo: () {
                    _canvasKey.currentState?.undo();
                  },
                  onClose: () async {
                    // Uygulamayı kapat
                    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
                      await windowManager.close();
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mod seçici widget
class _ModeSelector extends StatelessWidget {
  final DrawingMode? currentMode;
  final bool drawingEnabled;
  final Function(DrawingMode?) onModeChanged;
  final VoidCallback onDrawingToggle;

  const _ModeSelector({
    required this.currentMode,
    required this.drawingEnabled,
    required this.onModeChanged,
    required this.onDrawingToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Çizim Modu Toggle Butonu (Özel)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Tooltip(
              message: 'Çizim Modu ${drawingEnabled ? "Açık" : "Kapalı"}\n${DrawingMode.pen.description}',
              child: IconButton(
                onPressed: onDrawingToggle,
                icon: Text(
                  DrawingMode.pen.icon,
                  style: const TextStyle(fontSize: 20),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: drawingEnabled
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.grey.withValues(alpha: 0.2),
                  side: drawingEnabled
                      ? const BorderSide(color: Colors.green, width: 2)
                      : null,
                ),
              ),
            ),
          ),

          // Ayırıcı çizgi
          const Divider(height: 8),

          // Diğer mod butonları
          ...DrawingMode.values.where((mode) => mode != DrawingMode.pen).map((mode) {
            final isSelected = mode == currentMode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Tooltip(
                message: '${mode.name}\n${mode.description}',
                child: IconButton(
                  onPressed: () {
                    // Aynı modu tekrar seçerse kapat
                    if (isSelected) {
                      onModeChanged(null);
                    } else {
                      onModeChanged(mode);
                    }
                  },
                  icon: Text(
                    mode.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isSelected
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.transparent,
                    side: isSelected
                        ? const BorderSide(color: Colors.blue, width: 2)
                        : null,
                  ),
                ),
              ),
            );
          }),

          // Ayırıcı çizgi
          const Divider(height: 8),

          // Kapatma butonu
          Tooltip(
            message: 'Çizim Kalemini Kapat',
            child: IconButton(
              onPressed: () async {
                if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
                  await windowManager.close();
                }
              },
              icon: const Icon(Icons.close_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
