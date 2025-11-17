/// Application-wide constants
class AppConstants {
  AppConstants._();

  // Zoom settings
  static const double minZoom = 0.5;
  static const double maxZoom = 4.0;
  static const double zoomStep = 1.2;

  // Gesture thresholds
  static const double swipeVelocityThreshold = 1000.0;
  static const double swipeDistanceThreshold = 100.0;

  // Drawing settings
  static const double minDrawingDistance =
      0.1; // Very low for smooth, responsive drawing
  static const double minHighlighterDistance =
      0.3; // Low for smooth highlighting
  static const double defaultStrokeWidth = 0.7;
  static const double strokeSimplificationTolerance =
      0.3; // Douglas-Peucker tolerance (lower = better quality, higher = more simplification)

  // History settings
  static const int maxHistorySteps = 50;

  // UI dimensions
  static const double toolPanelMinWidth = 200.0;
  static const double toolPanelMaxWidth = 400.0;
  static const double toolPanelMinHeight = 300.0;
  static const double toolButtonSize = 48.0;
  static const double colorDotSize = 40.0;

  // PDF rendering
  static const double pdfRenderQualityMin = 4.0;
  static const double pdfRenderQualityMax = 12.0;
  static const double pdfQualityScaleFactor = 6.0;
  static const double scaleChangeThreshold = 0.05;

  // Time tracking
  static const int timeUpdateIntervalSeconds = 1;

  // File extensions
  static const List<String> supportedPdfExtensions = ['.pdf'];
  static const List<String> supportedBookExtensions = ['.book'];
  static const String cropDataFileName = 'crop_coordinates.json';
  static const String pdfFileName = 'original.pdf';

  // API
  static const String pythonServerUrl = 'http://localhost:5000';
  static const String healthEndpoint = '/health';
  static const String analyzeSingleEndpoint = '/analyze-single';
  static const String analyzeBatchEndpoint = '/analyze-batch';
}
