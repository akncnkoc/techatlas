import 'package:flutter/material.dart';
import '../tool_state.dart';
import '../drawing_provider.dart';

class VerticalToolSidebar extends StatefulWidget {
  final ValueNotifier<ToolState> toolNotifier;
  final DrawingProvider drawingProvider;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final VoidCallback? onSolve;
  final VoidCallback? onRotateLeft;
  final VoidCallback? onRotateRight;
  final VoidCallback? onFirstPage;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;
  final VoidCallback? onLastPage;
  final VoidCallback? onToggleThumbnails;
  final ValueNotifier<bool>? canUndoNotifier;
  final ValueNotifier<bool>? canRedoNotifier;
  final Function(DragUpdateDetails)? onDragUpdate;

  const VerticalToolSidebar({
    super.key,
    required this.toolNotifier,
    required this.drawingProvider,
    this.onUndo,
    this.onRedo,
    this.onClear,
    this.onSolve,
    this.onRotateLeft,
    this.onRotateRight,
    this.onFirstPage,
    this.onPreviousPage,
    this.onNextPage,
    this.onLastPage,
    this.onToggleThumbnails,
    this.canUndoNotifier,
    this.canRedoNotifier,
    this.onDragUpdate,
  });

  @override
  State<VerticalToolSidebar> createState() => _VerticalToolSidebarState();
}

class _VerticalToolSidebarState extends State<VerticalToolSidebar> {
  // Helper to update tool
  void _updateTool(ToolState Function(ToolState) updater) {
    widget.drawingProvider.setTool(updater);
    widget.toolNotifier.value = updater(widget.toolNotifier.value);
    setState(() => _isSettingsOpen = false); // Close settings when tool changes
  }

