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

/// Fatih Kalem benzeri - Sistem genelinde çalışan çizim uygulaması
///
/// Kullanım: flutter run -t lib/drawing_pen_main.dart
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
  DrawingMode _currentMode = DrawingMode.pen; // Aktif mod

  // Sürüklenebilir widget pozisyonları
  Offset _modeSelectorPosition = const Offset(16, 16);
  Offset _toolbarPosition = const Offset(80, 16);

  Widget _buildModeContent() {
    switch (_currentMode) {
      case DrawingMode.pen:
        return DrawingCanvas(
          key: _canvasKey,
          color: _selectedColor,
          strokeWidth: _strokeWidth,
          isEraser: _isEraser,
        );

      case DrawingMode.highlighter:
        return HighlighterMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
            });
          },
        );

      case DrawingMode.text:
        return TextMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
            });
          },
        );

      case DrawingMode.shapes:
        return ShapesMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
            });
          },
        );

      case DrawingMode.shapes3d:
        return Shapes3DMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
            });
          },
        );

      case DrawingMode.ruler:
        return RulerMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
            });
          },
        );

      case DrawingMode.spotlight:
        return SpotlightMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
            });
          },
        );

      case DrawingMode.curtain:
        return CurtainMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
            });
          },
        );

      case DrawingMode.laser:
        return LaserPointerMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
            });
          },
        );

      case DrawingMode.grid:
        return GridMode(
          onClose: () {
            setState(() {
              _currentMode = DrawingMode.pen;
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
          // Aktif mod içeriği
          Positioned.fill(
            child: _buildModeContent(),
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
                  onModeChanged: (mode) {},
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
                onModeChanged: (mode) {
                  setState(() {
                    _currentMode = mode;
                  });
                },
              ),
            ),
          ),

          // Sürüklenebilir toolbar (sadece kalem modunda)
          if (_currentMode == DrawingMode.pen)
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
  final DrawingMode currentMode;
  final Function(DrawingMode) onModeChanged;

  const _ModeSelector({
    required this.currentMode,
    required this.onModeChanged,
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
          // Mod butonları
          ...DrawingMode.values.map((mode) {
            final isSelected = mode == currentMode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Tooltip(
                message: '${mode.name}\n${mode.description}',
                child: IconButton(
                  onPressed: () => onModeChanged(mode),
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
