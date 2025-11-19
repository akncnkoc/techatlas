import 'dart:convert';
import 'dart:ui' show Size, Color;

class CropCoordinates {
  final int x1;
  final int y1;
  final int x2;
  final int y2;
  final int width;
  final int height;

  CropCoordinates({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.width,
    required this.height,
  });

  // Convenience getters for top-left corner coordinates
  int get x => x1;
  int get y => y1;

  factory CropCoordinates.fromJson(Map<String, dynamic> json) {
    // Destek 1: Yeni format -> { coordinates: { absolute: { x1, y1, ... } } }
    if (json.containsKey('absolute') && json['absolute'] is Map<String, dynamic>) {
      final abs = json['absolute'] as Map<String, dynamic>;
      return CropCoordinates(
        x1: (abs['x1'] as num?)?.toInt() ?? 0,
        y1: (abs['y1'] as num?)?.toInt() ?? 0,
        x2: (abs['x2'] as num?)?.toInt() ?? 0,
        y2: (abs['y2'] as num?)?.toInt() ?? 0,
        width: (abs['width'] as num?)?.toInt() ?? 0,
        height: (abs['height'] as num?)?.toInt() ?? 0,
      );
    }

    // Destek 2: Eski format -> { coordinates: { x1, y1, x2, y2, width, height } }
    return CropCoordinates(
      x1: (json['x1'] as num?)?.toInt() ?? 0,
      y1: (json['y1'] as num?)?.toInt() ?? 0,
      x2: (json['x2'] as num?)?.toInt() ?? 0,
      y2: (json['y2'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuestionNumberLocation {
  final int x;
  final int y;
  final int width;
  final int height;

  QuestionNumberLocation({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory QuestionNumberLocation.fromJson(Map<String, dynamic> json) {
    return QuestionNumberLocation(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuestionNumberDetails {
  final String text;
  final double ocrConfidence;
  final QuestionNumberLocation? location;

  QuestionNumberDetails({
    required this.text,
    required this.ocrConfidence,
    this.location,
  });

  factory QuestionNumberDetails.fromJson(Map<String, dynamic> json) {
    return QuestionNumberDetails(
      text: json['text']?.toString() ?? '',
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble() ?? 0.0,
      location: json['location_in_page'] != null
          ? QuestionNumberLocation.fromJson(
              json['location_in_page'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class PageDimensions {
  final int width;
  final int height;

  PageDimensions({
    required this.width,
    required this.height,
  });

  factory PageDimensions.fromJson(Map<String, dynamic> json) {
    return PageDimensions(
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

class AiSolution {
  final String answer;
  final String reasoning;
  final double confidence;
  final List<String> steps;

  AiSolution({
    required this.answer,
    required this.reasoning,
    required this.confidence,
    required this.steps,
  });

  factory AiSolution.fromJson(Map<String, dynamic> json) {
    return AiSolution(
      answer: json['answer']?.toString() ?? '',
      reasoning: json['reasoning']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      steps: (json['steps'] as List?)
              ?.map((step) => step.toString())
              .toList() ??
          [],
    );
  }
}

class UserSolution {
  final String? answerChoice;
  final String? explanation;
  final String? drawingFile;
  final AiSolution? aiSolution;
  final String? drawingDataFile;
  final bool hasAnimationData;
  final int stepsCount;

  UserSolution({
    this.answerChoice,
    this.explanation,
    this.drawingFile,
    this.aiSolution,
    this.drawingDataFile,
    this.hasAnimationData = false,
    this.stepsCount = 0,
  });

  factory UserSolution.fromJson(Map<String, dynamic> json) {
    return UserSolution(
      answerChoice: json['answer_choice']?.toString(),
      explanation: json['explanation']?.toString(),
      drawingFile: json['drawing_file']?.toString(),
      aiSolution: json['ai_solution'] != null
          ? AiSolution.fromJson(json['ai_solution'] as Map<String, dynamic>)
          : null,
      drawingDataFile: json['drawing_data_file']?.toString(),
      hasAnimationData: json['has_animation_data'] as bool? ?? false,
      stepsCount: (json['steps_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SolutionMetadata {
  final bool hasSolution;
  final String? solutionType;
  final String? answerChoice;
  final String? explanation;
  final String? drawingFile;
  final AiSolution? aiSolution;
  final List<String> solvedBy;

  SolutionMetadata({
    required this.hasSolution,
    this.solutionType,
    this.answerChoice,
    this.explanation,
    this.drawingFile,
    this.aiSolution,
    required this.solvedBy,
  });

  factory SolutionMetadata.fromJson(Map<String, dynamic> json) {
    return SolutionMetadata(
      hasSolution: json['has_solution'] as bool? ?? false,
      solutionType: json['solution_type']?.toString(),
      answerChoice: json['answer_choice']?.toString(),
      explanation: json['explanation']?.toString(),
      drawingFile: json['drawing_file']?.toString(),
      aiSolution: json['ai_solution'] != null
          ? AiSolution.fromJson(json['ai_solution'] as Map<String, dynamic>)
          : null,
      solvedBy: (json['solved_by'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          [],
    );
  }
}

class CropItem {
  final String imageFile;
  final String? cropUrl;
  final int pageNumber;
  final int? questionNumber;
  final String className;
  final double confidence;
  final CropCoordinates coordinates;
  final QuestionNumberDetails? questionNumberDetails;
  final PageDimensions? pageDimensions;
  final UserSolution? userSolution;
  final SolutionMetadata? solutionMetadata;

  CropItem({
    required this.imageFile,
    this.cropUrl,
    required this.pageNumber,
    this.questionNumber,
    required this.className,
    required this.confidence,
    required this.coordinates,
    this.questionNumberDetails,
    this.pageDimensions,
    this.userSolution,
    this.solutionMetadata,
  });

  factory CropItem.fromJson(Map<String, dynamic> json) {
    return CropItem(
      imageFile: json['image_file']?.toString() ?? '',
      cropUrl: json['crop_url']?.toString(),
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 0,
      questionNumber: (json['question_number'] as num?)?.toInt(),
      className: json['class']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      coordinates: CropCoordinates.fromJson(
        json['coordinates'] as Map<String, dynamic>? ?? {},
      ),
      questionNumberDetails: json['question_number_details'] != null
          ? QuestionNumberDetails.fromJson(
              json['question_number_details'] as Map<String, dynamic>,
            )
          : null,
      pageDimensions: json['page_dimensions'] != null
          ? PageDimensions.fromJson(
              json['page_dimensions'] as Map<String, dynamic>,
            )
          : null,
      userSolution: json['user_solution'] != null
          ? UserSolution.fromJson(
              json['user_solution'] as Map<String, dynamic>,
            )
          : null,
      solutionMetadata: json['solution_metadata'] != null
          ? SolutionMetadata.fromJson(
              json['solution_metadata'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class CropData {
  final String pdfFile;
  final int totalPages;
  final int totalDetected;
  final List<CropItem> objects;

  CropData({
    required this.pdfFile,
    required this.totalPages,
    required this.totalDetected,
    required this.objects,
  });

  factory CropData.fromJson(Map<String, dynamic> json) {
    return CropData(
      pdfFile: json['pdf_file']?.toString() ?? '',
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
      totalDetected: (json['total_detected'] as num?)?.toInt() ?? 0,
      objects: (json['objects'] as List?)
              ?.map((obj) => CropItem.fromJson(obj as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory CropData.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return CropData.fromJson(json);
  }

  /// Belirli bir sayfa numarası için crop'ları getir
  List<CropItem> getCropsForPage(int pageNumber) {
    return objects.where((crop) => crop.pageNumber == pageNumber).toList();
  }

  /// Crop koordinatlarının referans boyutunu hesapla
  /// Her sayfa için ayrı ayrı max değerleri bulur
  Size getReferenceSizeForPage(int pageNumber) {
    final pageCrops = getCropsForPage(pageNumber);
    if (pageCrops.isEmpty) return Size.zero;

    // Öncelik: Yeni şema ile gelen page_dimensions
    final withDims = pageCrops.firstWhere(
      (c) => c.pageDimensions != null &&
          c.pageDimensions!.width > 0 &&
          c.pageDimensions!.height > 0,
      orElse: () => pageCrops.first,
    );

    if (withDims.pageDimensions != null &&
        withDims.pageDimensions!.width > 0 &&
        withDims.pageDimensions!.height > 0) {
      return Size(
        withDims.pageDimensions!.width.toDouble(),
        withDims.pageDimensions!.height.toDouble(),
      );
    }

    double maxX = 0;
    double maxY = 0;

    for (final crop in pageCrops) {
      if (crop.coordinates.x2 > maxX) maxX = crop.coordinates.x2.toDouble();
      if (crop.coordinates.y2 > maxY) maxY = crop.coordinates.y2.toDouble();
    }

    return Size(maxX, maxY);
  }
}

// Animation Data Models
class CanvasSize {
  final double width;
  final double height;

  CanvasSize({
    required this.width,
    required this.height,
  });

  factory CanvasSize.fromJson(Map<String, dynamic> json) {
    return CanvasSize(
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AnimationMetadata {
  final CanvasSize canvasSize;
  final String mode;
  final int totalSteps;
  final String? createdAt;

  AnimationMetadata({
    required this.canvasSize,
    required this.mode,
    required this.totalSteps,
    this.createdAt,
  });

  factory AnimationMetadata.fromJson(Map<String, dynamic> json) {
    return AnimationMetadata(
      canvasSize: CanvasSize.fromJson(
        json['canvasSize'] as Map<String, dynamic>? ?? {},
      ),
      mode: json['mode']?.toString() ?? 'below',
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class DrawingLine {
  final List<double> points;
  final Color color;
  final double lineWidth;
  final String globalCompositeOperation;

  DrawingLine({
    required this.points,
    required this.color,
    required this.lineWidth,
    required this.globalCompositeOperation,
  });

  factory DrawingLine.fromJson(Map<String, dynamic> json) {
    return DrawingLine(
      points: (json['points'] as List?)
              ?.map((p) => (p as num).toDouble())
              .toList() ??
          [],
      color: _parseColor(json['color']?.toString() ?? '#000000'),
      lineWidth: (json['lineWidth'] as num?)?.toDouble() ?? 1.0,
      globalCompositeOperation:
          json['globalCompositeOperation']?.toString() ?? 'source-over',
    );
  }

  static Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return const Color(0xFF000000);
  }
}

class DrawingRectangle {
  final double x;
  final double y;
  final double width;
  final double height;
  final Color color;
  final double lineWidth;
  final String globalCompositeOperation;

  DrawingRectangle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    required this.lineWidth,
    required this.globalCompositeOperation,
  });

  factory DrawingRectangle.fromJson(Map<String, dynamic> json) {
    return DrawingRectangle(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 0.0,
      height: (json['height'] as num?)?.toDouble() ?? 0.0,
      color: DrawingLine._parseColor(json['color']?.toString() ?? '#000000'),
      lineWidth: (json['lineWidth'] as num?)?.toDouble() ?? 1.0,
      globalCompositeOperation:
          json['globalCompositeOperation']?.toString() ?? 'source-over',
    );
  }
}

class DrawingCircle {
  final double x;
  final double y;
  final double radius;
  final Color color;
  final double lineWidth;
  final String globalCompositeOperation;

  DrawingCircle({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.lineWidth,
    required this.globalCompositeOperation,
  });

  factory DrawingCircle.fromJson(Map<String, dynamic> json) {
    return DrawingCircle(
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      radius: (json['radius'] as num?)?.toDouble() ?? 0.0,
      color: DrawingLine._parseColor(json['color']?.toString() ?? '#000000'),
      lineWidth: (json['lineWidth'] as num?)?.toDouble() ?? 1.0,
      globalCompositeOperation:
          json['globalCompositeOperation']?.toString() ?? 'source-over',
    );
  }
}

class DrawingText {
  final String text;
  final double x;
  final double y;
  final Color color;
  final double fontSize;
  final String fontFamily;
  final String globalCompositeOperation;

  DrawingText({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    required this.globalCompositeOperation,
  });

  factory DrawingText.fromJson(Map<String, dynamic> json) {
    return DrawingText(
      text: json['text']?.toString() ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      color: DrawingLine._parseColor(json['color']?.toString() ?? '#000000'),
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      fontFamily: json['fontFamily']?.toString() ?? 'Arial',
      globalCompositeOperation:
          json['globalCompositeOperation']?.toString() ?? 'source-over',
    );
  }
}

class AnimationStep {
  final int id;
  final String name;
  final List<DrawingLine> lines;
  final List<DrawingRectangle> rectangles;
  final List<DrawingCircle> circles;
  final List<DrawingText> texts;

  AnimationStep({
    required this.id,
    required this.name,
    required this.lines,
    required this.rectangles,
    required this.circles,
    required this.texts,
  });

  factory AnimationStep.fromJson(Map<String, dynamic> json) {
    return AnimationStep(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      lines: (json['lines'] as List?)
              ?.map((line) => DrawingLine.fromJson(line as Map<String, dynamic>))
              .toList() ??
          [],
      rectangles: (json['rectangles'] as List?)
              ?.map((rect) =>
                  DrawingRectangle.fromJson(rect as Map<String, dynamic>))
              .toList() ??
          [],
      circles: (json['circles'] as List?)
              ?.map((circle) =>
                  DrawingCircle.fromJson(circle as Map<String, dynamic>))
              .toList() ??
          [],
      texts: (json['texts'] as List?)
              ?.map(
                  (text) => DrawingText.fromJson(text as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class AnimationData {
  final String version;
  final List<AnimationStep> steps;
  final AnimationMetadata metadata;

  AnimationData({
    required this.version,
    required this.steps,
    required this.metadata,
  });

  factory AnimationData.fromJson(Map<String, dynamic> json) {
    return AnimationData(
      version: json['version']?.toString() ?? '1.0',
      steps: (json['steps'] as List?)
              ?.map((step) => AnimationStep.fromJson(step as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: AnimationMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  factory AnimationData.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return AnimationData.fromJson(json);
  }
}
