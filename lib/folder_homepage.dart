import 'dart:io';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import './dropbox/dropbox_service.dart';
import './dropbox/models.dart';
import './google_drive/google_drive_service.dart';
import './google_drive/models.dart' as gdrive;
import './models/crop_data.dart';
import 'login_page.dart';
import 'viewer/pdf_drawing_viewer_page.dart';

class FolderHomePage extends StatefulWidget {
  const FolderHomePage({super.key});

  @override
  State<FolderHomePage> createState() => _FolderHomePageState();
}

class _FolderHomePageState extends State<FolderHomePage> {
  DropboxService? dropboxService;
  GoogleDriveService? googleDriveService;
  List<DropboxItem> folders = [];
  List<DropboxItem> pdfs = [];
  List<gdrive.DriveItem> driveItems =
      []; // folders + .book files (changed from driveBooks)
  String? currentDriveFolderId; // current Drive folder (null = root)
  List<OpenPdfTab> openTabs = [];
  int currentTabIndex = 0;
  bool isLoading = false;
  bool isFullScreen = false;
  bool showFolderBrowser = false;
  bool useDropbox = false;
  bool useGoogleDrive = false;
  bool showStorageSelection = true;

  List<BreadcrumbItem> breadcrumbs = [
    BreadcrumbItem(name: 'Akilli Tahta Proje Demo', path: ''),
  ];
  List<BreadcrumbItem> driveBreadcrumbs = [
    BreadcrumbItem(
      name: 'Ana Klasör',
      path: '1U8mbCEY2JzdDngZxL7RyxID5eh8MW2yR',
    ), // main folder
  ];

  @override
  void initState() {
    super.initState();
    // Don't automatically load anything - let user choose storage type
  }

  String get currentPath => breadcrumbs.last.path;

  void _selectLocalStorage() {
    setState(() {
      showStorageSelection = false;
      useDropbox = false;
      useGoogleDrive = false;
      // Local files will be picked by user on-demand
    });
  }

