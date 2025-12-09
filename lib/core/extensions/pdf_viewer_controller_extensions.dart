import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Extension methods for PdfViewerController to provide pdfx-like API
/// This helps maintain backward compatibility during migration from pdfx to pdfrx
extension PdfViewerControllerExtensions on PdfViewerController {
  /// Navigate to the next page
  /// Note: pdfrx doesn't support animation parameters, navigation is instant
  void nextPage({Duration? duration, Curve? curve}) {
    if (isReady && pageNumber != null) {
      if (pageNumber! < pageCount) {
        goToPage(pageNumber: pageNumber! + 1);
      }
    }
  }

  /// Navigate to the previous page
  /// Note: pdfrx doesn't support animation parameters, navigation is instant
  void previousPage({Duration? duration, Curve? curve}) {
    if (isReady && pageNumber != null && pageNumber! > 1) {
      goToPage(pageNumber: pageNumber! - 1);
    }
  }

  /// Jump to a specific page without animation
  void jumpToPage(int page) {
    if (isReady) {
      goToPage(pageNumber: page);
    }
  }

  /// Animate to a specific page (pdfrx doesn't support animation, behaves like jumpToPage)
  void animateToPage(int page, {Duration? duration, Curve? curve}) {
    jumpToPage(page);
  }

  /// Get total page count (null-safe accessor)
  int? get pagesCount {
    return pageCount;
  }

  /// Get current page number (alias for pageNumber for compatibility)
  int? get page {
    return pageNumber;
  }

  /// Create a ValueNotifier that tracks page changes
  /// This provides similar functionality to pdfx's pageListenable
  ValueNotifier<int?> createPageNotifier() {
    final notifier = ValueNotifier<int?>(pageNumber);

    void listener() {
      if (notifier.value != pageNumber) {
        notifier.value = pageNumber;
      }
    }

    addListener(listener);

    return notifier;
  }
}
