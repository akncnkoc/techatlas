import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:archive/archive.dart';
import 'package:techatlas/models/crop_data.dart';

import 'package:techatlas/viewer/widgets/solution_detail_dialog.dart';

class SolutionPanel extends StatefulWidget {
  final CropItem crop;
  final String? zipFilePath;
  final Uint8List? zipBytes;

  const SolutionPanel({
    super.key,
    required this.crop,
    this.zipFilePath,
    this.zipBytes,
  });

  @override
  State<SolutionPanel> createState() => _SolutionPanelState();
}

class _SolutionPanelState extends State<SolutionPanel> {
  bool _isAnswerExpanded = true; // Default to expanded in the panel view

  @override
  void dispose() {
    super.dispose();
  }

  Future<Uint8List?> _loadDrawingImage(String drawingPath) async {
    if (widget.zipFilePath == null) return null;

    try {
      final zipBytes = await File(widget.zipFilePath!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      Uint8List? imageBytes;
      for (final file in archive) {
        if (file.isFile && file.name == drawingPath) {
          imageBytes = file.content as Uint8List;
          break;
        }
      }

      if (imageBytes == null) return null;

      final cropHeight = widget.crop.coordinates.height;

      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      final croppedImage = img.copyCrop(
        image,
        x: 0,
        y: cropHeight.toInt(), // Start from the end of question
        width: image.width,
        height: (image.height - cropHeight)
            .toInt(), // Remaining height (solution part)
      );

      // Encode back to PNG
      return Uint8List.fromList(img.encodePng(croppedImage));
    } catch (e) {
      print('Error loading/cropping drawing: $e');
    }
    return null;
  }

  void _showManualSolutionImage(String drawingFileName) async {
    final imageBytes = await _loadDrawingImage(drawingFileName);

    if (imageBytes == null || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.draw,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Manuel Çözüm Çizimi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Image
              Flexible(
                child: SingleChildScrollView(
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Widget _buildSolutionToggleButton({bool rotate = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.8),
            scheme.primaryContainer.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: RotatedBox(
        quarterTurns: !rotate ? 0 : 3,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _isAnswerExpanded = !_isAnswerExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withValues(alpha: 0.2),
                          scheme.primary.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      rotate
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    rotate ? 'Çözümü Göster' : 'Çözümü Gizle',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crop = widget.crop;

    // Check if there's any actual solution data
    final hasAnswerChoice =
        (crop.solutionMetadata?.answerChoice != null ||
        crop.userSolution?.answerChoice != null);
    final hasExplanation =
        (crop.solutionMetadata?.explanation != null &&
            crop.solutionMetadata!.explanation!.trim().isNotEmpty) ||
        (crop.userSolution?.explanation != null &&
            crop.userSolution!.explanation!.trim().isNotEmpty);
    final hasDrawing =
        (crop.solutionMetadata?.drawingFile != null &&
            crop.solutionMetadata!.drawingFile!.trim().isNotEmpty) ||
        (crop.userSolution?.drawingFile != null &&
            crop.userSolution!.drawingFile!.trim().isNotEmpty);
    final hasSolutionImages =
        (crop.solutionMetadata?.solutionImages != null &&
        crop.solutionMetadata!.solutionImages.isNotEmpty);
    final hasAiSolution =
        crop.solutionMetadata?.aiSolution != null ||
        crop.userSolution?.aiSolution != null;

    final hasSolution =
        hasAnswerChoice ||
        hasExplanation ||
        hasDrawing ||
        hasSolutionImages ||
        hasAiSolution;

    if (!hasSolution) {
      return const Center(
        child: Text('Çözüm bulunamadı', style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Solution Content
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [_buildSolutionToggleButton(rotate: false)],
                  ),
                  const SizedBox(height: 12),
                  if (_isAnswerExpanded) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Çözüm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Answer choice (large)
                    if (crop.solutionMetadata?.answerChoice != null ||
                        crop.userSolution?.answerChoice != null) ...[
                      Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              crop.solutionMetadata?.answerChoice ??
                                  crop.userSolution?.answerChoice ??
                                  '',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Manual Solution
                    if (hasExplanation || hasDrawing) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Manuel Çözüm',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (hasExplanation) ...[
                              const SizedBox(height: 8),
                              Text(
                                crop.userSolution?.explanation?.trim() ??
                                    crop.solutionMetadata?.explanation
                                        ?.trim() ??
                                    '',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            if (hasDrawing) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _showManualSolutionImage(
                                  crop.userSolution?.drawingFile ??
                                      crop.solutionMetadata?.drawingFile ??
                                      '',
                                ),
                                icon: const Icon(Icons.image, size: 18),
                                label: const Text('Çizimi Görüntüle'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // AI Solution
                    if (hasAiSolution) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'AI Çözümü',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getConfidenceColor(
                                      (crop.userSolution?.aiSolution ??
                                              crop
                                                  .solutionMetadata!
                                                  .aiSolution!)
                                          .confidence,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '%${((crop.userSolution?.aiSolution ?? crop.solutionMetadata!.aiSolution!).confidence * 100).toInt()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _getConfidenceColor(
                                        (crop.userSolution?.aiSolution ??
                                                crop
                                                    .solutionMetadata!
                                                    .aiSolution!)
                                            .confidence,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              (crop.userSolution?.aiSolution ??
                                      crop.solutionMetadata!.aiSolution!)
                                  .reasoning,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if ((crop.userSolution?.aiSolution ??
                                        crop.solutionMetadata!.aiSolution!)
                                    .steps
                                    .isNotEmpty &&
                                (crop.userSolution?.aiSolution ??
                                        crop.solutionMetadata!.aiSolution!)
                                    .steps
                                    .first
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Adımlar:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...(crop.userSolution?.aiSolution ??
                                      crop.solutionMetadata!.aiSolution!)
                                  .steps
                                  .map(
                                    (step) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '• ',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          Expanded(
                                            child: Text(
                                              step,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Detailed Solution Button
                    if (crop.userSolution?.hasAnimationData == true ||
                        crop.userSolution?.drawingDataFile != null ||
                        hasSolutionImages) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            final zipDir = widget.zipFilePath != null
                                ? File(widget.zipFilePath!).parent.path
                                : '';
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => SolutionDetailDialog(
                                crop: crop,
                                baseDirectory: zipDir,
                                zipFilePath: widget.zipFilePath,
                                zipBytes: widget.zipBytes,
                              ),
                            );
                          },
                          icon: Icon(
                            (crop.userSolution?.hasAnimationData == true ||
                                    crop.userSolution?.drawingDataFile != null)
                                ? Icons.play_circle_outline
                                : Icons.photo_library,
                            size: 18,
                          ),
                          label: Text(
                            (crop.userSolution?.hasAnimationData == true ||
                                    crop.userSolution?.drawingDataFile != null)
                                ? 'Animasyonlu Çözümü İzle'
                                : 'Çözüm Resimlerini Göster',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onTertiary,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
