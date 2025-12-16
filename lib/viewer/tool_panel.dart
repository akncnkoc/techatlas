import 'package:techatlas/viewer/drawing_provider.dart';
import 'package:flutter/material.dart';
import 'package:icons_flutter/icons_flutter.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'tool_state.dart';
import '../services/user_preferences_service.dart';

// Import new components
import '../features/drawing/presentation/widgets/tool_panel/tool_panel_components.dart';
import '../features/pdf_viewer/presentation/widgets/page_navigation_buttons.dart';

class ToolPanel extends StatefulWidget {
  final PdfViewerController controller;
  final VoidCallback? onSolveProblem;
  final ValueNotifier<ToolState>? toolNotifier;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final ValueNotifier<bool>? canUndoNotifier;
  final ValueNotifier<bool>? canRedoNotifier;

  const ToolPanel({
    super.key,
    required this.controller,
    this.onSolveProblem,
    this.toolNotifier,
    this.onUndo,
    this.onRedo,
    this.onClear,
    this.canUndoNotifier,
    this.canRedoNotifier,
  });

  @override
  State<ToolPanel> createState() => _ToolPanelState();
}

class _ToolPanelState extends State<ToolPanel> {
  UserPreferencesService? _prefs;
  bool _isInitialized = false;

  // Helper method to update both DrawingProvider and toolNotifier
  void _updateTool(
    DrawingProvider provider,
    ToolState Function(ToolState) updater,
  ) {
    // Update DrawingProvider
    provider.setTool(updater);

    // Also update toolNotifier if provided
    if (widget.toolNotifier != null) {
      widget.toolNotifier!.value = updater(widget.toolNotifier!.value);
    }
  }

  // Panel state
  Offset _position = const Offset(20, 100);
  double _panelWidth = 300.0;
  final double _minWidth = 300.0;
  final double _maxWidth = 400.0;
  double _panelHeight = 300.0;
  final double _minHeight = 300.0;
  double _maxHeight = 500.0;

