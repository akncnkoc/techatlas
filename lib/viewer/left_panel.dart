import 'package:flutter/material.dart';
import 'package:icons_flutter/icons_flutter.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'pdf_viewer_with_drawing.dart';
import 'tool_state.dart';
import '../services/user_preferences_service.dart';

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

  // Panel pozisyonu
  Offset _position = const Offset(20, 100);

  // Panel boyutları
  double _panelWidth = 200.0;
  final double _minWidth = 150.0;
  final double _maxWidth = 400.0;

  double _panelHeight = 600.0;
  final double _minHeight = 400.0;
  final double _maxHeight = 900.0;

  // Drag/resize state
  bool _isDragging = false;
  bool _isResizingRight = false;
  bool _isResizingBottom = false;

  // Panel görünürlüğü
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

  void _showColorPicker(
    BuildContext context,
    Color currentColor,
    Function(Color) onColorChanged,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color tempColor = currentColor;
        return AlertDialog(
          title: const Text('Renk Seçin'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (Color color) {
                tempColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              displayThumbColor: true,
              enableAlpha: false,
              labelTypes: const [],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Seç'),
              onPressed: () {
                onColorChanged(tempColor);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPanelHeader(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: _isCollapsed
          ? Center(
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Araç Paneli',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pin butonu
                    IconButton(
                      icon: Icon(
                        _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _isPinned = !_isPinned);
                        _savePinned(_isPinned);
                      },
                      tooltip: _isPinned ? 'Sabitlemeyi Kaldır' : 'Sabitle',
                    ),
                    const SizedBox(width: 4),
                    // Collapse butonu
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _isCollapsed = true);
                        _saveCollapsed(true);
                      },
                      tooltip: 'Küçült',
                    ),
                  ],
                ),
              ],
            ),
    );
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
          // Expand butonu
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
          // Navigation butonları
          IconButton(
            icon: const Icon(Icons.first_page, size: 18),
            onPressed: () => widget.controller.jumpToPage(1),
            tooltip: 'İlk sayfa',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 18),
            onPressed: () => widget.controller.previousPage(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn,
            ),
            tooltip: 'Önceki sayfa',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 18),
            onPressed: () => widget.controller.nextPage(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeIn,
            ),
            tooltip: 'Sonraki sayfa',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.last_page, size: 18),
            onPressed: () => widget.controller.jumpToPage(
              widget.controller.pagesCount ?? 1,
            ),
            tooltip: 'Son sayfa',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const Divider(height: 8),
          // Araçlar
          IconButton(
            icon: Icon(
              Icons.pan_tool,
              size: 18,
              color: tool.mouse || tool.grab ? scheme.primary : null,
            ),
            onPressed: () => state.setMouse(true),
            tooltip: 'Kaydır',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(
              Icons.brush,
              size: 18,
              color: tool.pencil ? scheme.primary : null,
            ),
            onPressed: () => state.setPencil(true),
            tooltip: 'Kalem',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(
              Icons.highlight,
              size: 18,
              color: tool.highlighter ? Colors.yellow.shade600 : null,
            ),
            onPressed: () => state.setHighlighter(true),
            tooltip: 'Highlighter',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(
              Icons.cleaning_services,
              size: 18,
              color: tool.eraser ? scheme.primary : null,
            ),
            onPressed: () => state.setEraser(true),
            tooltip: 'Silgi',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelContent(
    ToolState tool,
    ColorScheme scheme,
    PdfViewerWithDrawingState state,
  ) {
    if (_isCollapsed) {
      return _buildCollapsedContent(tool, scheme, state);
    }

    return Column(
      children: [
        // Scrollable content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              // Navigation buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _navButton(
              icon: Icons.first_page,
              tooltip: "İlk sayfa",
              onPressed: () => widget.controller.jumpToPage(1),
              scheme: scheme,
            ),
            _navButton(
              icon: Icons.last_page,
              tooltip: "Son sayfa",
              onPressed: () => widget.controller.jumpToPage(
                widget.controller.pagesCount ?? 1,
              ),
              scheme: scheme,
            ),
            _navButton(
              icon: Icons.chevron_left,
              tooltip: "Önceki sayfa",
              onPressed: () => widget.controller.previousPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeIn,
              ),
              scheme: scheme,
            ),
            _navButton(
              icon: Icons.chevron_right,
              tooltip: "Sonraki sayfa",
              onPressed: () => widget.controller.nextPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeIn,
              ),
              scheme: scheme,
            ),
          ],
        ),
        const Divider(height: 24),

        // SORU ÇÖZ BUTONU
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

        // Undo/Redo controls
        const Center(
          child: Text(
            "Geri Al / İleri Al",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<bool>(
          valueListenable: state.canUndoNotifier,
          builder: (context, canUndo, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: state.canRedoNotifier,
              builder: (context, canRedo, _) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _toolButton(
                      icon: Icons.undo,
                      tooltip: "Geri Al (Ctrl+Z)",
                      onPressed: canUndo ? () => state.undo() : null,
                      scheme: scheme,
                      color: canUndo
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    _toolButton(
                      icon: Icons.redo,
                      tooltip: "İleri Al (Ctrl+Y)",
                      onPressed: canRedo ? () => state.redo() : null,
                      scheme: scheme,
                      color: canRedo
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const Divider(height: 24),

        // Zoom controls
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _toolButton(
              icon: Icons.zoom_in,
              tooltip: "Yakınlaştır",
              onPressed: () => state.zoomIn(),
              scheme: scheme,
            ),
            _toolButton(
              icon: Icons.zoom_out,
              tooltip: "Uzaklaştır",
              onPressed: () => state.zoomOut(),
              scheme: scheme,
            ),
            _toolButton(
              icon: Icons.fit_screen,
              tooltip: "Zoom sıfırla",
              onPressed: () => state.resetZoom(),
              scheme: scheme,
            ),
          ],
        ),
        const Divider(height: 24),

        // Rotation controls
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _toolButton(
              icon: Icons.rotate_left,
              tooltip: "Sola döndür",
              onPressed: () => state.rotateLeft(),
              scheme: scheme,
            ),
            _toolButton(
              icon: Icons.rotate_right,
              tooltip: "Sağa döndür",
              onPressed: () => state.rotateRight(),
              scheme: scheme,
            ),
            _toolButton(
              icon: Icons.refresh,
              tooltip: "Döndürmeyi sıfırla",
              onPressed: () => state.resetRotation(),
              scheme: scheme,
            ),
          ],
        ),
        const Divider(height: 24),

        // Tools
        const Center(
          child: Text("Araçlar", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _toolToggle(
              icon: Icons.pan_tool,
              tooltip: "Kaydır / Swipe (Hızlı kaydırarak sayfa değiştir)",
              active: tool.mouse || tool.grab,
              onPressed: () => state.setMouse(true),
              scheme: scheme,
            ),
            _toolToggle(
              icon: Icons.brush,
              tooltip: "Kalem",
              active: tool.pencil,
              onPressed: () => state.setPencil(true),
              scheme: scheme,
            ),
            _toolToggle(
              icon: Icons.highlight,
              tooltip: "Fosforlu Kalem (Highlighter)",
              active: tool.highlighter,
              onPressed: () => state.setHighlighter(true),
              scheme: scheme,
              activeColor: Colors.yellow.shade600,
            ),
            _toolToggle(
              icon: Icons.category,
              tooltip: "Şekiller",
              active: tool.shape,
              onPressed: () => state.setShape(true),
              scheme: scheme,
            ),
            _toolToggle(
              icon: Icons.crop_free,
              tooltip: "Alan Seç",
              active: tool.selection,
              onPressed: () => state.setSelection(!tool.selection),
              scheme: scheme,
              activeColor: const Color(0xFF2196F3),
            ),
            _toolToggle(
              icon: Icons.cleaning_services,
              tooltip: "Silgi",
              active: tool.eraser,
              onPressed: () => state.setEraser(true),
              scheme: scheme,
            ),
            _toolButton(
              icon: FontAwesome.trash_o,
              tooltip: "Sayfayı temizle",
              onPressed: () => state.clearCurrentPage(),
              scheme: scheme,
              color: scheme.errorContainer,
            ),
          ],
        ),

        // Shape selection
        if (tool.shape) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _shapeButton(
                      icon: Icons.crop_free,
                      active: tool.selectedShape == ShapeType.rectangle,
                      onPressed: () =>
                          state.setSelectedShape(ShapeType.rectangle),
                    ),
                    _shapeButton(
                      icon: Icons.circle_outlined,
                      active: tool.selectedShape == ShapeType.circle,
                      onPressed: () => state.setSelectedShape(ShapeType.circle),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _shapeButton(
                      icon: Icons.remove,
                      active: tool.selectedShape == ShapeType.line,
                      onPressed: () => state.setSelectedShape(ShapeType.line),
                    ),
                    _shapeButton(
                      icon: Icons.arrow_forward,
                      active: tool.selectedShape == ShapeType.arrow,
                      onPressed: () => state.setSelectedShape(ShapeType.arrow),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const Divider(),

        Container(
          padding: const EdgeInsets.all(4),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Center(
                    child: Text(
                      "Renk",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showColorPicker(context, tool.color, (color) {
                      state.setColor(color);
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: tool.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.outline, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.palette,
                          color: tool.color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Center(
                    child: Text(
                      "Kalınlık",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Slider(
                    value: tool.width,
                    min: 2,
                    max: 10,
                    divisions: 8,
                    onChanged: (v) => state.setWidth(v),
                  ),
                ],
              ),
            ],
          ),
        ),
            ],
          ),
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
                    child: _isCollapsed
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Draggable Header (collapsed)
                              GestureDetector(
                                onPanStart: _isPinned
                                    ? null
                                    : (details) {
                                        setState(() => _isDragging = true);
                                      },
                                onPanUpdate: _isPinned
                                    ? null
                                    : (details) {
                                        setState(() {
                                          _position = Offset(
                                            (_position.dx + details.delta.dx)
                                                .clamp(
                                              0,
                                              MediaQuery.of(context).size.width -
                                                  60,
                                            ),
                                            (_position.dy + details.delta.dy)
                                                .clamp(
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
                                child: _buildPanelHeader(scheme),
                              ),
                              // Panel Content (collapsed)
                              _buildPanelContent(tool, scheme, state),
                            ],
                          )
                        : Column(
                            children: [
                              // Draggable Header
                              GestureDetector(
                                onPanStart: _isPinned
                                    ? null
                                    : (details) {
                                        setState(() => _isDragging = true);
                                      },
                                onPanUpdate: _isPinned
                                    ? null
                                    : (details) {
                                        setState(() {
                                          _position = Offset(
                                            (_position.dx + details.delta.dx)
                                                .clamp(
                                              0,
                                              MediaQuery.of(context).size.width -
                                                  _panelWidth,
                                            ),
                                            (_position.dy + details.delta.dy)
                                                .clamp(
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
                                child: _buildPanelHeader(scheme),
                              ),
                              // Panel Content
                              Expanded(
                                child: _buildPanelContent(tool, scheme, state),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // Right resize handle (sağ ortada, touch için)
            if (!_isCollapsed)
              Positioned(
                left: _position.dx + _panelWidth + 6,
                top: _position.dy + (_panelHeight / 2) - 35,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() => _isResizingRight = true);
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _panelWidth = (_panelWidth + details.delta.dx).clamp(
                        _minWidth,
                        _maxWidth,
                      );
                    });
                  },
                  onPanEnd: (details) {
                    setState(() => _isResizingRight = false);
                    _saveSize();
                  },
                  child: Container(
                    width: 12,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _isResizingRight
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 3,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 3,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 3,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom resize handle (alt ortada, touch için)
            if (!_isCollapsed)
              Positioned(
                left: _position.dx + (_panelWidth / 2) - 35,
                top: _position.dy + _panelHeight + 6,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() => _isResizingBottom = true);
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _panelHeight = (_panelHeight + details.delta.dy).clamp(
                        _minHeight,
                        _maxHeight,
                      );
                    });
                  },
                  onPanEnd: (details) {
                    setState(() => _isResizingBottom = false);
                    _saveSize();
                  },
                  child: Container(
                    width: 70,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isResizingBottom
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 3,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 3,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 3,
                            decoration: BoxDecoration(
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Button helpers (aynı)
  Widget _navButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required ColorScheme scheme,
  }) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: scheme.surfaceContainerHighest,
          foregroundColor: scheme.primary,
          elevation: 0,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required ColorScheme scheme,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: color ?? scheme.surfaceContainerHighest,
          foregroundColor: onPressed == null
              ? scheme.onSurface.withValues(alpha: 0.3)
              : scheme.onSurface,
          elevation: 0,
          disabledBackgroundColor: color ?? scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.3),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _toolToggle({
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onPressed,
    required ColorScheme scheme,
    Color? activeColor,
    Color? inactiveColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: active
              ? (activeColor ?? scheme.primary)
              : (inactiveColor ?? scheme.surfaceContainerHighest),
          foregroundColor: active ? scheme.onPrimary : scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _shapeButton({
    required IconData icon,
    required bool active,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: active ? Border.all(color: scheme.primary, width: 2) : null,
        ),
        child: Icon(
          icon,
          color: active ? scheme.primary : scheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }
}
