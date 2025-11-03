import 'package:flutter/material.dart';
import 'package:icons_flutter/icons_flutter.dart';
import 'package:pdfx/pdfx.dart';
import 'pdf_viewer_with_drawing.dart';
import 'tool_state.dart';
import '../services/user_preferences_service.dart';

// Import new components
import '../features/drawing/presentation/widgets/tool_panel/tool_panel_components.dart';
import '../features/pdf_viewer/presentation/widgets/page_navigation_buttons.dart';

class FloatingLeftPanel extends StatefulWidget {
  final PdfController controller;
  final GlobalKey<PdfViewerWithDrawingState> drawingKey;
  final VoidCallback? onSolveProblem;

  const FloatingLeftPanel({
    super.key,
    required this.controller,
    required this.drawingKey,
    this.onSolveProblem,
  });

  @override
  State<FloatingLeftPanel> createState() => _FloatingLeftPanelState();
}

class _FloatingLeftPanelState extends State<FloatingLeftPanel> {
  UserPreferencesService? _prefs;
  bool _isInitialized = false;

  // Panel state
  Offset _position = const Offset(20, 100);
  double _panelWidth = 200.0;
  final double _minWidth = 150.0;
  final double _maxWidth = 400.0;
  double _panelHeight = 600.0;
  final double _minHeight = 400.0;
  final double _maxHeight = 900.0;

