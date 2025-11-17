import 'dart:convert';
import 'dart:ui' show Size;

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

  UserSolution({
    this.answerChoice,
    this.explanation,
    this.drawingFile,
    this.aiSolution,
  });

  factory UserSolution.fromJson(Map<String, dynamic> json) {
    return UserSolution(
      answerChoice: json['answer_choice']?.toString(),
      explanation: json['explanation']?.toString(),
      drawingFile: json['drawing_file']?.toString(),
      aiSolution: json['ai_solution'] != null
          ? AiSolution.fromJson(json['ai_solution'] as Map<String, dynamic>)
          : null,
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