  Future<void> _selectGoogleDriveStorage() async {
    setState(() => isLoading = true);

    try {
      googleDriveService = GoogleDriveService();
      // Initialize service (which will load service account credentials)
      await googleDriveService!.initialize();

      // Load root folder after successful initialization
      const rootFolderId =
          "1U8mbCEY2JzdDngZxL7RyxID5eh8MW2yR"; // Main folder ID
      await _loadGoogleDriveFolder(rootFolderId);
      setState(() {
        showStorageSelection = false;
        useGoogleDrive = true;
        useDropbox = false;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Google Drive authentication error: $e');
    }
  }

  Future<void> _makeFullscreen() async {
    setState(() => isFullScreen = !isFullScreen);
    // Web'de window_manager yok
    if (!kIsWeb) {
      await windowManager.setFullScreen(isFullScreen);
    }
  }

  Future<void> _loadFolder(String path) async {
    if (dropboxService == null) return;

    setState(() => isLoading = true);

    try {
      final items = await dropboxService!.listFolder(path);

      final foldersList = items.where((item) => item.isFolder).toList();
      final pdfsList = items.where((item) => item.isPdf).toList();

      setState(() {
        folders = foldersList;
        pdfs = pdfsList;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load folder: $e');
    }
  }

  Future<void> _loadGoogleDriveFolder(String? folderId) async {
    if (googleDriveService == null) return;

    setState(() => isLoading = true);

    try {
      final items = await googleDriveService!.listFiles(folderId: folderId);

      setState(() {
        driveItems = items; // folders + .book files
        currentDriveFolderId = folderId;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load Google Drive folder: $e');
    }
  }

  void _navigateToDriveFolder(String folderId, String folderName) {
    setState(() {
      driveBreadcrumbs.add(BreadcrumbItem(name: folderName, path: folderId));
    });
    _loadGoogleDriveFolder(folderId);
  }

  void _navigateToDriveBreadcrumb(int index) {
    if (index < driveBreadcrumbs.length - 1) {
      setState(() {
        driveBreadcrumbs = driveBreadcrumbs.sublist(0, index + 1);
      });
      final folderId = driveBreadcrumbs[index].path;
      _loadGoogleDriveFolder(folderId);
    }
  }

  Future<void> _pickLocalPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['book'],
        allowMultiple: false,
        withData: kIsWeb, // Web'de bytes gerekli
      );

      if (result != null && result.files.single.bytes != null) {
        // Web platformu - bytes kullan
        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name;

        // Check if it's a book file
        if (fileName.toLowerCase().endsWith('.book')) {
          await _handleZipFileFromBytes(bytes, fileName);
        } else {
          // PDF için web'de bytes'tan geçici dosya oluştur
          if (kIsWeb) {
            _showError('Web platformunda sadece .book dosyaları desteklenir');
          }
        }
      } else if (result != null && result.files.single.path != null) {
        // Mobil/Desktop platformu - path kullan
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;

        // Check if it's a book file
        if (fileName.toLowerCase().endsWith('.book')) {
          await _handleZipFile(filePath, fileName);
        } else {
          // It's a PDF file
          setState(() {
            openTabs.add(
              OpenPdfTab(pdfPath: filePath, title: 'Kitap', dropboxPath: null),
            );
            currentTabIndex = openTabs.length - 1;
            showFolderBrowser = false;
          });
        }
      }
    } catch (e) {
      _showError('Failed to open file: $e');
    }
  }

  // Web platformu için bytes kullanarak zip işleme
  Future<void> _handleZipFileFromBytes(
    Uint8List bytes,
    String zipFileName,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Decode the book file (zip format)
      final archive = ZipDecoder().decodeBytes(bytes);

      // Look for original.pdf and crop_coordinates.json in the archive
      ArchiveFile? originalPdf;
      ArchiveFile? cropCoordinatesJson;

      for (final file in archive) {
        if (file.isFile && file.name.toLowerCase() == 'original.pdf') {
          originalPdf = file;
        } else if (file.isFile &&
            file.name.toLowerCase() == 'crop_coordinates.json') {
          cropCoordinatesJson = file;
        }
      }

      if (originalPdf == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        _showError('original.pdf not found in the book file');
        return;
      }

      // Web'de dosya yazmadan doğrudan bytes kullanacağız
      final pdfBytes = originalPdf.content as List<int>;

      // Parse crop coordinates data if available
      CropData? cropData;
      if (cropCoordinatesJson != null) {
        try {
          final jsonString = utf8.decode(
            cropCoordinatesJson.content as List<int>,
          );
          cropData = CropData.fromJsonString(jsonString);
        } catch (e) {
          print('⚠️ Failed to parse crop_coordinates.json: $e');
        }
      } else {
        print('⚠️ No crop_coordinates.json found in ZIP');
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      // Web için bytes'ı kullan - path yerine
      // PDF viewer'a bytes eklemek gerekecek
      setState(() {
        openTabs.add(
          OpenPdfTab(
            pdfPath:
                'web_${DateTime.now().millisecondsSinceEpoch}.pdf', // Placeholder
            title: 'Kitap',
            dropboxPath: null,
            cropData: cropData,
            zipFilePath: null, // Web'de zip path yok
            pdfBytes: Uint8List.fromList(pdfBytes), // PDF bytes'ı sakla
            zipBytes: bytes, // ZIP bytes'ı da sakla (crop resimleri için)
          ),
        );
        currentTabIndex = openTabs.length - 1;
        showFolderBrowser = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showError('Failed to extract PDF from zip: $e');
    }
  }

  Future<void> _handleZipFile(String zipPath, String zipFileName) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Read the book file (zip format)
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Look for original.pdf and crop_coordinates.json in the archive
      ArchiveFile? originalPdf;
      ArchiveFile? cropCoordinatesJson;

      for (final file in archive) {
        if (file.isFile && file.name.toLowerCase() == 'original.pdf') {
          originalPdf = file;
        } else if (file.isFile &&
            file.name.toLowerCase() == 'crop_coordinates.json') {
          cropCoordinatesJson = file;
        }
      }

      if (originalPdf == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        _showError('original.pdf not found in the book file');
        return;
      }

      // Extract the PDF to a temporary location
      final tempDir = await getTemporaryDirectory();
      final pdfPath =
          '${tempDir.path}/original_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(originalPdf.content as List<int>);

      // Parse crop coordinates data if available
      CropData? cropData;
      if (cropCoordinatesJson != null) {
        try {
          final jsonString = utf8.decode(
            cropCoordinatesJson.content as List<int>,
          );
          cropData = CropData.fromJsonString(jsonString);
        } catch (e, stackTrace) {
          print('e: $e');
          print('Stack trace: $stackTrace');
        }
      } else {
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      // Open the extracted PDF
      setState(() {
        openTabs.add(
          OpenPdfTab(
            pdfPath: pdfPath,
            title: 'Kitap',
            dropboxPath: null,
            cropData: cropData,
            zipFilePath: zipPath, // Zip dosyasının yolunu sakla
          ),
        );
        currentTabIndex = openTabs.length - 1;
        showFolderBrowser = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showError('Failed to extract PDF from zip: $e');
    }
  }

  void _navigateToFolder(String folderPath, String folderName) {
    setState(() {
      breadcrumbs.add(BreadcrumbItem(name: folderName, path: folderPath));
    });
    _loadFolder(folderPath);
  }

  void _navigateToBreadcrumb(int index) {
    if (index < breadcrumbs.length - 1) {
      setState(() {
        breadcrumbs = breadcrumbs.sublist(0, index + 1);
      });
      _loadFolder(breadcrumbs.last.path);
    }
  }

  void _openFolderBrowser() {
    if (useDropbox) {
      setState(() {
        showFolderBrowser = true;
      });
    } else {
      // For local mode, open file picker directly
      _pickLocalPdf();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openPdfFromDropbox(DropboxItem pdf) async {
    if (dropboxService == null) return;

    final existingIndex = openTabs.indexWhere(
      (tab) => tab.dropboxPath == pdf.path,
    );
    if (existingIndex != -1) {
      setState(() {
        currentTabIndex = existingIndex;
        showFolderBrowser = false;
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = await dropboxService!.downloadFile(pdf.path);
      if (!mounted) return;
      Navigator.of(context).pop();

      setState(() {
        openTabs.add(
          OpenPdfTab(pdfPath: file.path, title: 'Kitap', dropboxPath: pdf.path),
        );
        currentTabIndex = openTabs.length - 1;
        showFolderBrowser = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showError('Failed to open PDF: $e');
    }
  }

  Future<void> _openBookFromGoogleDrive(gdrive.DriveItem book) async {
    if (googleDriveService == null) return;

    // Check if already open
    final existingIndex = openTabs.indexWhere(
      (tab) => tab.dropboxPath == 'gdrive:${book.id}',
    );
    if (existingIndex != -1) {
      setState(() {
        currentTabIndex = existingIndex;
        showFolderBrowser = false;
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (kIsWeb) {
        // Web: Download as bytes
        final bytes = await googleDriveService!.downloadFileBytes(book.id);
        if (!mounted) return;
        Navigator.of(context).pop();
        await _handleZipFileFromBytes(bytes, book.name);
      } else {
        // Desktop/Mobile: Download to file
        final file = await googleDriveService!.downloadFile(book.id, book.name);
        if (!mounted) return;
        Navigator.of(context).pop();
        await _handleZipFile(file.path, book.name);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showError('Failed to open book from Google Drive: $e');
    }
  }

  void closeTab(int index) {
    setState(() {
      if (openTabs.length > index) {
        openTabs.removeAt(index);
        if (currentTabIndex >= openTabs.length && openTabs.isNotEmpty) {
          currentTabIndex = openTabs.length - 1;
        }
        if (openTabs.isEmpty) {
          currentTabIndex = 0;
        }
      }
    });
  }

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < breadcrumbs.length; i++) ...[
                    InkWell(
                      onTap: () => _navigateToBreadcrumb(i),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: i == breadcrumbs.length - 1
                            ? BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Text(
                          breadcrumbs[i].name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i == breadcrumbs.length - 1
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == breadcrumbs.length - 1
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    if (i < breadcrumbs.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.15),
                  Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.cloud_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < driveBreadcrumbs.length; i++) ...[
                    InkWell(
                      onTap: () => _navigateToDriveBreadcrumb(i),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: i == driveBreadcrumbs.length - 1
                            ? BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.secondary
                                        .withValues(alpha: 0.12),
                                    Theme.of(context).colorScheme.secondary
                                        .withValues(alpha: 0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Text(
                          driveBreadcrumbs[i].name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: i == driveBreadcrumbs.length - 1
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == driveBreadcrumbs.length - 1
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    if (i < driveBreadcrumbs.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: 6,
                bottom: 6,
                left: 0,
                right: 0,
              ),
              child: ListView.builder(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                itemCount: openTabs.length,
                itemBuilder: (context, index) {
                  final tab = openTabs[index];
                  final isSelected = index == currentTabIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          currentTabIndex = index;
                          showFolderBrowser = false;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        constraints: const BoxConstraints(maxWidth: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: isSelected && !showFolderBrowser
                              ? LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.85),
                                  ],
                                )
                              : null,
                          color: isSelected && !showFolderBrowser
                              ? null
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          boxShadow: isSelected && !showFolderBrowser
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                              color: isSelected && !showFolderBrowser
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                tab.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: isSelected && !showFolderBrowser
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => closeTab(index),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  gradient: isSelected && !showFolderBrowser
                                      ? null
                                      : LinearGradient(
                                          colors: [
                                            Colors.red.shade400.withValues(
                                              alpha: 0.15,
                                            ),
                                            Colors.red.shade600.withValues(
                                              alpha: 0.1,
                                            ),
                                          ],
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: isSelected && !showFolderBrowser
                                      ? Theme.of(context).colorScheme.onPrimary
                                            .withValues(alpha: 0.9)
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // New PDF Button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _openFolderBrowser,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: showFolderBrowser
                      ? LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.85),
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.8),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: showFolderBrowser
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: showFolderBrowser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!useDropbox && !useGoogleDrive) {
      // For local mode, show empty state with "open file" button
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceContainerHighest,
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.6),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Kitap dosyası açın',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bir .book dosyası seçmek için aşağıdaki butona tıklayın',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _pickLocalPdf,
                icon: const Icon(Icons.file_open_rounded),
                label: const Text(
                  'Dosya Seç',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Google Drive mode
    if (useGoogleDrive) {
      if (driveItems.isEmpty) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  Theme.of(context).colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.tertiaryContainer,
                        Theme.of(
                          context,
                        ).colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.folder_off_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bu klasör boş',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Klasör veya .book dosyası bulunamadı',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _loadGoogleDriveFolder(currentDriveFolderId),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text(
                    'Yenile',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Show Google Drive items (folders + books) in premium grid
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: driveItems.length,
        itemBuilder: (context, index) {
          final item = driveItems[index];
          final isFolder = item.isFolder;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (isFolder) {
                  _navigateToDriveFolder(item.id, item.name);
                } else {
                  _openBookFromGoogleDrive(item);
                }
              },
              child: Card(
                elevation: 2,
                shadowColor: isFolder
                    ? Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.15)
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        Theme.of(context).colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Icon container with gradient
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isFolder
                                  ? [
                                      Theme.of(context).colorScheme.tertiary
                                          .withValues(alpha: 0.1),
                                      Theme.of(context).colorScheme.tertiary
                                          .withValues(alpha: 0.05),
                                    ]
                                  : [
                                      Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      Theme.of(context).colorScheme.secondary
                                          .withValues(alpha: 0.05),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Main icon (folder or book)
                              Center(
                                child: Icon(
                                  isFolder
                                      ? Icons.folder_rounded
                                      : Icons.menu_book_rounded,
                                  size: 40,
                                  color: isFolder
                                      ? Theme.of(context).colorScheme.tertiary
                                      : Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              // Small badge
                              if (!isFolder)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.secondary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.cloud_rounded,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Item name
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        width: double.infinity,
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (folders.isEmpty && pdfs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Bu klasör boş',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dropbox\'a dosya veya klasör ekleyin',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadFolder(currentPath),
                icon: const Icon(Icons.refresh),
                label: const Text('Yenile'),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: folders.length + pdfs.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _navigateToFolder(folder.path, folder.name),
              child: Card(
                elevation: 2,
                shadowColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        Theme.of(context).colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.folder_rounded,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        width: double.infinity,
                        child: Text(
                          folder.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          final pdfIndex = index - folders.length;
          final pdf = pdfs[pdfIndex];
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openPdfFromDropbox(pdf),
              child: Card(
                elevation: 2,
                shadowColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        Theme.of(context).colorScheme.surface,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.secondary
                                        .withValues(alpha: 0.1),
                                    Theme.of(context).colorScheme.secondary
                                        .withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14),
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 40,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                            ),
                            // Dropbox cloud badge
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0061FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0061FF,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.cloud_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        width: double.infinity,
                        child: Text(
                          pdf.name.replaceAll('.book', ''),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildStorageSelectionScreen() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium header icon with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Dosya Kaynağı Seçin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PDF dosyalarınızı nereden açmak istersiniz?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 32),

            // Local Storage Card - Premium
            _buildPremiumStorageCard(
              icon: Icons.computer_rounded,
              title: 'Yerel Dosyalar',
              subtitle: 'Bilgisayarınızdan dosya seçin',
              gradientColors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ],
              onTap: _selectLocalStorage,
            ),

            const SizedBox(height: 12),

            // Google Drive Card - Premium
            _buildPremiumStorageCard(
              icon: Icons.cloud_rounded,
              title: 'Google Drive',
              subtitle: '.book dosyalarını görüntüle',
              gradientColors: [
                Theme.of(context).colorScheme.secondary,
                Theme.of(context).colorScheme.tertiary,
              ],
              onTap: isLoading ? null : _selectGoogleDriveStorage,
            ),

            if (isLoading) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 3,
                child: LinearProgressIndicator(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumStorageCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback? onTap,
  }) {
    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Card(
          elevation: 2,
          shadowColor: gradientColors[0].withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    gradientColors[0].withValues(alpha: 0.05),
                    gradientColors[1].withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // Icon container with gradient
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors[0].withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 16),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Arrow icon
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showStorageSelection) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Akilli Tahta Proje Demo'),
          actions: [
            IconButton(
              tooltip: 'Çıkış Yap',
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => LoginPage(onLogin: (_, __) async => false),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: _buildStorageSelectionScreen(),
      );
    }

    return PopScope(
      canPop: openTabs.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && openTabs.isNotEmpty) {
          closeTab(currentTabIndex);
        }
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: ClipRRect(
            child: AppBar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.96),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Depolama Seçimi',
                onPressed: () {
                  setState(() {
                    showStorageSelection = true;
                    openTabs.clear();
                    currentTabIndex = 0;
                  });
                },
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.15),
                          Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      useDropbox
                          ? Icons.cloud_rounded
                          : useGoogleDrive
                          ? Icons.g_mobiledata_rounded
                          : Icons.folder_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      useDropbox
                          ? 'Dropbox'
                          : useGoogleDrive
                          ? 'Google Drive'
                          : 'Yerel Depo',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                // Fullscreen toggle
                Tooltip(
                  message: isFullScreen ? 'Tam Ekrandan Çık' : 'Tam Ekran',
                  child: InkWell(
                    onTap: _makeFullscreen,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        !isFullScreen
                            ? Icons.fullscreen_rounded
                            : Icons.fullscreen_exit_rounded,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                // Refresh button (only when showing grid)
                if (openTabs.isEmpty && !isLoading)
                  Tooltip(
                    message: 'Yenile',
                    child: InkWell(
                      onTap: () => useGoogleDrive
                          ? _loadGoogleDriveFolder(currentDriveFolderId)
                          : _loadFolder(currentPath),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.refresh_rounded, size: 22),
                      ),
                    ),
                  ),
                // Logout
                Tooltip(
                  message: 'Çıkış Yap',
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) =>
                              LoginPage(onLogin: (_, __) async => false),
                        ),
                        (route) => false,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(right: 4),
                      child: const Icon(Icons.logout_rounded, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            if (openTabs.isNotEmpty) _buildTabBar(),
            if ((openTabs.isEmpty || showFolderBrowser) &&
                !isLoading &&
                (useDropbox || useGoogleDrive))
              useGoogleDrive ? _buildDriveBreadcrumbs() : _buildBreadcrumbs(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: openTabs.isEmpty || showFolderBrowser
                    ? _buildGridView()
                    : PdfDrawingViewerPage(
                        key: ValueKey(openTabs[currentTabIndex].pdfPath),
                        pdfPath: openTabs[currentTabIndex].pdfPath,
                        onBack: () => closeTab(currentTabIndex),
                        cropData: openTabs[currentTabIndex].cropData,
                        zipFilePath: openTabs[currentTabIndex].zipFilePath,
                        pdfBytes: openTabs[currentTabIndex].pdfBytes,
                        zipBytes: openTabs[currentTabIndex].zipBytes,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
