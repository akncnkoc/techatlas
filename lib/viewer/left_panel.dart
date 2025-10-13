import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'pdf_viewer_with_drawing.dart';
import 'tool_state.dart';

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
  // Panel pozisyonu
  Offset _position = const Offset(20, 100);

  // Panel boyutu
  double _scale = 1.0;
  final double _minScale = 0.6;
  final double _maxScale = 1.5;

  // Panel genişliği
  double _panelWidth = 200.0;
  final double _minWidth = 150.0;
  final double _maxWidth = 400.0;

  // Drag/resize state
  bool _isDragging = false;
  bool _isResizing = false;
  bool _isScaling = false;

  // Panel görünürlüğü
  bool _isCollapsed = false;
  bool _isPinned = false;

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

  Widget _buildPanelContent(
    ToolState tool,
    ColorScheme scheme,
    PdfViewerWithDrawingState state,
  ) {
    if (_isCollapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => setState(() => _isCollapsed = false),
            tooltip: 'Paneli Aç',
          ),
        ],
      );
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        // Panel kontrolleri (header)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Araç Paneli',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: scheme.onSurface,
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
                  onPressed: () => setState(() => _isPinned = !_isPinned),
                  tooltip: _isPinned ? 'Sabitlemeyi Kaldır' : 'Sabitle',
                ),
                const SizedBox(width: 4),
                // Collapse butonu
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _isCollapsed = true),
                  tooltip: 'Küçült',
                ),
              ],
            ),
          ],
        ),
        const Divider(height: 16),

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
          child: Text("Geri Al / İleri Al", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                      color: canUndo ? scheme.primaryContainer : scheme.surfaceContainerHighest.withOpacity(0.5),
                    ),
                    _toolButton(
                      icon: Icons.redo,
                      tooltip: "İleri Al (Ctrl+Y)",
                      onPressed: canRedo ? () => state.redo() : null,
                      scheme: scheme,
                      color: canRedo ? scheme.primaryContainer : scheme.surfaceContainerHighest.withOpacity(0.5),
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
              icon: Icons.clear,
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

        // Color Picker
        const Center(
          child: Text("Renk", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Center(
          child: InkWell(
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
        ),

        const Divider(),

        // Width slider
        const Center(
          child: Text(
            "Genişlik",
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

        const Divider(),

        // Panel Scale Slider
        const Center(
          child: Text(
            "Panel Boyutu",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Row(
          children: [
            Icon(
              Icons.photo_size_select_small,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
            Expanded(
              child: Slider(
                value: _scale,
                min: _minScale,
                max: _maxScale,
                divisions: 18,
                onChanged: (v) => setState(() => _scale = v),
              ),
            ),
            Icon(
              Icons.photo_size_select_large,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.drawingKey.currentState;
    if (state == null) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<ToolState>(
      valueListenable: state.toolNotifier,
      builder: (_, tool, __) {
        final scheme = Theme.of(context).colorScheme;

        return Stack(
          children: [
            Positioned(
              left: _position.dx,
              top: _position.dy,
              child: Transform.scale(
                scale: _scale,
                alignment: Alignment.topLeft,
                child: GestureDetector(
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
                              (_position.dx + details.delta.dx).clamp(
                                0,
                                MediaQuery.of(context).size.width -
                                    (_panelWidth * _scale),
                              ),
                              (_position.dy + details.delta.dy).clamp(
                                0,
                                MediaQuery.of(context).size.height - 100,
                              ),
                            );
                          });
                        },
                  onPanEnd: _isPinned
                      ? null
                      : (details) {
                          setState(() => _isDragging = false);
                        },
                  child: Material(
                    elevation: _isDragging ? 12 : 8,
                    borderRadius: BorderRadius.circular(16),
                    color: scheme.surface,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    child: Container(
                      width: _isCollapsed ? 60 : _panelWidth,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                        child: _buildPanelContent(tool, scheme, state),
                      ),
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
          foregroundColor: onPressed == null ? scheme.onSurface.withOpacity(0.3) : scheme.onSurface,
          elevation: 0,
          disabledBackgroundColor: color ?? scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurface.withOpacity(0.3),
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
