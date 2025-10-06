class OpenPdfTab {
  final String pdfPath;
  final String title;
  final String? dropboxPath;

  OpenPdfTab({
    required this.pdfPath,
    required this.title,
    this.dropboxPath,
  });
}

class BreadcrumbItem {
  final String name;
  final String path;

  BreadcrumbItem({required this.name, required this.path});
}