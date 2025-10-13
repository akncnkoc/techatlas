import 'stroke.dart';

/// Çizim geçmişini yöneten sınıf - Undo/Redo için kullanılır
class DrawingHistory {
  // Her sayfa için ayrı geçmiş tutar
  final Map<int, List<List<Stroke>>> _history = {};
  final Map<int, int> _currentIndex = {};

  static const int maxHistorySize = 50; // Maksimum 50 adım geriye gidebilir

  /// Mevcut durumu kaydet
  void saveState(int pageNumber, List<Stroke> strokes) {
    // Geçmiş listesini al veya oluştur
    final history = _history[pageNumber] ?? [];
    final currentIndex = _currentIndex[pageNumber] ?? -1;

    // Eğer ortadaysak (undo yapılmışsa), ileriyi sil
    if (currentIndex < history.length - 1) {
      history.removeRange(currentIndex + 1, history.length);
    }

    // Yeni durumu ekle (deep copy)
    final stateCopy = strokes.map((stroke) {
      if (stroke.type != StrokeType.freehand) {
        return Stroke.shape(
          color: stroke.color,
          width: stroke.width,
          type: stroke.type,
          shapePoints: List.from(stroke.points),
        );
      } else {
        final newStroke = Stroke(
          color: stroke.color,
          width: stroke.width,
          erase: stroke.erase,
          type: stroke.type,
        );
        newStroke.points.addAll(stroke.points);
        return newStroke;
      }
    }).toList();

    history.add(stateCopy);

    // Maksimum boyutu aşarsa en eskiyi sil
    if (history.length > maxHistorySize) {
      history.removeAt(0);
    }

    // İndeksi güncelle
    _history[pageNumber] = history;
    _currentIndex[pageNumber] = history.length - 1;
  }

  /// Undo yapılabilir mi?
  bool canUndo(int pageNumber) {
    final currentIndex = _currentIndex[pageNumber] ?? -1;
    return currentIndex > 0;
  }

  /// Redo yapılabilir mi?
  bool canRedo(int pageNumber) {
    final history = _history[pageNumber];
    if (history == null) return false;

    final currentIndex = _currentIndex[pageNumber] ?? -1;
    return currentIndex < history.length - 1;
  }

  /// Undo işlemi - bir önceki duruma dön
  List<Stroke>? undo(int pageNumber) {
    if (!canUndo(pageNumber)) return null;

    final currentIndex = _currentIndex[pageNumber]!;
    _currentIndex[pageNumber] = currentIndex - 1;

    final history = _history[pageNumber]!;
    final previousState = history[currentIndex - 1];

    // Deep copy döndür
    return previousState.map((stroke) {
      if (stroke.type != StrokeType.freehand) {
        return Stroke.shape(
          color: stroke.color,
          width: stroke.width,
          type: stroke.type,
          shapePoints: List.from(stroke.points),
        );
      } else {
        final newStroke = Stroke(
          color: stroke.color,
          width: stroke.width,
          erase: stroke.erase,
          type: stroke.type,
        );
        newStroke.points.addAll(stroke.points);
        return newStroke;
      }
    }).toList();
  }

  /// Redo işlemi - bir sonraki duruma git
  List<Stroke>? redo(int pageNumber) {
    if (!canRedo(pageNumber)) return null;

    final currentIndex = _currentIndex[pageNumber]!;
    _currentIndex[pageNumber] = currentIndex + 1;

    final history = _history[pageNumber]!;
    final nextState = history[currentIndex + 1];

    // Deep copy döndür
    return nextState.map((stroke) {
      if (stroke.type != StrokeType.freehand) {
        return Stroke.shape(
          color: stroke.color,
          width: stroke.width,
          type: stroke.type,
          shapePoints: List.from(stroke.points),
        );
      } else {
        final newStroke = Stroke(
          color: stroke.color,
          width: stroke.width,
          erase: stroke.erase,
          type: stroke.type,
        );
        newStroke.points.addAll(stroke.points);
        return newStroke;
      }
    }).toList();
  }

  /// Belirli bir sayfanın geçmişini temizle
  void clearPage(int pageNumber) {
    _history.remove(pageNumber);
    _currentIndex.remove(pageNumber);
  }

  /// Tüm geçmişi temizle
  void clearAll() {
    _history.clear();
    _currentIndex.clear();
  }

  /// Debug için - mevcut durumu göster
  String getDebugInfo(int pageNumber) {
    final history = _history[pageNumber];
    final currentIndex = _currentIndex[pageNumber];

    if (history == null) {
      return 'Sayfa $pageNumber: Geçmiş yok';
    }

    return 'Sayfa $pageNumber: ${currentIndex! + 1}/${history.length} adım';
  }
}
