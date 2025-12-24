import 'package:pdfrx/pdfrx.dart';
import 'dart:math';

class Chapter {
  final String title;
  final int pageNumber; // 1-based

  Chapter({required this.title, required this.pageNumber});
}

class TOCDetectorService {
  /// Scans the first [scanLimit] pages of the document to find a potential
  /// Table of Contents page.
  ///
  /// Returns a list of [Chapter]s if found, otherwise empty list.
  Future<List<Chapter>> scanForTOC(
    PdfDocument doc, {
    int scanLimit = 10,
  }) async {
    int bestPageNumber = -1;
    int maxLinks = 0;

    // 1. Find the page with the most internal links
    // We scan pages 1 to min(pages.count, scanLimit)
    int limit = min(doc.pages.length, scanLimit);

    for (int i = 1; i <= limit; i++) {
      // Skip page 1 (cover) if possible, but keep it in case it's a 1-page doc?
      // Usually TOC is not on page 1 (cover). Let's keep scanning all.
      final page = doc.pages[i - 1];
      try {
        final links = await page.loadLinks();

        // Count generic internal links (having destination)
        // PdfLink usually has `dest` or `url`. we want `dest`.
        int internalLinkCount = 0;

        for (final link in links) {
          if (link.dest != null) {
            internalLinkCount++;
          }
        }

        // User requested "at least 1".
        // We look for the page with the most links to avoid false positives
        // (e.g. a page with just 1 reference link vs a TOC with 20).
        // But strict acceptance threshold is 1.
        if (internalLinkCount >= 1 && internalLinkCount > maxLinks) {
          maxLinks = internalLinkCount;
          bestPageNumber = i;
        }
      } catch (e) {}
    }

    if (bestPageNumber != -1) {
      return await extractChapters(doc.pages[bestPageNumber - 1]);
    }

    return [];
  }

  /// Extracts chapters from specific page by correlating links with text.
  Future<List<Chapter>> extractChapters(PdfPage page) async {
    List<Chapter> chapters = [];

    try {
      final links = await page.loadLinks();
      final text = await page.loadText();

      // Filter only internal links and sort by vertical position (top to bottom)
      final internalLinks = links.where((l) => l.dest != null).toList();

      // Sort links by Y position (assuming standard vertical TOC)
      internalLinks.sort((a, b) {
        if (a.rects.isEmpty) return 1;
        if (b.rects.isEmpty) return -1;
        return a.rects.first.top.compareTo(b.rects.first.top);
      });

      for (final link in internalLinks) {
        if (link.rects.isEmpty) continue;

        // Get the text covered by the link rect
        final linkRect = link.rects.first;

        // Find matched text fragments
        String title = '';

        // Simple heuristic: Join all text fragments that intersect with the link rect
        // or are very close to it (e.g. on the same line).

        // Group fragments by line (Y position)
        // Find fragments that are visually on the same line as the link
        // We expand the tolerance because proper TOC pointers (.....) often
        // align loosely or the font sizes differ.
        const double verticalTolerance = 10.0; // +/- 5-10 points

        final rowFragments = text.fragments.where((f) {
          final textCenterY = f.bounds.center.y;
          final linkCenterY = linkRect.center.y;
          // Check if text is within vertical range of the link's center
          return (textCenterY - linkCenterY).abs() < verticalTolerance;
        }).toList();

        // Debug
        // if (rowFragments.isEmpty) {
        //
        //
        // }

        // Sort fragments horizontally
        rowFragments.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));

        // Combine text
        title = rowFragments.map((f) => f.text).join(' ').trim();

        // Fallback: If no text specifically *under* the link, maybe the link is on the page number
        if (title.isEmpty) {
          final sameLineFragments = text.fragments.where((f) {
            final fCenterY = f.bounds.center.y;
            final verticalOverlap =
                (min(f.bounds.bottom, linkRect.bottom) -
                max(f.bounds.top, linkRect.top));
            return verticalOverlap > 0; // Any vertical overlap
          }).toList();

          sameLineFragments.sort(
            (a, b) => a.bounds.left.compareTo(b.bounds.left),
          );
          title = sameLineFragments.map((f) => f.text).join(' ').trim();
        }

        if (title.isNotEmpty && link.dest?.pageNumber != null) {
          // Clean up title (remove trailing dots, page numbers if included in text)
          title = _cleanTitle(title);

          chapters.add(
            Chapter(title: title, pageNumber: link.dest!.pageNumber!),
          );
        } else if (link.dest?.pageNumber != null) {
          // Fallback title
          chapters.add(
            Chapter(
              title: "Bölüm (Sf ${link.dest!.pageNumber})",
              pageNumber: link.dest!.pageNumber!,
            ),
          );
        }
      }
    } catch (e) {}

    return chapters;
  }

  String _cleanTitle(String raw) {
    // Remove typical TOC fillers like "......"
    String cleaned = raw.replaceAll(RegExp(r'\.{2,}'), '');

    // Remove trailing numbers (often the page number itself is in the text)
    // e.g. "Introduction .... 1" -> "Introduction"
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+$'), '');

    return cleaned.trim();
  }
}