  bool _isDragging = false;
  bool _isResizingRight = false;
  bool _isResizingBottom = false;
  bool _isResizingTop = false;
  bool _isCollapsed = false;
  bool _isPinned = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _prefs = await UserPreferencesService.getInstance();
    setState(() {
      _position = _prefs!.leftPanelPosition;
      _panelWidth = _prefs!.leftPanelWidth;
      _panelHeight = _prefs!.leftPanelHeight;
      _isCollapsed = _prefs!.isLeftPanelCollapsed;
      _isPinned = _prefs!.isLeftPanelPinned;
      _isInitialized = true;
    });
  }

  Future<void> _savePosition() async {
    await _prefs?.setLeftPanelPosition(_position);
  }

  Future<void> _saveSize() async {
    await _prefs?.setLeftPanelWidth(_panelWidth);
    await _prefs?.setLeftPanelHeight(_panelHeight);
  }

  Future<void> _saveCollapsed(bool value) async {
    await _prefs?.setLeftPanelCollapsed(value);
  }

  Future<void> _savePinned(bool value) async {
    await _prefs?.setLeftPanelPinned(value);
  }

  Widget _buildCollapsedContent(
    ToolState tool,
    ColorScheme scheme,
    DrawingProvider provider,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expand button
          IconButton(
            icon: const Icon(Icons.menu, size: 20),
            onPressed: () {
              setState(() => _isCollapsed = false);
              _saveCollapsed(false);
            },
            tooltip: 'Paneli Aç',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const Divider(height: 8),

          // Navigation (compact)
          PageNavigationButtons(controller: widget.controller, isCompact: true),

          const Divider(height: 8),

          // Tools (compact)
          ToolButtonCompact(
            icon: Icons.pan_tool,
            tooltip: 'Kaydır',
            isSelected: tool.mouse || tool.grab,
            onPressed: () => _updateTool(
              provider,
              (t) => t.copyWith(
                mouse: true,
                grab: false,
                pencil: false,
                highlighter: false,
                eraser: false,
                shape: false,
                selection: false,
                magnifier: false,
              ),
            ),
          ),
          ToolButtonCompact(
            icon: Icons.brush,
            tooltip: 'Kalem',
            isSelected: tool.pencil,
            onPressed: () => _updateTool(
              provider,
              (t) => t.copyWith(
                pencil: true,
                mouse: false,
                grab: false,
                highlighter: false,
                eraser: false,
                shape: false,
                selection: false,
                magnifier: false,
              ),
            ),
          ),
          ToolButtonCompact(
            icon: Icons.highlight,
            tooltip: 'Highlighter',
            isSelected: tool.highlighter,
            selectedColor: Colors.yellow.shade600,
            onPressed: () => _updateTool(
              provider,
              (t) => t.copyWith(
                highlighter: true,
                pencil: false,
                mouse: false,
                grab: false,
                eraser: false,
                shape: false,
                selection: false,
                magnifier: false,
              ),
            ),
          ),
          ToolButtonCompact(
            icon: Icons.search,
            tooltip: 'Büyüteç',
            isSelected: tool.magnifier,
            selectedColor: const Color(0xFF9C27B0),
            onPressed: () => _updateTool(
              provider,
              (t) => t.copyWith(
                magnifier: !t.magnifier,
                pencil: false,
                mouse: false,
                grab: false,
                highlighter: false,
                eraser: false,
                shape: false,
                selection: false,
              ),
            ),
          ),
          ToolButtonCompact(
            icon: Icons.cleaning_services,
            tooltip: 'Silgi',
            isSelected: tool.eraser,
            onPressed: () => _updateTool(
              provider,
              (t) => t.copyWith(
                eraser: true,
                pencil: false,
                mouse: false,
                grab: false,
                highlighter: false,
                shape: false,
                selection: false,
                magnifier: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    ToolState tool,
    ColorScheme scheme,
    DrawingProvider provider,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Page Navigation
        PageNavigationButtons(controller: widget.controller, isCompact: false),
        const Divider(height: 16),

        // Undo/Redo section header with gradient
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.3),
                scheme.primaryContainer.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Geri Al / İleri Al',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: scheme.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        // Use ValueListenableBuilder to listen to canUndo/canRedo changes
        widget.canUndoNotifier != null && widget.canRedoNotifier != null
            ? ValueListenableBuilder<bool>(
                valueListenable: widget.canUndoNotifier!,
                builder: (context, canUndo, child) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.canRedoNotifier!,
                    builder: (context, canRedo, child) {
                      return UndoRedoButtons(
                        canUndo: canUndo,
                        canRedo: canRedo,
                        onUndo: widget.onUndo ?? () {},
                        onRedo: widget.onRedo ?? () {},
                        isCompact: false,
                      );
                    },
                  );
                },
              )
            : UndoRedoButtons(
                canUndo: provider.canUndo,
                canRedo: provider.canRedo,
                onUndo: () {
                  provider.undo();
                  widget.onUndo?.call();
                },
                onRedo: () {
                  provider.redo();
                  widget.onRedo?.call();
                },
                isCompact: false,
              ),
        const Divider(height: 16),

        // Zoom section header with gradient
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.secondaryContainer.withValues(alpha: 0.3),
                scheme.secondaryContainer.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.zoom_in_rounded, size: 14, color: scheme.secondary),
              const SizedBox(width: 6),
              Text(
                'Zoom',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: scheme.secondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            ToolButton(
              icon: Icons.zoom_in,
              tooltip: 'Yakınlaştır',
              isSelected: false,
              onPressed: () => provider.zoomIn(),
              size: 36,
            ),
            ToolButton(
              icon: Icons.zoom_out,
              tooltip: 'Uzaklaştır',
              isSelected: false,
              onPressed: () => provider.zoomOut(),
              size: 36,
            ),
            ToolButton(
              icon: Icons.fit_screen,
              tooltip: 'Zoom Sıfırla',
              isSelected: false,
              onPressed: () => provider.resetZoom(),
              size: 36,
            ),
          ],
        ),
        const Divider(height: 16),

        // Rotation section header with gradient
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.tertiaryContainer.withValues(alpha: 0.3),
                scheme.tertiaryContainer.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.rotate_90_degrees_cw_rounded,
                size: 14,
                color: scheme.tertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'Döndürme',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: scheme.tertiary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            ToolButton(
              icon: Icons.rotate_left,
              tooltip: 'Sola Döndür',
              isSelected: false,
              onPressed: () => provider.rotateLeft(),
              size: 42,
            ),
            ToolButton(
              icon: Icons.rotate_right,
              tooltip: 'Sağa Döndür',
              isSelected: false,
              onPressed: () => provider.rotateRight(),
              size: 42,
            ),
            ToolButton(
              icon: Icons.refresh,
              tooltip: 'Döndürmeyi Sıfırla',
              isSelected: false,
              onPressed: () => provider.resetRotation(),
              size: 42,
            ),
          ],
        ),
        const Divider(height: 16),

        // Tools section header with gradient
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.3),
                scheme.primaryContainer.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction_rounded, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Araçlar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: scheme.primary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            ToolButton(
              icon: Icons.pan_tool,
              tooltip: 'Kaydır / Swipe',
              isSelected: tool.mouse || tool.grab,
              onPressed: () => _updateTool(
                provider,
                (t) => t.copyWith(
                  mouse: true,
                  grab: false,
                  pencil: false,
                  highlighter: false,
                  eraser: false,
                  shape: false,
                  selection: false,
                  magnifier: false,
                ),
              ),
            ),
            ToolButton(
              icon: Icons.brush,
              tooltip: 'Kalem',
              isSelected: tool.pencil,
              onPressed: () => _updateTool(
                provider,
                (t) => t.copyWith(
                  pencil: true,
                  mouse: false,
                  grab: false,
                  highlighter: false,
                  eraser: false,
                  shape: false,
                  selection: false,
                  magnifier: false,
                ),
              ),
            ),
            ToolButton(
              icon: Icons.highlight,
              tooltip: 'Fosforlu Kalem',
              isSelected: tool.highlighter,
              selectedColor: Colors.yellow.shade600,
              onPressed: () => _updateTool(
                provider,
                (t) => t.copyWith(
                  highlighter: true,
                  pencil: false,
                  mouse: false,
                  grab: false,
                  eraser: false,
                  shape: false,
                  selection: false,
                  magnifier: false,
                ),
              ),
            ),
            ToolButton(
              icon: Icons.category,
              tooltip: 'Şekiller',
              isSelected: tool.shape,
              onPressed: () => _updateTool(
                provider,
                (t) => t.copyWith(
                  shape: true,
                  pencil: false,
                  mouse: false,
                  grab: false,
                  highlighter: false,
                  eraser: false,
                  selection: false,
                  magnifier: false,
                ),
              ),
            ),
            ToolButton(
              icon: Icons.crop_free,
              tooltip: 'Alan Seç',
              isSelected: tool.selection,
              selectedColor: const Color(0xFF2196F3),
              onPressed: () => _updateTool(
                provider,
                (t) => t.copyWith(
                  selection: !t.selection,
                  pencil: false,
                  mouse: false,
                  grab: false,
                  highlighter: false,
                  eraser: false,
                  shape: false,
                  magnifier: false,
                ),
              ),
            ),
            ToolButton(
              icon: Icons.search,
              tooltip: 'Büyüteç',
              isSelected: tool.magnifier,
              selectedColor: const Color(0xFF9C27B0),
              onPressed: () => _updateTool(
                provider,
                (t) => t.copyWith(
                  magnifier: !t.magnifier,
                  pencil: false,
                  mouse: false,
                  grab: false,
                  highlighter: false,
                  eraser: false,
                  shape: false,
                  selection: false,
                ),
              ),
            ),
            ToolButton(
              icon: Icons.cleaning_services,
              tooltip: 'Silgi',
              isSelected: tool.eraser,
              onPressed: () => _updateTool(
                provider,
                (t) => t.copyWith(
                  eraser: true,
                  pencil: false,
                  mouse: false,
                  grab: false,
                  highlighter: false,
                  shape: false,
                  selection: false,
                  magnifier: false,
                ),
              ),
            ),
            ToolButton(
              icon: FontAwesome.trash_o,
              tooltip: 'Sayfayı Temizle',
              isSelected: false,
              onPressed: () {
                provider.clearCurrentPage();
                widget.onClear?.call();
              },
            ),
          ],
        ),

        // Shape Selector
        if (tool.shape) ...[
          const SizedBox(height: 12),
          ShapeSelector(
            selectedShape: tool.selectedShape,
            onShapeSelected: (shape) {
              print('🔷 Şekil seçildi: $shape');
              // Update DrawingProvider
              provider.setTool(
                (t) => t.copyWith(selectedShape: shape, shape: true),
              );
              // Also update toolNotifier if provided
              if (widget.toolNotifier != null) {
                print('🔷 toolNotifier güncelleniyor: $shape');
                widget.toolNotifier!.value = widget.toolNotifier!.value
                    .copyWith(selectedShape: shape, shape: true);
              }
            },
          ),
        ],

        const Divider(height: 16),

        // Color section header with gradient
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.secondaryContainer.withValues(alpha: 0.3),
                scheme.secondaryContainer.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.palette_rounded, size: 14, color: scheme.secondary),
              const SizedBox(width: 6),
              Text(
                'Renk',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: scheme.secondary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        Center(
          child: ColorPickerButton(
            currentColor: tool.color,
            onColorChanged: (color) {
              print('🎨 Renk seçildi: $color');
              // Update DrawingProvider
              provider.setColor(color);
              // Also update toolNotifier if provided
              if (widget.toolNotifier != null) {
                print('🎨 toolNotifier güncelleniyor: $color');
                widget.toolNotifier!.value = widget.toolNotifier!.value
                    .copyWith(color: color);
              }
            },
            size: 50,
          ),
        ),

        const SizedBox(height: 12),

        // Width section header with gradient
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.tertiaryContainer.withValues(alpha: 0.3),
                scheme.tertiaryContainer.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.line_weight_rounded, size: 14, color: scheme.tertiary),
              const SizedBox(width: 6),
              Text(
                'Kalınlık',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: scheme.tertiary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),

        // Width Slider
        WidthSlider(
          width: tool.width,
          min: 2.0,
          max: 10.0,
          onChanged: (value) {
            print('📏 Kalınlık seçildi: $value');
            // Update DrawingProvider
            provider.setWidth(value);
            // Also update toolNotifier if provided
            if (widget.toolNotifier != null) {
              print('📏 toolNotifier güncelleniyor: $value');
              widget.toolNotifier!.value = widget.toolNotifier!.value.copyWith(
                width: value,
              );
            }
          },
          label: 'Kalınlık',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final calculatedMaxHeight = (screenHeight / 2) + 200;

    if (_maxHeight != calculatedMaxHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _maxHeight = calculatedMaxHeight;
            if (_panelHeight > _maxHeight) {
              _panelHeight = _maxHeight;
            }
          });
        }
      });
    }

    return Consumer<DrawingProvider>(
      builder: (context, provider, child) {
        final tool = provider.toolState;
        final scheme = Theme.of(context).colorScheme;

        return Stack(
          children: [
            Positioned(
              left: _position.dx,
              top: _position.dy,
              child: Material(
                elevation: _isDragging ? 12 : 8,
                borderRadius: BorderRadius.circular(12),
                color: scheme.surface.withValues(alpha: 0.92),
                shadowColor: Colors.black.withValues(alpha: 0.3),
                child: Container(
                  width: _isCollapsed ? 60 : _panelWidth,
                  height: _isCollapsed ? null : _panelHeight,
                  constraints: _isCollapsed
                      ? BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                        )
                      : BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.9,
                          maxWidth: MediaQuery.of(context).size.width * 0.4,
                        ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isDragging
                          ? scheme.primary.withValues(alpha: 0.5)
                          : scheme.outlineVariant,
                      width: _isDragging ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: _isCollapsed
                          ? MainAxisSize.min
                          : MainAxisSize.max,
                      children: [
                        // Header (draggable)
                        GestureDetector(
                          onPanStart: _isPinned
                              ? null
                              : (details) => setState(() => _isDragging = true),
                          onPanUpdate: _isPinned
                              ? null
                              : (details) {
                                  setState(() {
                                    _position = Offset(
                                      (_position.dx + details.delta.dx).clamp(
                                        0,
                                        MediaQuery.of(context).size.width -
                                            (_isCollapsed ? 60 : _panelWidth),
                                      ),
                                      (_position.dy + details.delta.dy).clamp(
                                        0,
                                        MediaQuery.of(context).size.height -
                                            100,
                                      ),
                                    );
                                  });
                                },
                          onPanEnd: _isPinned
                              ? null
                              : (details) {
                                  setState(() => _isDragging = false);
                                  _savePosition();
                                },
                          child: PanelHeader(
                            isCollapsed: _isCollapsed,
                            isPinned: _isPinned,
                            onTogglePin: () {
                              setState(() => _isPinned = !_isPinned);
                              _savePinned(_isPinned);
                            },
                            onCollapse: () {
                              setState(() => _isCollapsed = true);
                              _saveCollapsed(true);
                            },
                            onExpand: () {
                              setState(() => _isCollapsed = false);
                              _saveCollapsed(false);
                            },
                          ),
                        ),

                        // Content
                        if (_isCollapsed)
                          _buildCollapsedContent(tool, scheme, provider)
                        else
                          Expanded(
                            child: _buildExpandedContent(
                              tool,
                              scheme,
                              provider,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Resize handles
            if (!_isCollapsed) ...[
              // Right resize handle (Sağa doğru genişletme)
              _buildResizeHandle(
                left: _position.dx + _panelWidth - 6,
                top: _position.dy + (_panelHeight / 2) - 35,
                width: 12,
                height: 70,
                isActive: _isResizingRight,
                isHorizontal: false,
                scheme: scheme,
                cursor: SystemMouseCursors.resizeLeftRight,
                onPanStart: () => setState(() => _isResizingRight = true),
                onPanUpdate: (delta) {
                  setState(() {
                    final newWidth = (_panelWidth + delta.dx).clamp(
                      _minWidth,
                      _maxWidth,
                    );
                    _panelWidth = newWidth;
                  });
                },
                onPanEnd: () {
                  setState(() => _isResizingRight = false);
                  _saveSize();
                },
              ),

              // Bottom resize handle (Aşağı doğru uzatma)
              _buildResizeHandle(
                left: _position.dx + (_panelWidth / 2) - 35,
                top: _position.dy + _panelHeight - 6,
                width: 70,
                height: 12,
                isActive: _isResizingBottom,
                isHorizontal: true,
                scheme: scheme,
                cursor: SystemMouseCursors.resizeUpDown,
                onPanStart: () => setState(() => _isResizingBottom = true),
                onPanUpdate: (delta) {
                  setState(() {
                    var newHeight = (_panelHeight + delta.dy).clamp(
                      _minHeight,
                      _maxHeight,
                    );
                    _panelHeight = newHeight;
                  });
                },
                onPanEnd: () {
                  setState(() => _isResizingBottom = false);
                  _saveSize();
                },
              ),

              // Top resize handle (Yukarı doğru uzatma - pozisyon da değişir)
              _buildResizeHandle(
                left: _position.dx + (_panelWidth / 2) - 35,
                top: _position.dy - 6,
                width: 70,
                height: 12,
                isActive: _isResizingTop,
                isHorizontal: true,
                scheme: scheme,
                cursor: SystemMouseCursors.resizeUpDown,
                onPanStart: () => setState(() => _isResizingTop = true),
                onPanUpdate: (delta) {
                  setState(() {
                    // Yukarı sürüklerken (delta.dy negatif), paneli büyüt
                    final newHeight = (_panelHeight - delta.dy).clamp(
                      _minHeight,
                      _maxHeight,
                    );
                    final actualDelta = newHeight - _panelHeight;

                    // Pozisyonu ayarla (yukarı büyürken pozisyon yukarı kaymalı)
                    final newPosY = (_position.dy - actualDelta).clamp(
                      0.0,
                      MediaQuery.of(context).size.height - _minHeight,
                    );

                    _position = Offset(_position.dx, newPosY);
                    _panelHeight = newHeight;
                  });
                },
                onPanEnd: () {
                  setState(() => _isResizingTop = false);
                  _saveSize();
                  _savePosition();
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResizeHandle({
    required double left,
    required double top,
    required double width,
    required double height,
    required bool isActive,
    required bool isHorizontal,
    required ColorScheme scheme,
    required VoidCallback onPanStart,
    required Function(Offset) onPanUpdate,
    required VoidCallback onPanEnd,
    MouseCursor? cursor,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor:
            cursor ??
            (isHorizontal
                ? SystemMouseCursors.resizeUpDown
                : SystemMouseCursors.resizeLeftRight),
        child: GestureDetector(
          onPanStart: (_) => onPanStart(),
          onPanUpdate: (details) => onPanUpdate(details.delta),
          onPanEnd: (_) => onPanEnd(),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: isActive ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: scheme.outlineVariant, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: isHorizontal
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Padding(
                          padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                          child: Container(
                            width: 8,
                            height: 3,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Padding(
                          padding: EdgeInsets.only(top: i > 0 ? 4 : 0),
                          child: Container(
                            width: 3,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
