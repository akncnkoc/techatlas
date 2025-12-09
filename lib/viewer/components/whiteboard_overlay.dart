import 'package:flutter/material.dart';

class WhiteboardOverlay extends StatefulWidget {
  final Rect selectedArea;
  final VoidCallback onClose;

  const WhiteboardOverlay({
    super.key,
    required this.selectedArea,
    required this.onClose,
  });

  @override
  State<WhiteboardOverlay> createState() => _WhiteboardOverlayState();
}

class _WhiteboardOverlayState extends State<WhiteboardOverlay> {
  final List<List<Offset>> _strokes = [];
  final List<List<Offset>> _redoStack = [];
  List<Offset>? _currentStroke;

  // Drawing state
  Color _color = Colors.black;
  double _strokeWidth = 2.0;
  bool _isEraser = false;

  @override
  Widget build(BuildContext context) {
    // Position to the right of the selected area
    // We add some padding (e.g. 20px)
    final left = widget.selectedArea.right + 20;
    final top = widget.selectedArea.top;

    // Size matches the selected area height, but width is fixed or flexible?
    // User said "secilen alan kadar" (as much as selected area).
    // Let's make it same size as selected area for now.
    final width = widget.selectedArea.width;
    final height = widget.selectedArea.height;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            // Toolbar
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildToolButton(Icons.edit, false),
                  _buildToolButton(Icons.cleaning_services, true), // Eraser
                  IconButton(
                    icon: const Icon(Icons.undo, size: 20),
                    onPressed: _strokes.isNotEmpty ? _undo : null,
                    tooltip: 'Geri Al',
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.red,
                    ),
                    onPressed: _clear,
                    tooltip: 'Temizle',
                  ),
                  const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: widget.onClose,
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            // Canvas
            Expanded(
              child: ClipRect(
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _WhiteboardPainter(
                      strokes: _strokes,
                      currentStroke: _currentStroke,
                      color: _color,
                      strokeWidth: _strokeWidth,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(IconData icon, bool isEraser) {
    final isSelected = _isEraser == isEraser;
    return IconButton(
      icon: Icon(icon, size: 20),
      color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700,
      onPressed: () {
        setState(() {
          _isEraser = isEraser;
        });
      },
    );
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke?.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke != null) {
      setState(() {
        _strokes.add(List.from(_currentStroke!));
        _currentStroke = null;
        _redoStack.clear();
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _redoStack.add(_strokes.removeLast());
      });
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _redoStack.clear();
    });
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? currentStroke;
  final Color color;
  final double strokeWidth;

  _WhiteboardPainter({
    required this.strokes,
    this.currentStroke,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentStroke != null && currentStroke!.length > 1) {
      final path = Path();
      path.moveTo(currentStroke!.first.dx, currentStroke!.first.dy);
      for (int i = 1; i < currentStroke!.length; i++) {
        path.lineTo(currentStroke![i].dx, currentStroke![i].dy);
      }
      canvas.drawPath(path, paint..color = Colors.blue);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) {
    return true;
  }
}
