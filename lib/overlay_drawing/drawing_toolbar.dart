import 'package:flutter/material.dart';

/// Çizim araçları toolbar'ı (Fatih Kalem tarzı)
class DrawingToolbar extends StatefulWidget {
  final Color selectedColor;
  final double strokeWidth;
  final bool isEraser;
  final Function(Color) onColorChanged;
  final Function(double) onStrokeWidthChanged;
  final VoidCallback onEraserToggle;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onClose;

  const DrawingToolbar({
    super.key,
    required this.selectedColor,
    required this.strokeWidth,
    required this.isEraser,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onEraserToggle,
    required this.onClear,
    required this.onUndo,
    required this.onClose,
  });

  @override
  State<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends State<DrawingToolbar> {
  bool _showColorPicker = false;
  bool _showSizePicker = false;

  // 24 renk paleti (Fatih Kalem gibi)
  static const List<Color> _colors = [
    Colors.black,
    Color(0xFF424242), // Koyu gri
    Color(0xFF9E9E9E), // Açık gri
    Colors.white,
    Color(0xFFD2691E), // Kahverengi
    Color(0xFFFFC0CB), // Pembe

    Color(0xFFB71C1C), // Koyu kırmızı
    Colors.red,
    Color(0xFFEF5350), // Açık kırmızı
    Color(0xFFFF5722), // Turuncu kırmızı
    Colors.orange,
    Color(0xFFFFB300), // Altın sarısı

    Colors.yellow,
    Color(0xFFCDDC39), // Lime
    Color(0xFF8BC34A), // Açık yeşil
    Colors.green,
    Color(0xFF388E3C), // Koyu yeşil
    Color(0xFF00897B), // Teal

    Colors.cyan,
    Color(0xFF03A9F4), // Açık mavi
    Colors.blue,
    Color(0xFF3F51B5), // Indigo
    Color(0xFF9C27B0), // Mor
    Color(0xFF673AB7), // Koyu mor
  ];

  // 6 kalem boyutu (Fatih Kalem gibi)
  static const List<double> _sizes = [1.0, 2.0, 3.0, 5.0, 8.0, 12.0];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ana Toolbar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Kalem/Silgi toggle
                _ToolButton(
                  icon: widget.isEraser ? Icons.create_rounded : Icons.edit_rounded,
                  tooltip: widget.isEraser ? 'Kalem' : 'Silgi',
                  isSelected: !widget.isEraser,
                  onPressed: widget.onEraserToggle,
                  child: !widget.isEraser
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.selectedColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 8),

                // Renk seçici
                if (!widget.isEraser)
                  _ToolButton(
                    icon: Icons.palette_rounded,
                    tooltip: 'Renk Seç',
                    isSelected: _showColorPicker,
                    onPressed: () {
                      setState(() {
                        _showColorPicker = !_showColorPicker;
                        if (_showColorPicker) _showSizePicker = false;
                      });
                    },
                  ),
                if (!widget.isEraser) const SizedBox(height: 8),

                // Boyut seçici
                _ToolButton(
                  icon: Icons.line_weight_rounded,
                  tooltip: 'Kalem Boyutu',
                  isSelected: _showSizePicker,
                  onPressed: () {
                    setState(() {
                      _showSizePicker = !_showSizePicker;
                      if (_showSizePicker) _showColorPicker = false;
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Geri al
                _ToolButton(
                  icon: Icons.undo_rounded,
                  tooltip: 'Geri Al',
                  onPressed: widget.onUndo,
                ),
                const SizedBox(height: 8),

                // Temizle
                _ToolButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Tümünü Temizle',
                  onPressed: widget.onClear,
                  color: Colors.red.shade700,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Renk paleti (popup)
          if (_showColorPicker)
            Container(
              width: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Renk Seçin',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colors.map((color) {
                      final isSelected = color.toARGB32() == widget.selectedColor.toARGB32();
                      return GestureDetector(
                        onTap: () {
                          widget.onColorChanged(color);
                          setState(() {
                            _showColorPicker = false;
                          });
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey.shade300,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Boyut seçici (popup)
          if (_showSizePicker)
            Container(
              width: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kalem Boyutu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._sizes.map((size) {
                    final isSelected = (widget.strokeWidth - size).abs() < 0.1;
                    return GestureDetector(
                      onTap: () {
                        widget.onStrokeWidthChanged(size);
                        setState(() {
                          _showSizePicker = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: size * 3,
                              height: size * 3,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${size.toStringAsFixed(0)} pt',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Toolbar butonu widget'ı
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isSelected;
  final Color? color;
  final Widget? child;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isSelected = false,
    this.color,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: isSelected
                ? BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue, width: 2),
                  )
                : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  color: color ?? (isSelected ? Colors.blue : Colors.grey.shade700),
                  size: 20,
                ),
                if (child != null)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: child!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
