import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Color(0xFF5B4CE6)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Yeni Güncelleme: ${widget.updateInfo.version}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TechAtlas için yeni bir sürüm mevcut.'),
            const SizedBox(height: 16),
            const Text(
              'Yenilikler:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F9),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Text(widget.updateInfo.releaseNotes),
              ),
            ),
            if (_isUpdating) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Center(child: Text('İndiriliyor ve Başlatılıyor...')),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isUpdating) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Daha Sonra'),
          ),
          FilledButton.icon(
            onPressed: () async {
              setState(() {
                _isUpdating = true;
              });

              try {
                final updateService = UpdateService();
                await updateService.performUpdate(
                  widget.updateInfo.downloadUrl,
                );
                // App should exit, but if not:
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isUpdating = false;
                  });
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Güncelle'),
          ),
        ],
      ],
    );
  }
}
