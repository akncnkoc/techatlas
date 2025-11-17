import 'package:flutter/material.dart';
import '../../models/crop_data.dart';

class SolutionDetailDialog extends StatelessWidget {
  final CropItem crop;

  const SolutionDetailDialog({
    super.key,
    required this.crop,
  });

  @override
  Widget build(BuildContext context) {
    final hasSolution = crop.solutionMetadata?.hasSolution ?? false;
    final solutionType = crop.solutionMetadata?.solutionType;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.quiz,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Soru ${crop.questionNumber ?? "?"}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Solution Status
                    _buildStatusCard(context, hasSolution, solutionType),

                    if (hasSolution) ...[
                      const SizedBox(height: 16),

                      // Answer Choice
                      if (crop.solutionMetadata?.answerChoice != null)
                        _buildAnswerCard(
                          context,
                          crop.solutionMetadata!.answerChoice!,
                        ),

                      const SizedBox(height: 16),

                      // Manual Solution
                      if (crop.userSolution?.explanation != null)
                        _buildManualSolutionCard(
                          context,
                          crop.userSolution!,
                        ),

                      // AI Solution
                      if (crop.userSolution?.aiSolution != null ||
                          crop.solutionMetadata?.aiSolution != null)
                        _buildAiSolutionCard(
                          context,
                          crop.userSolution?.aiSolution ??
                              crop.solutionMetadata!.aiSolution!,
                        ),

                      const SizedBox(height: 16),

                      // Solved By
                      _buildSolvedByCard(
                        context,
                        crop.solutionMetadata?.solvedBy ?? [],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Question Details
                    _buildDetailsCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    bool hasSolution,
    String? solutionType,
  ) {
    final color = hasSolution ? Colors.green : Colors.orange;
    final icon = hasSolution ? Icons.check_circle : Icons.pending;
    final statusText = hasSolution ? 'Çözüldü' : 'Çözülmedi';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (solutionType != null)
                  Text(
                    _getSolutionTypeText(solutionType),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(BuildContext context, String answer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  answer,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'Seçilen Cevap',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualSolutionCard(BuildContext context, UserSolution solution) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Manuel Çözüm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              solution.explanation ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            if (solution.drawingFile != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.draw,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Çizim mevcut',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiSolutionCard(BuildContext context, AiSolution aiSolution) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Çözümü',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(aiSolution.confidence)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '%${(aiSolution.confidence * 100).toInt()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getConfidenceColor(aiSolution.confidence),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cevap: ${aiSolution.answer}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    aiSolution.reasoning,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            if (aiSolution.steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Çözüm Adımları:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...aiSolution.steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(step, style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSolvedByCard(BuildContext context, List<String> solvedBy) {
    if (solvedBy.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Çözüm Yöntemi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: solvedBy.map((method) {
                return Chip(
                  label: Text(_getMethodText(method)),
                  avatar: Icon(
                    _getMethodIcon(method),
                    size: 16,
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Soru Detayları',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Sayfa', '${crop.pageNumber}'),
            _buildDetailRow('Sınıf', crop.className),
            _buildDetailRow(
              'Güven',
              '%${(crop.confidence * 100).toInt()}',
            ),
            if (crop.questionNumberDetails != null) ...[
              _buildDetailRow(
                'Soru No',
                crop.questionNumberDetails!.text,
              ),
              _buildDetailRow(
                'OCR Güven',
                '%${(crop.questionNumberDetails!.ocrConfidence * 100).toInt()}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getSolutionTypeText(String type) {
    switch (type) {
      case 'manual':
        return 'Manuel olarak çözüldü';
      case 'ai':
        return 'AI tarafından çözüldü';
      case 'mixed':
        return 'Manuel ve AI ile çözüldü';
      default:
        return type;
    }
  }

  String _getMethodText(String method) {
    switch (method) {
      case 'manual':
        return 'Manuel';
      case 'ai':
        return 'AI';
      case 'drawing':
        return 'Çizim';
      default:
        return method;
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'manual':
        return Icons.edit;
      case 'ai':
        return Icons.psychology;
      case 'drawing':
        return Icons.draw;
      default:
        return Icons.help;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
