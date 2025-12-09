import 'package:flutter/material.dart';

/// Metin ekleme modu - Ekrana metin etiketleri ekler
class TextMode extends StatefulWidget {
  final VoidCallback? onClose;

  const TextMode({super.key, this.onClose});

  @override
  State<TextMode> createState() => _TextModeState();
}

class _TextModeState extends State<TextMode> {
  final List<TextItem> _textItems = [];
  Color _selectedColor = Colors.black;
  double _fontSize = 24.0;
  FontWeight _fontWeight = FontWeight.normal;
  bool _isItalic = false;

  // Renk paleti
  static const List<Color> _colors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.cyan,
  ];

  // Font boyutları
  static const List<double> _fontSizes = [12, 16, 20, 24, 32, 48, 64];

  void _addText(Offset position) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Metin Ekle'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Metninizi yazın...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                setState(() {
                  _textItems.add(
                    TextItem(
                      text: textController.text,
                      position: position,
                      color: _selectedColor,
                      fontSize: _fontSize,
                      fontWeight: _fontWeight,
                      isItalic: _isItalic,
                    ),
                  );
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Metin öğelerini göster
        ...List.generate(_textItems.length, (index) {
          final item = _textItems[index];
          return Positioned(
            left: item.position.dx,
            top: item.position.dy,
            child: Draggable(
              feedback: Opacity(
                opacity: 0.7,
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    item.text,
                    style: TextStyle(
                      color: item.color,
                      fontSize: item.fontSize,
                      fontWeight: item.fontWeight,
                      fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  _textItems[index] = TextItem(
                    text: item.text,
                    position: details.offset,
                    color: item.color,
                    fontSize: item.fontSize,
                    fontWeight: item.fontWeight,
                    isItalic: item.isItalic,
                  );
                });
              },
              child: GestureDetector(
                onLongPress: () {
                  // Uzun basınca sil
                  setState(() {
                    _textItems.removeAt(index);
                  });
                },
                child: Text(
                  item.text,
                  style: TextStyle(
                    color: item.color,
                    fontSize: item.fontSize,
                    fontWeight: item.fontWeight,
                    fontStyle: item.isItalic ? FontStyle.italic : FontStyle.normal,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        // Tıklama alanı (metin eklemek için)
        Positioned.fill(
          child: GestureDetector(
            onTapUp: (details) {
              _addText(details.localPosition);
            },
            behavior: HitTestBehavior.translucent,
          ),
        ),

        // Kontrol paneli (sağ üst)
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Metin Araçları',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),

                // Renk seçimi
                const Text('Renk', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _colors.map((color) {
                    final isSelected = color == _selectedColor;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Font boyutu
                const Text('Boyut', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _fontSizes.map((size) {
                    final isSelected = size == _fontSize;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _fontSize = size;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${size.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Stil seçenekleri
                const Text('Stil', style: TextStyle(fontSize: 10)),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kalın
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _fontWeight = _fontWeight == FontWeight.bold
                              ? FontWeight.normal
                              : FontWeight.bold;
                        });
                      },
                      icon: const Icon(Icons.format_bold),
                      style: IconButton.styleFrom(
                        backgroundColor: _fontWeight == FontWeight.bold
                            ? Colors.blue
                            : Colors.grey.shade200,
                        foregroundColor: _fontWeight == FontWeight.bold
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // İtalik
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isItalic = !_isItalic;
                        });
                      },
                      icon: const Icon(Icons.format_italic),
                      style: IconButton.styleFrom(
                        backgroundColor: _isItalic
                            ? Colors.blue
                            : Colors.grey.shade200,
                        foregroundColor: _isItalic
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Temizle butonu
                ElevatedButton.icon(
                  onPressed: _textItems.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _textItems.clear();
                          });
                        },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Hepsini Sil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                // Kapat butonu
                ElevatedButton.icon(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Modu Kapat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bilgi mesajı (sol alt)
        Positioned(
          left: 20,
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '💡 İpuçları:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '• Ekrana tıklayarak metin ekleyin',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                Text(
                  '• Metni sürükleyerek taşıyın',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                Text(
                  '• Uzun basarak silin',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Metin öğesi
class TextItem {
  final String text;
  final Offset position;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final bool isItalic;

  TextItem({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    required this.isItalic,
  });
}
