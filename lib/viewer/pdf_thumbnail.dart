import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfThumbnail extends StatefulWidget {
  final PdfController controller;
  final int pageNumber;
  final bool isCurrentPage;
  final VoidCallback onTap;

  const PdfThumbnail({
    super.key,
    required this.controller,
    required this.pageNumber,
    required this.isCurrentPage,
    required this.onTap,
  });

  @override
  State<PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<PdfThumbnail> {
  PdfPageImage? _cachedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (_cachedImage != null || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final document = await widget.controller.document;
      final page = await document.getPage(widget.pageNumber);
      final image = await page.render(
        width: page.width * 0.3,
        height: page.height * 0.3,
      );

      if (mounted) {
        setState(() {
          _cachedImage = image;
          _isLoading = false;
        });
      }

      await page.close();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(
            color: widget.isCurrentPage
                ? colorScheme.primary
                : colorScheme.inversePrimary,
            width: widget.isCurrentPage ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: widget.isCurrentPage
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                  child: _cachedImage != null
                      ? Image.memory(_cachedImage!.bytes, fit: BoxFit.cover)
                      : Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              colorScheme.primary,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: widget.isCurrentPage
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(11),
                  bottomRight: Radius.circular(11),
                ),
              ),
              child: Center(
                child: Text(
                  '${widget.pageNumber}',
                  style: TextStyle(
                    color: widget.isCurrentPage
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
