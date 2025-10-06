import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'pdf_viewer_with_drawing.dart';
import 'tool_state.dart';
import 'color_dot.dart';

class LeftPanel extends StatefulWidget {
  final PdfController controller;
  final GlobalKey<PdfViewerWithDrawingState> drawingKey;
  const LeftPanel({
    super.key,
    required this.controller,
    required this.drawingKey,
  });

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  final List<Color> colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.black,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
    Colors.grey,
    Colors.yellow,
  ];

  @override
  Widget build(BuildContext context) {
    final state = widget.drawingKey.currentState;
    if (state == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ValueListenableBuilder<ToolState>(
      valueListenable: state.toolNotifier,
      builder: (_, tool, __) {
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: 320,
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // Navigation controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
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

              // Zoom controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toolButton(
                    icon: Icons.zoom_in,
                    tooltip: "Yakınlaştır",
                    onPressed: () => state.zoomIn(),
                    scheme: scheme,
                    color: scheme.secondary,
                  ),
                  _toolButton(
                    icon: Icons.zoom_out,
                    tooltip: "Uzaklaştır",
                    onPressed: () => state.zoomOut(),
                    scheme: scheme,
                    color: scheme.secondary,
                  ),
                  _toolButton(
                    icon: Icons.fit_screen,
                    tooltip: "Zoom sıfırla",
                    onPressed: () => state.resetZoom(),
                    scheme: scheme,
                    color: scheme.secondary,
                  ),
                ],
              ),
              const Divider(height: 24),

              // Rotation controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toolButton(
                    icon: Icons.rotate_left,
                    tooltip: "Sola döndür",
                    onPressed: () => state.rotateLeft(),
                    scheme: scheme,
                    color: scheme.tertiary,
                  ),
                  _toolButton(
                    icon: Icons.rotate_right,
                    tooltip: "Sağa döndür",
                    onPressed: () => state.rotateRight(),
                    scheme: scheme,
                    color: scheme.tertiary,
                  ),
                  _toolButton(
                    icon: Icons.refresh,
                    tooltip: "Döndürmeyi sıfırla",
                    onPressed: () => state.resetRotation(),
                    scheme: scheme,
                    color: scheme.tertiary,
                  ),
                ],
              ),
              const Divider(height: 24),

              // Tools
              const Text(
                "Araçlar",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toolToggle(
                    icon: Icons.pan_tool,
                    tooltip: "Kaydır",
                    active: tool.grab,
                    onPressed: () => state.setGrab(true),
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
                            active:
                                tool.selectedShape == ShapeType.rectangle,
                            onPressed: () =>
                                state.setSelectedShape(ShapeType.rectangle),
                          ),
                          _shapeButton(
                            icon: Icons.circle_outlined,
                            active: tool.selectedShape == ShapeType.circle,
                            onPressed: () =>
                                state.setSelectedShape(ShapeType.circle),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _shapeButton(
                            icon: Icons.remove,
                            active: tool.selectedShape == ShapeType.line,
                            onPressed: () =>
                                state.setSelectedShape(ShapeType.line),
                          ),
                          _shapeButton(
                            icon: Icons.arrow_forward,
                            active: tool.selectedShape == ShapeType.arrow,
                            onPressed: () =>
                                state.setSelectedShape(ShapeType.arrow),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const Divider(),

              // Colors
              const Text(
                "Renkler",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 4,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                  itemCount: colors.length,
                  itemBuilder: (context, index) {
                    final color = colors[index];
                    return ColorDot(
                      color: color,
                      selected:
                          tool.color == color &&
                          (tool.pencil || tool.shape),
                      onTap: () => state.setColor(color),
                    );
                  },
                ),
              ),

              const Divider(),

              // Width slider
              const Text(
                "Genişlik",
                style: TextStyle(fontWeight: FontWeight.bold),
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
        );
      },
    );
  }

  // Button helpers
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    required VoidCallback onPressed,
    required ColorScheme scheme,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: color ?? scheme.surfaceContainerHighest,
          foregroundColor: scheme.onSurface,
          elevation: 0,
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
          foregroundColor: active
              ? scheme.onPrimary
              : scheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          border: active
              ? Border.all(color: scheme.primary, width: 2)
              : null,
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
