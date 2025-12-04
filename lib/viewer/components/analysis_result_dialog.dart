import 'package:flutter/material.dart';
import '../../soru_cozucu_service.dart';
import 'draggable_resizable_dialog.dart';

class AnalysisResultDialog extends StatelessWidget {
  final AnalysisResult result;

  const AnalysisResultDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return DraggableResizableDialog(
      initialWidth: 700,
      initialHeight: (screenSize.height * 0.7).clamp(500.0, 800.0),
      minWidth: 500,
      minHeight: 400,
      child: Column(
        children: [
          // Header - Draggable
          _buildHeader(context),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cevaplı görsel varsa göster
                  if (result.resultImage != null) ...[
                    _buildResultImage(context),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                  ],

                  // Soru detayları
                  const Text(
                    '📝 Soru Detayları',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  ...result.sorular.asMap().entries.map((entry) {
                    return _buildQuestionCard(context, entry.value);
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return DraggableDialogHeader(
      onClose: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${result.soruSayisi} Soru Bulundu',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Drag indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Taşı',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultImage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📸 Cevaplı Görsel',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        // Resmi sınırlı boyutta göster
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: 600, // Maksimum yükseklik
            maxWidth: double.infinity,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(result.resultImage!, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(BuildContext context, Soru soru) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Soru başlığı
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Soru ${soru.soruNo}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Soru metni
              Text(
                soru.metin,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 10),

              // Cevap
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.shade50,
                      Colors.green.shade100.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cevap: ${soru.dogruSecenek}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Açıklama
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        soru.aciklama,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
