import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import '../../models/crop_data.dart';

class AnimationPlayerWidget extends StatefulWidget {
  final String animationDataPath;
  final String baseDirectory;
  final String? zipFilePath;

  const AnimationPlayerWidget({
    super.key,
    required this.animationDataPath,
    required this.baseDirectory,
    this.zipFilePath,
  });

  @override
  State<AnimationPlayerWidget> createState() => AnimationPlayerWidgetState();
}

class AnimationPlayerWidgetState extends State<AnimationPlayerWidget> {
  AnimationData? _animationData;
  bool _isLoading = true;
  String? _error;
  int _currentStep = -1; // -1 = boş canvas, 0 = ilk adım

  @override
  void initState() {
    super.initState();
    _loadAnimationData();
  }

  Future<void> _loadAnimationData() async {
    try {
      String jsonString;

      // Try to load from zip archive first
      if (widget.zipFilePath != null) {
        print('🎬 Loading animation from ZIP: ${widget.zipFilePath}');
        print('📄 Animation path in ZIP: ${widget.animationDataPath}');

        final zipFile = File(widget.zipFilePath!);
        if (!await zipFile.exists()) {
          setState(() {
            _error = 'Zip file not found: ${widget.zipFilePath}';
            _isLoading = false;
          });
          return;
        }

        final zipBytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(zipBytes);

        // Find the animation data file in the archive
        ArchiveFile? animationFile;
        for (final file in archive) {
          if (file.isFile && file.name == widget.animationDataPath) {
            animationFile = file;
            break;
          }
        }

        if (animationFile == null) {
          print('❌ Animation file not found in ZIP');
          print('📦 Files in ZIP:');
          for (final file in archive) {
            if (file.isFile) {
              print('   - ${file.name}');
            }
          }
          setState(() {
            _error = 'Animation data file not found in archive: ${widget.animationDataPath}';
            _isLoading = false;
          });
          return;
        }

        print('✅ Animation file found in ZIP, loading...');
        final content = animationFile.content as Uint8List;
        jsonString = utf8.decode(content);
      } else {
        // Fallback to file system
        final filePath = '${widget.baseDirectory}/${widget.animationDataPath}';
        print('🎬 Loading animation from file system: $filePath');

        final file = File(filePath);
        if (!await file.exists()) {
          setState(() {
            _error = 'Animation data file not found: $filePath';
            _isLoading = false;
          });
          return;
        }

        jsonString = await file.readAsString();
      }

      final animationData = AnimationData.fromJsonString(jsonString);

      setState(() {
        _animationData = animationData;
        _isLoading = false;
      });

      // Otomatik oynatma kapalı - kullanıcı butonlarla kontrol edecek
    } catch (e) {
      setState(() {
        _error = 'Error loading animation: $e';
        _isLoading = false;
      });
    }
  }

  void resetAnimation() {
    setState(() {
      _currentStep = -1; // Boş canvas
    });
  }

  void nextStep() {
    if (_animationData == null) return;
    if (_currentStep < _animationData!.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void previousStep() {
    if (_currentStep > -1) { // -1'e kadar geri gidebilir
      setState(() {
        _currentStep--;
      });
    }
  }

  void goToLastStep() {
    if (_animationData == null) return;
    setState(() {
      _currentStep = _animationData!.steps.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_animationData == null) {
      return const Center(
        child: Text('No animation data available'),
      );
    }

    final canvasWidth = _animationData!.metadata.canvasSize.width;
    final canvasHeight = _animationData!.metadata.canvasSize.height;
    final aspectRatio = canvasWidth / canvasHeight;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CustomPaint(
            painter: AnimationPainter(
              animationData: _animationData!,
              currentStep: _currentStep,
            ),
            size: Size(canvasWidth, canvasHeight),
          ),
        ),
      ),
    );
  }
}

class AnimationPainter extends CustomPainter {
  final AnimationData animationData;
  final int currentStep;

  AnimationPainter({
    required this.animationData,
    required this.currentStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final canvasWidth = animationData.metadata.canvasSize.width;
    final canvasHeight = animationData.metadata.canvasSize.height;

    // Scale factor to fit the canvas
    final scaleX = size.width / canvasWidth;
    final scaleY = size.height / canvasHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    canvas.save();
    canvas.scale(scale);

    // If currentStep is -1, show empty canvas
    if (currentStep >= 0) {
      // Draw all steps up to current step (inclusive)
      for (int i = 0; i <= currentStep && i < animationData.steps.length; i++) {
        final step = animationData.steps[i];

        // Draw lines
        for (final line in step.lines) {
          _drawLine(canvas, line);
        }

        // Draw rectangles
        for (final rect in step.rectangles) {
          _drawRectangle(canvas, rect);
        }

        // Draw circles
        for (final circle in step.circles) {
          _drawCircle(canvas, circle);
        }

        // Draw texts
        for (final text in step.texts) {
          _drawText(canvas, text);
        }
      }
    }

    canvas.restore();
  }

  void _drawLine(Canvas canvas, DrawingLine line) {
    if (line.points.length < 4) return;

    final paint = Paint()
      ..color = line.color
      ..strokeWidth = line.lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(line.points[0], line.points[1]);

    for (int i = 1; i * 2 + 1 < line.points.length; i++) {
      path.lineTo(line.points[i * 2], line.points[i * 2 + 1]);
    }

    canvas.drawPath(path, paint);
  }

  void _drawRectangle(Canvas canvas, DrawingRectangle rect) {
    final paint = Paint()
      ..color = rect.color
      ..strokeWidth = rect.lineWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height),
      paint,
    );
  }

  void _drawCircle(Canvas canvas, DrawingCircle circle) {
    final paint = Paint()
      ..color = circle.color
      ..strokeWidth = circle.lineWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(
      Offset(circle.x, circle.y),
      circle.radius,
      paint,
    );
  }

  void _drawText(Canvas canvas, DrawingText text) {
    final textSpan = TextSpan(
      text: text.text,
      style: TextStyle(
        color: text.color,
        fontSize: text.fontSize,
        fontFamily: text.fontFamily,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset(text.x, text.y));
  }

  @override
  bool shouldRepaint(AnimationPainter oldDelegate) {
    return oldDelegate.currentStep != currentStep;
  }
}
