import 'dart:async';

/// Sayfa zaman takibi için model
class PageTimeData {
  final int pageNumber;
  DateTime startTime;
  Duration totalDuration;
  bool isActive;

  PageTimeData({
    required this.pageNumber,
    required this.startTime,
    this.totalDuration = Duration.zero,
    this.isActive = true,
  });

  /// Şu anki sayfadaki toplam süreyi hesapla
  Duration get currentTotalDuration {
    if (isActive) {
      final elapsed = DateTime.now().difference(startTime);
      return totalDuration + elapsed;
    }
    return totalDuration;
  }

  /// Sayfayı duraklat (başka sayfaya geçildiğinde)
  void pause() {
    if (isActive) {
      final elapsed = DateTime.now().difference(startTime);
      totalDuration += elapsed;
      isActive = false;
    }
  }

  /// Sayfayı yeniden başlat (bu sayfaya geri dönüldüğünde)
  void resume() {
    if (!isActive) {
      startTime = DateTime.now();
      isActive = true;
    }
  }

  /// Zamanı okunabilir formata çevir
  String formatDuration() {
    final duration = currentTotalDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}s ${minutes}d ${seconds}sn';
    } else if (minutes > 0) {
      return '${minutes}d ${seconds}sn';
    } else {
      return '${seconds}sn';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'pageNumber': pageNumber,
      'totalDuration': totalDuration.inSeconds,
    };
  }

  factory PageTimeData.fromJson(Map<String, dynamic> json) {
    return PageTimeData(
      pageNumber: json['pageNumber'] as int,
      startTime: DateTime.now(),
      totalDuration: Duration(seconds: json['totalDuration'] as int),
      isActive: false,
    );
  }
}

/// Tüm sayfalar için zaman takibi yöneticisi
class PageTimeTracker {
  final Map<int, PageTimeData> _pageData = {};
  int? _currentPage;
  Timer? _updateTimer;
  final void Function()? onUpdate;

  PageTimeTracker({this.onUpdate});

  /// Zamanlayıcıyı başlat (UI güncellemeleri için)
  void startTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      onUpdate?.call();
    });
  }

  /// Zamanlayıcıyı durdur
  void stopTimer() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Sayfa değiştiğinde çağrılır
  void onPageChanged(int pageNumber) {
    // Önceki sayfayı duraklat
    if (_currentPage != null && _pageData.containsKey(_currentPage)) {
      _pageData[_currentPage]!.pause();
    }

    // Yeni sayfayı başlat veya devam ettir
    if (!_pageData.containsKey(pageNumber)) {
      _pageData[pageNumber] = PageTimeData(
        pageNumber: pageNumber,
        startTime: DateTime.now(),
      );
    } else {
      _pageData[pageNumber]!.resume();
    }

    _currentPage = pageNumber;
    onUpdate?.call();
  }

  /// Belirli bir sayfa için zaman verisini al
  PageTimeData? getPageData(int pageNumber) {
    return _pageData[pageNumber];
  }

  /// Mevcut sayfa için zaman verisini al
  PageTimeData? getCurrentPageData() {
    if (_currentPage == null) return null;
    return _pageData[_currentPage];
  }

  /// Tüm sayfa verilerini al
  Map<int, PageTimeData> getAllPageData() {
    return Map.unmodifiable(_pageData);
  }

  /// Toplam harcanan süreyi hesapla
  Duration getTotalDuration() {
    Duration total = Duration.zero;
    for (final data in _pageData.values) {
      total += data.currentTotalDuration;
    }
    return total;
  }

  /// Tüm verileri temizle
  void clear() {
    _pageData.clear();
    _currentPage = null;
    onUpdate?.call();
  }

  /// Bellek temizliği
  void dispose() {
    stopTimer();
    _pageData.clear();
  }

  /// Verileri JSON'a dönüştür (kaydetmek için)
  List<Map<String, dynamic>> toJson() {
    // Aktif sayfayı önce duraklat ki doğru süreyi kaydedelim
    if (_currentPage != null && _pageData.containsKey(_currentPage)) {
      _pageData[_currentPage]!.pause();
      _pageData[_currentPage]!.resume();
    }

    return _pageData.values.map((data) => data.toJson()).toList();
  }

  /// JSON'dan verileri yükle
  void fromJson(List<dynamic> json) {
    _pageData.clear();
    for (final item in json) {
      final data = PageTimeData.fromJson(item as Map<String, dynamic>);
      _pageData[data.pageNumber] = data;
    }
  }
}