  bool _isSettingsOpen = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<ToolState>(
      valueListenable: widget.toolNotifier,
      builder: (context, tool, child) {
        return Center(
          child: SingleChildScrollView(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // MAIN SIDEBAR
                GestureDetector(
                  onPanUpdate: widget.onDragUpdate,
                  child: Container(
                    margin: const EdgeInsets.only(
                      left: 0,
                    ), // Handled by Positioned
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(2, 2),
                        ),
                      ],
                      border: Border.all(
                        color: scheme.outlineVariant.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag Handle Indicator
                        Container(
                          width: 20,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: scheme.onSurfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        // 1. Navigation / View Tools
                        _SidebarButton(
                          icon: Icons.pan_tool_rounded,
                          tooltip: 'Kaydır',
                          isSelected: tool.mouse || tool.grab,
                          onPressed: () => _updateTool(
                            (t) => t.copyWith(
                              mouse: true,
                              grab: false,
                              pencil: false,
                              eraser: false,
                              highlighter: false,
                              shape: false,
                              selection: false,
                              magnifier: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 2. Drawing Tools
                        _SidebarButton(
                          icon: Icons.edit_rounded,
                          tooltip: 'Kalem',
                          isSelected: tool.pencil || tool.highlighter,
                          onPressed: () {
                            if (tool.pencil) {
                              // Keep pencil active
                            } else {
                              // Switch to pencil
                              _updateTool(
                                (t) => t.copyWith(
                                  pencil: true,
                                  highlighter: false,
                                  mouse: false,
                                  grab: false,
                                  eraser: false,
                                  shape: false,
                                  selection: false,
                                  magnifier: false,
                                ),
                              );
                            }
                          },
                          // Show color indicator
                          child: (tool.pencil || tool.highlighter)
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: tool.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                )
                              : null,
                        ),

                        // const SizedBox(height: 8),
                        // _SidebarButton(
                        //   icon: Icons.select_all_rounded,
                        //   tooltip: 'Seç',
                        //   isSelected: tool.selection,
                        //   onPressed: () => _updateTool(
                        //     (t) => t.copyWith(
                        //       selection: true,
                        //       mouse: false,
                        //       grab: false,
                        //       pencil: false,
                        //       highlighter: false,
                        //       shape: false,
                        //       eraser: false,
                        //       magnifier: false,
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 12),
                        Container(
                          height: 1,
                          width: 24,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 8),
                        _SidebarButton(
                          icon: Icons.search_rounded,
                          tooltip: 'Büyüteç',
                          isSelected: tool.magnifier,
                          onPressed: () => _updateTool(
                            (t) => t.copyWith(
                              magnifier: !t.magnifier, // Toggle
                              mouse: false,
                              grab: false,
                              pencil: false,
                              highlighter: false,
                              shape: false,
                              eraser: false,
                              selection: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SidebarButton(
                          icon: Icons.cleaning_services_rounded,
                          tooltip: 'Silgi',
                          isSelected: tool.eraser,
                          onPressed: () => _updateTool(
                            (t) => t.copyWith(
                              eraser: true,
                              mouse: false,
                              grab: false,
                              pencil: false,
                              highlighter: false,
                              shape: false,
                              selection: false,
                              magnifier: false,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),
                        _SidebarButton(
                          icon: Icons.category_rounded,
                          tooltip: 'Şekiller',
                          isSelected: tool.shape,
                          onPressed: () => _updateTool(
                            (t) => t.copyWith(
                              shape: true,
                              mouse: false,
                              grab: false,
                              pencil: false,
                              highlighter: false,
                              eraser: false,
                              selection: false,
                              magnifier: false,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Container(
                          height: 1,
                          width: 24,
                          color: scheme.outlineVariant,
                        ),
                        const SizedBox(height: 8),
                        _SidebarButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Görünüm Ayarları',
                          isSelected: _isSettingsOpen,
                          onPressed: () {
                            setState(() {
                              _isSettingsOpen = !_isSettingsOpen;
                            });
                          },
                        ),
                        // 3. Actions
                        if (widget.canUndoNotifier != null)
                          ValueListenableBuilder<bool>(
                            valueListenable: widget.canUndoNotifier!,
                            builder: (context, canUndo, _) => _SidebarButton(
                              icon: Icons.undo_rounded,
                              tooltip: 'Geri Al',
                              isEnabled: canUndo,
                              onPressed: widget.onUndo,
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (widget.canRedoNotifier != null)
                          ValueListenableBuilder<bool>(
                            valueListenable: widget.canRedoNotifier!,
                            builder: (context, canRedo, _) => _SidebarButton(
                              icon: Icons.redo_rounded,
                              tooltip: 'İleri Al',
                              isEnabled: canRedo,
                              onPressed: widget.onRedo,
                            ),
                          ),
                        const SizedBox(height: 8),
                        _SidebarButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Temizle',
                          isDestructive: true,
                          onPressed: widget.onClear,
                        ),
                        const SizedBox(height: 8),
                        if (widget.onSolve != null)
                          _SidebarButton(
                            icon: Icons.smart_toy_rounded,
                            tooltip: 'Çöz',
                            onPressed: widget.onSolve,
                          ),
                      ],
                    ),
                  ),
                ),

                // POP-OUT PANELS (Rendered to the right of the sidebar)
                const SizedBox(width: 12),

                // Pen Settings Pop-out
                if (tool.pencil || tool.highlighter)
                  _PopOutPanel(
                    children: [
                      const Text(
                        'Kalem Ayarları',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Colors
                      Row(
                        children: [
                          _ColorDot(
                            color: Colors.black,
                            selectedColor: tool.color,
                            onTap: () => _updateTool(
                              (t) => t.copyWith(color: Colors.black),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ColorDot(
                            color: Colors.red,
                            selectedColor: tool.color,
                            onTap: () => _updateTool(
                              (t) => t.copyWith(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ColorDot(
                            color: Colors.blue,
                            selectedColor: tool.color,
                            onTap: () => _updateTool(
                              (t) => t.copyWith(color: Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ColorDot(
                            color: Colors.green,
                            selectedColor: tool.color,
                            onTap: () => _updateTool(
                              (t) => t.copyWith(color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Type Toggle
                      Row(
                        children: [
                          _TextButton(
                            label: 'Kalem',
                            isSelected: tool.pencil,
                            onTap: () => _updateTool(
                              (t) =>
                                  t.copyWith(pencil: true, highlighter: false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TextButton(
                            label: 'Fosforlu',
                            isSelected: tool.highlighter,
                            onTap: () => _updateTool(
                              (t) =>
                                  t.copyWith(highlighter: true, pencil: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Width Slider (Simplified)
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 8),
                          Expanded(
                            child: Slider(
                              value: tool.width,
                              min: 0.1,
                              max: 20.0,
                              onChanged: (val) =>
                                  _updateTool((t) => t.copyWith(width: val)),
                            ),
                          ),
                          const Icon(Icons.circle, size: 16),
                        ],
                      ),
                    ],
                  ),

                // Shape Settings Pop-out
                if (tool.shape)
                  _PopOutPanel(
                    children: [
                      const Text(
                        'Şekiller',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ShapeButton(
                            icon: Icons.crop_square_rounded,
                            type: ShapeType.rectangle,
                            currentType: tool.selectedShape,
                            onTap: (type) => _updateTool(
                              (t) => t.copyWith(selectedShape: type),
                            ),
                          ),
                          _ShapeButton(
                            icon: Icons.circle_outlined,
                            type: ShapeType.circle,
                            currentType: tool.selectedShape,
                            onTap: (type) => _updateTool(
                              (t) => t.copyWith(selectedShape: type),
                            ),
                          ),
                          _ShapeButton(
                            icon: Icons.arrow_outward_rounded,
                            type: ShapeType.arrow,
                            currentType: tool.selectedShape,
                            onTap: (type) => _updateTool(
                              (t) => t.copyWith(selectedShape: type),
                            ),
                          ),
                          _ShapeButton(
                            icon: Icons.change_history_rounded,
                            type: ShapeType.triangle,
                            currentType: tool.selectedShape,
                            onTap: (type) => _updateTool(
                              (t) => t.copyWith(selectedShape: type),
                            ),
                          ),
                          _ShapeButton(
                            icon: Icons.star_border_rounded,
                            type: ShapeType.star,
                            currentType: tool.selectedShape,
                            onTap: (type) => _updateTool(
                              (t) => t.copyWith(selectedShape: type),
                            ),
                          ),
                          _ShapeButton(
                            icon: Icons.horizontal_rule_rounded,
                            type: ShapeType.line,
                            currentType: tool.selectedShape,
                            onTap: (type) => _updateTool(
                              (t) => t.copyWith(selectedShape: type),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                // Settings Pop-out
                if (_isSettingsOpen)
                  _PopOutPanel(
                    children: [
                      const Text(
                        'Görünüm',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SidebarButton(
                            icon: Icons.rotate_left_rounded,
                            tooltip: 'Sola Döndür',
                            onPressed: widget.onRotateLeft,
                          ),
                          const SizedBox(width: 8),
                          _SidebarButton(
                            icon: Icons.rotate_right_rounded,
                            tooltip: 'Sağa Döndür',
                            onPressed: widget.onRotateRight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SidebarButton(
                            icon: Icons.first_page_rounded,
                            tooltip: 'İlk Sayfa',
                            onPressed: widget.onFirstPage,
                          ),
                          const SizedBox(width: 8),
                          _SidebarButton(
                            icon: Icons.navigate_before_rounded,
                            tooltip: 'Önceki Sayfa',
                            onPressed: widget.onPreviousPage,
                          ),
                          const SizedBox(width: 8),
                          _SidebarButton(
                            icon: Icons.navigate_next_rounded,
                            tooltip: 'Sonraki Sayfa',
                            onPressed: widget.onNextPage,
                          ),
                          const SizedBox(width: 8),
                          _SidebarButton(
                            icon: Icons.last_page_rounded,
                            tooltip: 'Son Sayfa',
                            onPressed: widget.onLastPage,
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PopOutPanel extends StatelessWidget {
  final List<Widget> children;
  const _PopOutPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 2),
          ),
        ],
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool isEnabled;
  final bool isDestructive;
  final VoidCallback? onPressed;
  final Widget? child;

  const _SidebarButton({
    required this.icon,
    required this.tooltip,
    this.isSelected = false,
    this.isEnabled = true,
    this.isDestructive = false,
    this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isDestructive
        ? scheme.error
        : isSelected
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: isSelected
                ? BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  icon,
                  color: isEnabled ? color : color.withOpacity(0.3),
                  size: 20,
                ),
                if (child != null) Positioned(top: 0, right: 0, child: child!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = color.value == selectedColor.value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: isSelected
            ? const Center(
                child: Icon(Icons.check, size: 14, color: Colors.white),
              )
            : null,
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TextButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? scheme.onPrimary : scheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ShapeButton extends StatelessWidget {
  final IconData icon;
  final ShapeType type;
  final ShapeType currentType;
  final Function(ShapeType) onTap;

  const _ShapeButton({
    required this.icon,
    required this.type,
    required this.currentType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = type == currentType;
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => onTap(type),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
  }
}
