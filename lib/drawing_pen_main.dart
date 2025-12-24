import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
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
import 'services/virtual_keyboard_service.dart';
import 'widgets/virtual_keyboard.dart';
// import 'overlay_drawing/widgets/widget_overlay_manager.dart'; // [NEW]

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
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            // Virtual keyboard overlay
            ListenableBuilder(
              listenable: VirtualKeyboardService(),
              builder: (context, _) {
                final keyboardService = VirtualKeyboardService();
                if (!keyboardService.isVisible) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: const VirtualKeyboard(),
                );
              },
            ),
          ],
        );
      },
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
  State<TransparentDrawingOverlay> createState() =>
      _TransparentDrawingOverlayState();
}

class _TransparentDrawingOverlayState extends State<TransparentDrawingOverlay> {
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;
  bool _isEraser = false;
  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey();
  DrawingMode? _currentMode; // Aktif mod (null = hiçbir mod seçili değil)
  bool _isMouseMode =
      false; // false = Pen Mode (çizim), true = Mouse Mode (click-through)

  // Sürüklenebilir widget pozisyonları
  Offset _modeSelectorPosition = const Offset(16, 16);
  Offset _toolbarPosition = const Offset(80, 16);

  // Bluetooth
  final BluetoothInputHandler _bluetoothHandler = BluetoothInputHandler();
  bool _bluetoothEnabled = false;

  // Ekran klavyesi algılama
  bool _isKeyboardVisible = false;