  bool _isDragging = false;
  bool _isResizingRight = false;
  bool _isResizingBottom = false;
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
    PdfViewerWithDrawingState state,
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
            onPressed: () => state.setMouse(true),
          ),
          ToolButtonCompact(
            icon: Icons.brush,
            tooltip: 'Kalem',
            isSelected: tool.pencil,
            onPressed: () => state.setPencil(true),
          ),
          ToolButtonCompact(
            icon: Icons.highlight,
            tooltip: 'Highlighter',
            isSelected: tool.highlighter,
            selectedColor: Colors.yellow.shade600,
            onPressed: () => state.setHighlighter(true),
          ),
          ToolButtonCompact(
            icon: Icons.search,
            tooltip: 'Büyüteç',
            isSelected: tool.magnifier,
            selectedColor: const Color(0xFF9C27B0),
            onPressed: () => state.setMagnifier(!tool.magnifier),
          ),
          ToolButtonCompact(
            icon: Icons.cleaning_services,
            tooltip: 'Silgi',
            isSelected: tool.eraser,
            onPressed: () => state.setEraser(true),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    ToolState tool,
    ColorScheme scheme,
    PdfViewerWithDrawingState state,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Page Navigation
        PageNavigationButtons(controller: widget.controller, isCompact: false),
        const Divider(height: 24),

        // AI Solve Button
        if (widget.onSolveProblem != null) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onSolveProblem,
              icon: const Icon(Icons.auto_awesome, size: 20),
              label: const Text('Soru Çöz'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const Divider(height: 24),
        ],

        // Undo/Redo
        const Text(
          'Geri Al / İleri Al',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: state.canUndoNotifier,
          builder: (context, canUndo, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: state.canRedoNotifier,
              builder: (context, canRedo, _) {
                return UndoRedoButtons(
                  canUndo: canUndo,
                  canRedo: canRedo,
                  onUndo: () => state.undo(),
                  onRedo: () => state.redo(),
                  isCompact: false,
                );
              },
            );
          },
        ),
        const Divider(height: 24),

        // Zoom controls
        const Text(
          'Zoom',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ToolButton(
              icon: Icons.zoom_in,
              tooltip: 'Yakınlaştır',
              isSelected: false,
              onPressed: () => state.zoomIn(),
              size: 42,
            ),
            ToolButton(
              icon: Icons.zoom_out,
              tooltip: 'Uzaklaştır',
              isSelected: false,
              onPressed: () => state.zoomOut(),
              size: 42,
            ),
            ToolButton(
              icon: Icons.fit_screen,
              tooltip: 'Zoom Sıfırla',
              isSelected: false,
              onPressed: () => state.resetZoom(),
              size: 42,
            ),
          ],
        ),
        const Divider(height: 24),

        // Rotation controls
        const Text(
          'Döndürme',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ToolButton(
              icon: Icons.rotate_left,
              tooltip: 'Sola Döndür',
              isSelected: false,
              onPressed: () => state.rotateLeft(),
              size: 42,
            ),
            ToolButton(
              icon: Icons.rotate_right,
              tooltip: 'Sağa Döndür',
              isSelected: false,
              onPressed: () => state.rotateRight(),
              size: 42,
            ),
            ToolButton(
              icon: Icons.refresh,
              tooltip: 'Döndürmeyi Sıfırla',
              isSelected: false,
              onPressed: () => state.resetRotation(),
              size: 42,
            ),
          ],
        ),
        const Divider(height: 24),

        // Drawing Tools
        const Text(
          'Araçlar',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ToolButton(
              icon: Icons.pan_tool,
              tooltip: 'Kaydır / Swipe',
              isSelected: tool.mouse || tool.grab,
              onPressed: () => state.setMouse(true),
            ),
            ToolButton(
              icon: Icons.brush,
              tooltip: 'Kalem',
              isSelected: tool.pencil,
              onPressed: () => state.setPencil(true),
            ),
            ToolButton(
              icon: Icons.highlight,
              tooltip: 'Fosforlu Kalem',
              isSelected: tool.highlighter,
              selectedColor: Colors.yellow.shade600,
              onPressed: () => state.setHighlighter(true),
            ),
            ToolButton(
              icon: Icons.category,
              tooltip: 'Şekiller',
              isSelected: tool.shape,
              onPressed: () => state.setShape(true),
            ),
            ToolButton(
              icon: Icons.crop_free,
              tooltip: 'Alan Seç',
              isSelected: tool.selection,
              selectedColor: const Color(0xFF2196F3),
              onPressed: () => state.setSelection(!tool.selection),
            ),
            ToolButton(
              icon: Icons.search,
              tooltip: 'Büyüteç',
              isSelected: tool.magnifier,
              selectedColor: const Color(0xFF9C27B0),
              onPressed: () => state.setMagnifier(!tool.magnifier),
            ),
            ToolButton(
              icon: Icons.cleaning_services,
              tooltip: 'Silgi',
              isSelected: tool.eraser,
              onPressed: () => state.setEraser(true),
            ),
            ToolButton(
              icon: FontAwesome.trash_o,
              tooltip: 'Sayfayı Temizle',
              isSelected: false,
              onPressed: () => state.clearCurrentPage(),
            ),
          ],
        ),

        // Shape Selector
        if (tool.shape) ...[
          const SizedBox(height: 12),
          ShapeSelector(
            selectedShape: tool.selectedShape,
            onShapeSelected: (shape) => state.setSelectedShape(shape),
          ),
        ],

        const Divider(height: 24),

        // Color Picker
        const Text(
          'Renk',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Center(
          child: ColorPickerButton(
            currentColor: tool.color,
            onColorChanged: (color) => state.setColor(color),
            size: 50,
          ),
        ),

        const SizedBox(height: 16),

        // Width Slider
        WidthSlider(
          width: tool.width,
          min: 2.0,
          max: 10.0,
          onChanged: (value) => state.setWidth(value),
          label: 'Kalınlık',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.drawingKey.currentState;
    if (state == null || !_isInitialized) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<ToolState>(
      valueListenable: state.toolNotifier,
      builder: (_, tool, __) {
        final scheme = Theme.of(context).colorScheme;

        return Stack(
          children: [
            // Main panel
            Positioned(
              left: _position.dx,
              top: _position.dy,
              child: Material(
                elevation: _isDragging ? 12 : 8,
                borderRadius: BorderRadius.circular(16),
                color: scheme.surface,
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDragging
                          ? scheme.primary.withValues(alpha: 0.5)
                          : scheme.outlineVariant,
                      width: _isDragging ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
                          _buildCollapsedContent(tool, scheme, state)
                        else
                          Expanded(
                            child: _buildExpandedContent(tool, scheme, state),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Resize handles
            if (!_isCollapsed) ...[
              // Right resize handle
              _buildResizeHandle(
                left: _position.dx + _panelWidth + 6,
                top: _position.dy + (_panelHeight / 2) - 35,
                width: 12,
                height: 70,
                isActive: _isResizingRight,
                isHorizontal: false,
                scheme: scheme,
                onPanStart: () => setState(() => _isResizingRight = true),
                onPanUpdate: (delta) {
                  setState(() {
                    _panelWidth = (_panelWidth + delta.dx).clamp(
                      _minWidth,
                      _maxWidth,
                    );
                  });
                },
                onPanEnd: () {
                  setState(() => _isResizingRight = false);
                  _saveSize();
                },
              ),

              // Bottom resize handle
              _buildResizeHandle(
                left: _position.dx + (_panelWidth / 2) - 35,
                top: _position.dy + _panelHeight + 6,
                width: 70,
                height: 12,
                isActive: _isResizingBottom,
                isHorizontal: true,
                scheme: scheme,
                onPanStart: () => setState(() => _isResizingBottom = true),
                onPanUpdate: (delta) {
                  setState(() {
                    _panelHeight = (_panelHeight + delta.dy).clamp(
                      _minHeight,
                      _maxHeight,
                    );
                  });
                },
                onPanEnd: () {
                  setState(() => _isResizingBottom = false);
                  _saveSize();
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
  }) {
    return Positioned(
      left: left,
      top: top,
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
    );
  }
}
