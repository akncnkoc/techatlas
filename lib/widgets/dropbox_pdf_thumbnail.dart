import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../dropbox/dropbox_service.dart';

class DropboxPdfThumbnail extends StatefulWidget {
  final String pdfPath;
  final DropboxService dropboxService;
  
  const DropboxPdfThumbnail({
    super.key,
    required this.pdfPath,
    required this.dropboxService,
  });

  @override
  State<DropboxPdfThumbnail> createState() => _DropboxPdfThumbnailState();
}

class _DropboxPdfThumbnailState extends State<DropboxPdfThumbnail> {
  Uint8List? imageBytes;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final thumbnail = await widget.dropboxService.getThumbnail(widget.pdfPath);
      if (mounted) {
        setState(() {
          imageBytes = thumbnail;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    if (imageBytes == null) {
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(Icons.picture_as_pdf, size: 48, color: Colors.grey),
        ),
      );
    }
    
    return Image.memory(imageBytes!, fit: BoxFit.cover);
  }
}