  // Mouse Mode Polling
  Timer? _mousePollingTimer;
  final GlobalKey _toolbarKey = GlobalKey();
  final GlobalKey _modeSelectorKey = GlobalKey();
  final GlobalKey _activeModePanelKey =
      GlobalKey(); // Aktif modun paneli için key
  bool _wasMouseOverToolbar = false;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _startKeyboardDetection();
  }

  @override
  void dispose() {
    _bluetoothHandler.stop();
    _stopMousePolling();
    super.dispose();
  }

  /// Ekran klavyesini düzenli olarak kontrol et
  void _startKeyboardDetection() {
    if (!kIsWeb && Platform.isWindows) {
      // Her 500ms'de bir kontrol et
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkKeyboard();
          _startKeyboardDetection();
        }
      });
    }
  }

  /// Mouse pozisyonunu takip et ve toolbar üzerindeyse tıklamaya izin ver
  void _startMousePolling() {
    _stopMousePolling();
    if (kIsWeb || !Platform.isWindows) return;

    // Z-Order koruması için ekstra sayaç
    int checkCount = 0;

    _mousePollingTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) async {
      if (!mounted || !_isMouseMode) {
        timer.cancel();
        return;
      }

      try {
        checkCount++;

        // Her 1 saniyede bir (10 * 100ms) z-order'ı zorla
        if (checkCount % 10 == 0) {
          await windowManager.setAlwaysOnTop(true);
        }

        // Mouse pozisyonunu al
        final cursorOffset = await screenRetriever.getCursorScreenPoint();

        bool isOverUI = false;

        // 1. Toolbar Kontrolü
        final RenderBox? toolbarRenderBox =
            _toolbarKey.currentContext?.findRenderObject() as RenderBox?;

        if (toolbarRenderBox != null) {
          final size = toolbarRenderBox.size;
          final position = toolbarRenderBox.localToGlobal(Offset.zero);
          final rect = position & size;
          if (rect.inflate(10).contains(cursorOffset)) {
            isOverUI = true;
          }
        }

        // 2. Mode Selector Kontrolü
        if (!isOverUI) {
          final RenderBox? modeRenderBox =
              _modeSelectorKey.currentContext?.findRenderObject() as RenderBox?;

          if (modeRenderBox != null) {
            final size = modeRenderBox.size;
            final position = modeRenderBox.localToGlobal(Offset.zero);
            final rect = position & size;
            if (rect.inflate(10).contains(cursorOffset)) {
              isOverUI = true;
            }
          }
        }

        // 3. Aktif Mod Paneli Kontrolü (Sağ menü vb.)
        if (!isOverUI) {
          final RenderBox? panelRenderBox =
              _activeModePanelKey.currentContext?.findRenderObject()
                  as RenderBox?;

          if (panelRenderBox != null) {
            final size = panelRenderBox.size;
            final position = panelRenderBox.localToGlobal(Offset.zero);
            final rect = position & size;
            if (rect.inflate(10).contains(cursorOffset)) {
              isOverUI = true;
            }
          }
        }

        // Durum değiştiyse güncelle
        if (isOverUI != _wasMouseOverToolbar) {
          _wasMouseOverToolbar = isOverUI;

          if (isOverUI) {
            // UI üzerine gelince TIKLANABİLİR yap ve ÖNE GETİR
            await windowManager.setIgnoreMouseEvents(false);
            await windowManager.setAlwaysOnTop(true);
            await windowManager.focus(); // Bu çok önemli, pencereyi öne çeker
          } else {
            // UI dışına çıkınca TIKLAMAYI YOK SAY ama En Üstte tutmaya çalış
            await windowManager.setIgnoreMouseEvents(true, forward: true);
            // Focus'u bırakabiliriz ama alwaysOnTop kalmalı
          }
        }
      } catch (e) {}
    });
  }

  void _stopMousePolling() {
    _mousePollingTimer?.cancel();
    _mousePollingTimer = null;
  }

  /// Windows ekran klavyesinin açık olup olmadığını kontrol et
  Future<void> _checkKeyboard() async {
    if (!kIsWeb && Platform.isWindows) {
      try {
        // tasklist komutu ile ekran klavyesini kontrol et
        final result = await Process.run('tasklist', [
          '/FI',
          'IMAGENAME eq TabTip.exe',
        ]);

        final bool keyboardOpen = result.stdout.toString().contains(
          'TabTip.exe',
        );

        // Durum değiştiyse window ayarlarını güncelle
        if (keyboardOpen != _isKeyboardVisible) {
          setState(() {
            _isKeyboardVisible = keyboardOpen;
          });

          if (!_isMouseMode) {
            // Sadece pen mode'dayken ayarla
            if (_isKeyboardVisible) {
              // Klavye açıldı - always on top'u kapat
              await windowManager.setAlwaysOnTop(false);
            } else {
              // Klavye kapandı - always on top'u tekrar aç
              await windowManager.setAlwaysOnTop(true);
            }
          }
        }
      } catch (e) {
        // Hata oluşursa sessizce devam et
      }
    }
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
        };

        _bluetoothHandler.onMouseDelta = (delta) {
          // TODO: Relative mouse hareketi (daha kullanışlı)
        };

        _bluetoothHandler.onMouseDown = (button) {
          // TODO: Mouse button basıldı
        };

        _bluetoothHandler.onMouseUp = (button) {
          // TODO: Mouse button bırakıldı
        };

        _bluetoothHandler.onKeyDown = (key) {
          // TODO: Klavye tuşu basıldı

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
      case 'm':
        // Toggle mouse/pen mode
        _toggleMouseMode();
        break;
      case 'q':
        // Close app
        if (!kIsWeb && Platform.isWindows) {
          windowManager.close();
        }
        break;
    }
  }

  Future<void> _toggleMouseMode() async {
    setState(() {
      _isMouseMode = !_isMouseMode;
    });

    // Windows'ta window ayarları
    if (!kIsWeb && Platform.isWindows) {
      if (_isMouseMode) {
        // MOUSE MODE: Click-through aktif ama toolbar için polling başlat

        // Polling başlamadan önce garanti olsun diye OnTop yap
        await windowManager.setAlwaysOnTop(true);

        // Başlangıçta click-through yap, polling düzeltecek
        await windowManager.setIgnoreMouseEvents(true, forward: true);
        _startMousePolling();
      } else {
        // PEN MODE: Çizim aktif

        _stopMousePolling();
        await windowManager.setIgnoreMouseEvents(false);
        // Sadece ekran klavyesi açık değilse always on top'u aç
        if (!_isKeyboardVisible) {
          await windowManager.setAlwaysOnTop(true);
        }
        await windowManager.focus(); // Pen moda geçince focus al
      }
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
          panelKey: _activeModePanelKey,
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.text:
        return TextMode(
          panelKey: _activeModePanelKey,
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.shapes:
        return ShapesMode(
          panelKey: _activeModePanelKey,
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.shapes3d:
        return Shapes3DMode(
          panelKey: _activeModePanelKey,
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.ruler:
        return RulerMode(
          panelKey: _activeModePanelKey,
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.spotlight:
        return SpotlightMode(
          panelKey: _activeModePanelKey,
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.curtain:
        return CurtainMode(
          panelKey: _activeModePanelKey,
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.laser:
        return LaserPointerMode(
          panelKey: _activeModePanelKey,
          onClose: () {
            setState(() {
              _currentMode = null;
            });
          },
        );

      case DrawingMode.grid:
        return GridMode(
          panelKey: _activeModePanelKey,
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
    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        // M tuşu ile mouse/pen mode toggle (özellikle mouse modunda önemli)
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyM) {
          _toggleMouseMode();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Aktif mod içeriği (çizim hariç)
            if (_buildModeContent() != null)
              Positioned.fill(child: _buildModeContent()!),

            // Çizim katmanı (sadece Pen Mode'da görünür)
            if (!_isMouseMode)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring:
                      _currentMode != null && _currentMode != DrawingMode.pen,
                  child: DrawingCanvas(
                    key: _canvasKey,
                    color: _selectedColor,
                    strokeWidth: _strokeWidth,
                    isEraser: _isEraser,
                  ),
                ),
              ),

            // Sürüklenebilir mod seçici (Her zaman görünür)
            Positioned(
              left: _modeSelectorPosition.dx,
              top: _modeSelectorPosition.dy,
              child: Draggable(
                feedback: Opacity(
                  opacity: 0.8,
                  child: _ModeSelector(
                    currentMode: _currentMode,
                    isMouseMode: _isMouseMode,
                    onModeChanged: (mode) {},
                    onMouseModeToggle: () {},
                  ),
                ),
                childWhenDragging: Container(),
                onDragEnd: (details) {
                  setState(() {
                    _modeSelectorPosition = details.offset;
                  });
                },
                child: Container(
                  key: _modeSelectorKey,
                  child: _ModeSelector(
                    currentMode: _currentMode,
                    isMouseMode: _isMouseMode,
                    onModeChanged: (mode) {
                      setState(() {
                        _currentMode = mode;
                      });
                    },
                    onMouseModeToggle: _toggleMouseMode,
                  ),
                ),
              ),
            ),

            // Mouse Mode'da SAĞ KENARDAN SWIPE ile çizim moduna dönüş
            // Dokunmatik ekran için ekran kenarından içeri kaydırma hareketi
            if (_isMouseMode)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    // Sağdan sola kaydırma (negatif velocity)
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! < -500) {
                      _toggleMouseMode();
                    }
                  },
                  child: Container(
                    width: 40, // 40px genişliğinde swipe bölgesi
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.orange.shade600.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white.withOpacity(0.6),
                        size: 24,
                      ),
                    ),
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

            // Sürüklenebilir toolbar (Her zaman görünür olsun, Mouse Mode'da da)
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
                      isMouseMode: _isMouseMode,
                      onMouseModeToggle: () {},
                      onColorChanged: (color) {},
                      onStrokeWidthChanged: (width) {},
                      onEraserToggle: () {},
                      onClear: () {},
                      onUndo: () {},
                      onClose: () {},
                      onToolSelected: (toolId) {},
                    ),
                  ),
                ),
                childWhenDragging: Container(),
                onDragEnd: (details) {
                  setState(() {
                    _toolbarPosition = details.offset;
                  });
                },
                child: Container(
                  key: _toolbarKey,
                  child: DrawingToolbar(
                    selectedColor: _selectedColor,
                    strokeWidth: _strokeWidth,
                    isEraser: _isEraser,
                    isMouseMode: _isMouseMode,
                    onMouseModeToggle: _toggleMouseMode,
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
                      if (!kIsWeb &&
                          (Platform.isWindows ||
                              Platform.isLinux ||
                              Platform.isMacOS)) {
                        await windowManager.close();
                      }
                    },
                    onToolSelected: (toolId) {
                      // Placeholder
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mod seçici widget
class _ModeSelector extends StatelessWidget {
  final DrawingMode? currentMode;
  final bool isMouseMode;
  final Function(DrawingMode?) onModeChanged;
  final VoidCallback onMouseModeToggle;

  const _ModeSelector({
    required this.currentMode,
    required this.isMouseMode,
    required this.onModeChanged,
    required this.onMouseModeToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mouse/Pen Mode Toggle Butonu
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Tooltip(
              message: isMouseMode
                  ? '🖱️ Mouse Modu (Tıkla: Çizim Moduna Geç)'
                  : '✏️ Çizim Modu (Tıkla: Mouse Moduna Geç)',
              child: IconButton(
                onPressed: onMouseModeToggle,
                icon: Icon(
                  isMouseMode ? Icons.mouse_rounded : Icons.edit_rounded,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isMouseMode
                      ? Colors.blue.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                  foregroundColor: isMouseMode
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                  side: BorderSide(
                    color: isMouseMode ? Colors.blue : Colors.green,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          // Ayırıcı çizgi
          const Divider(height: 8),

          // Diğer mod butonları
          ...DrawingMode.values.where((mode) => mode != DrawingMode.pen).map((
            mode,
          ) {
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
                  icon: Text(mode.icon, style: const TextStyle(fontSize: 20)),
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
                if (!kIsWeb &&
                    (Platform.isWindows ||
                        Platform.isLinux ||
                        Platform.isMacOS)) {
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
