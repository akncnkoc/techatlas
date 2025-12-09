/// Çizim kalemi modları
enum DrawingMode {
  /// Serbest çizim (kalem)
  pen,

  /// Vurgulayıcı kalem
  highlighter,

  /// Metin ekleme
  text,

  /// Geometrik şekiller
  shapes,

  /// 3D Şekiller
  shapes3d,

  /// Cetvel / Düz çizgi
  ruler,

  /// Spot ışık (ekranın bir kısmını vurgulama)
  spotlight,

  /// Perde (ekranı aşamalı açma/kapatma)
  curtain,

  /// Laser pointer / Gösterge
  laser,

  /// Izgara
  grid,
}

extension DrawingModeExtension on DrawingMode {
  String get name {
    switch (this) {
      case DrawingMode.pen:
        return 'Kalem';
      case DrawingMode.highlighter:
        return 'Vurgulayıcı';
      case DrawingMode.text:
        return 'Metin';
      case DrawingMode.shapes:
        return 'Şekiller';
      case DrawingMode.shapes3d:
        return '3D Şekiller';
      case DrawingMode.ruler:
        return 'Cetvel';
      case DrawingMode.spotlight:
        return 'Spot Işık';
      case DrawingMode.curtain:
        return 'Perde';
      case DrawingMode.laser:
        return 'Laser';
      case DrawingMode.grid:
        return 'Izgara';
    }
  }

  String get icon {
    switch (this) {
      case DrawingMode.pen:
        return '✏️';
      case DrawingMode.highlighter:
        return '🖍️';
      case DrawingMode.text:
        return '📝';
      case DrawingMode.shapes:
        return '⬜';
      case DrawingMode.shapes3d:
        return '🎲';
      case DrawingMode.ruler:
        return '📏';
      case DrawingMode.spotlight:
        return '💡';
      case DrawingMode.curtain:
        return '🪟';
      case DrawingMode.laser:
        return '🔴';
      case DrawingMode.grid:
        return '⊞';
    }
  }

  String get description {
    switch (this) {
      case DrawingMode.pen:
        return 'Ekrana serbest çizim yapın';
      case DrawingMode.highlighter:
        return 'Metinleri vurgulayın';
      case DrawingMode.text:
        return 'Ekrana yazı yazın';
      case DrawingMode.shapes:
        return 'Geometrik şekiller çizin';
      case DrawingMode.shapes3d:
        return '3D şekiller döndürün';
      case DrawingMode.ruler:
        return 'Düz çizgiler çizin';
      case DrawingMode.spotlight:
        return 'Ekranın bir kısmını vurgulayın';
      case DrawingMode.curtain:
        return 'Ekranı aşamalı olarak açın/kapatın';
      case DrawingMode.laser:
        return 'Gösterge ile işaret edin';
      case DrawingMode.grid:
        return 'Izgara ekleyin';
    }
  }
}
