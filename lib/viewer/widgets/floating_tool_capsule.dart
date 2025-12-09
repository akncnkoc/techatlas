import 'package:flutter/material.dart';

import '../tool_state.dart';
import '../drawing_provider.dart';

class FloatingToolCapsule extends StatefulWidget {
  final ValueNotifier<ToolState> toolNotifier;
  final DrawingProvider drawingProvider;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onClear;
  final ValueNotifier<bool>? canUndoNotifier;
  final ValueNotifier<bool>? canRedoNotifier;
  final VoidCallback? onSolve;
  const FloatingToolCapsule({
    super.key,
    required this.toolNotifier,
    required this.drawingProvider,
    this.onUndo,
    this.onRedo,
    this.onClear,
    this.canUndoNotifier,
    this.canRedoNotifier,
    this.onSolve,
  });

  @override
  State<FloatingToolCapsule> createState() => _FloatingToolCapsuleState();
}

class _FloatingToolCapsuleState extends State<FloatingToolCapsule> {
  // Helper to update tool
  void _updateTool(ToolState Function(ToolState) updater) {
    widget.drawingProvider.setTool(updater);
    widget.toolNotifier.value = updater(widget.toolNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<ToolState>(
      valueListenable: widget.toolNotifier,
      builder: (context, tool, child) {
        return Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 32),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Pointer / Pan
                _CapsuleButton(
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
                const SizedBox(width: 8),

                // 2. Drawing Tools Group
                _CapsuleButton(
                  icon: Icons.edit_rounded,
                  tooltip: 'Çizim',
                  isSelected: tool.pencil || tool.highlighter,
                  onPressed: () {
                    if (tool.pencil) {
                      // Toggle highlighter if already pencil
                      _updateTool(
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
                      );
                    } else {
                      // Default to pencil
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
                  // Show color indicator if selected
                  child: (tool.pencil || tool.highlighter)
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tool.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        )
                      : null,
                ),

                // Expanded Drawing Options (Color/Width) - Only when drawing
                if (tool.pencil || tool.highlighter) ...[
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: scheme.outlineVariant),
                  const SizedBox(width: 8),
                  // Color Palette (Simplified)
                  _ColorDot(
                    color: Colors.black,
                    selectedColor: tool.color,
                    onTap: () =>
                        _updateTool((t) => t.copyWith(color: Colors.black)),
                  ),
                  const SizedBox(width: 4),
                  _ColorDot(
                    color: Colors.red,
                    selectedColor: tool.color,
                    onTap: () =>
                        _updateTool((t) => t.copyWith(color: Colors.red)),
                  ),
                  const SizedBox(width: 4),
                  _ColorDot(
                    color: Colors.blue,
                    selectedColor: tool.color,
                    onTap: () =>
                        _updateTool((t) => t.copyWith(color: Colors.blue)),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 24, color: scheme.outlineVariant),
                  const SizedBox(width: 8),
                ],

                const SizedBox(width: 8),

                // 3. Eraser
                _CapsuleButton(
                  icon: Icons.cleaning_services_rounded, // Better eraser icon
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

                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: scheme.outlineVariant),
                const SizedBox(width: 16),

                // 4. Actions Group
                if (widget.onSolve != null)
                  _CapsuleButton(
                    icon: Icons.smart_toy_rounded,
                    tooltip: 'Çöz',
                    onPressed: widget.onSolve,
                  ),

                if (widget.canUndoNotifier != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.canUndoNotifier!,
                    builder: (context, canUndo, _) => _CapsuleButton(
                      icon: Icons.undo_rounded,
                      tooltip: 'Geri Al',
                      isEnabled: canUndo,
                      onPressed: widget.onUndo,
                    ),
                  ),

                if (widget.canRedoNotifier != null)
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.canRedoNotifier!,
                    builder: (context, canRedo, _) => _CapsuleButton(
                      icon: Icons.redo_rounded,
                      tooltip: 'İleri Al',
                      isEnabled: canRedo,
                      onPressed: widget.onRedo,
                    ),
                  ),

                _CapsuleButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Temizle',
                  isDestructive: true,
                  onPressed: widget.onClear,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool isEnabled;
  final bool isDestructive;
  final VoidCallback? onPressed;
  final Widget? child;

  const _CapsuleButton({
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
            padding: const EdgeInsets.all(8),
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
                  color: isEnabled ? color : color.withValues(alpha: 0.3),
                  size: 24,
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
    final isSelected = color.toARGB32() == selectedColor.toARGB32();
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
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
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
