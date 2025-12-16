import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:window_manager/window_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import './google_drive/google_drive_service.dart';
import './google_drive/models.dart' as gdrive;

// ADDED for creating dummy items for direct access
import './google_drive/models.dart' show DriveItem;

import './models/crop_data.dart';
import './models/downloaded_book.dart';
import './models/app_models.dart';
import './services/book_storage_service.dart';
import 'login_page.dart';
import 'viewer/pdf_drawing_viewer_page.dart';

// Drawing Pen Launcher (Fatih Kalem tarzı)
import 'services/drawing_pen_launcher.dart';
import 'access_codes.dart';
import './services/recent_file_service.dart';
import './models/recent_file.dart';


class FolderHomePage extends StatefulWidget {
  const FolderHomePage({super.key});

  @override
  State<FolderHomePage> createState() => _FolderHomePageState();
}

class _FolderHomePageState extends State<FolderHomePage> {
  GoogleDriveService? googleDriveService;
  final BookStorageService _bookStorageService = BookStorageService();
  final RecentFileService _recentFileService = RecentFileService();
  
  List<RecentFile> recentFiles = [];
  List<gdrive.DriveItem> driveItems =
      []; // folders + .book files (changed from driveBooks)
  String? currentDriveFolderId; // current Drive folder (null = root)
  List<OpenPdfTab> openTabs = [];
  int currentTabIndex = 0;
  bool isLoading = false;
  bool isFullScreen = false;
  bool showFolderBrowser = false;
  bool useGoogleDrive = false;
  bool showMyBooks = false;
  bool showStorageSelection = true;
  List<DownloadedBook> downloadedBooks = [];
  
  // Download progress tracking
  Map<String, double> _downloadProgress = {};
  Set<String> _downloadingBooks = {};
  
  // Download cancellation
  Map<String, bool> _downloadCancelFlags = {};
  
  // Download queue management
  List<gdrive.DriveItem> _downloadQueue = [];
  static const int _maxConcurrentDownloads = 2;

  Timer? _drawingPenMonitor;
  bool _wasDrawingPenRunning = false;

  List<BreadcrumbItem> driveBreadcrumbs = [
    BreadcrumbItem(
      name: 'Ana Klasör',
      path: '1U8mbCEY2JzdDngZxL7RyxID5eh8MW2yR',
    ), // main folder
  ];

  @override
  void initState() {
    super.initState();
    _loadDownloadedBooks();
    _loadRecentFiles();
    _startDrawingPenMonitoring();
    // Don't automatically load anything - let user choose storage type
  }

  @override
  void dispose() {
    _drawingPenMonitor?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentFiles() async {
    final files = await _recentFileService.getRecentFiles();
    setState(() {
      recentFiles = files;
    });
  }

  Future<void> _addRecentFile(String path, String name) async {
    final file = RecentFile(path: path, name: name, addedAt: DateTime.now());
    await _recentFileService.addRecentFile(file);
    await _loadRecentFiles();
  }

  Future<void> _removeRecentFile(String path) async {
    await _recentFileService.removeRecentFile(path);
    await _loadRecentFiles();
  }

  void _startDrawingPenMonitoring() {
    // Her 2 saniyede bir çizim kaleminin durumunu kontrol et
    _drawingPenMonitor = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final isRunning = DrawingPenLauncher.isRunning;

      // Çizim kalemi kapandıysa ve önceden çalışıyorsa
      if (!isRunning && _wasDrawingPenRunning) {
        _wasDrawingPenRunning = false;
        // Ana uygulamayı geri getir ve fullscreen yap
        if (!kIsWeb) {
          await windowManager.show();
          await windowManager.focus();
          if (mounted) {
            await _makeFullscreen();
          }
        }
      } else if (isRunning) {
        _wasDrawingPenRunning = true;
      }
    });
  }

  Future<void> _loadDownloadedBooks() async {
    final books = await _bookStorageService.getBooks();
    setState(() {
      downloadedBooks = books;
    });
  }

  void _selectLocalStorage() {
    setState(() {
      showStorageSelection = false;
      useGoogleDrive = false;
      showMyBooks = false;
      // Local files will be picked by user on-demand
    });
  }

  void _selectMyBooks() {
    setState(() {
      showStorageSelection = false;
      useGoogleDrive = false;
      showMyBooks = true;
    });
  }

  Future<void> _selectGoogleDriveStorage() async {
    // Show dialog to ask for code
    final codeController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Erişim Kodu'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: 'Lütfen erişim kodunuzu giriniz',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vpn_key),
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, codeController.text),
            child: const Text('Giriş'),
          ),
        ],
      ),
    );

    if (result == null || result.trim().isEmpty) return;

    // Show loading while verifying
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final configs = await AccessCodeService.verifyCode(result);
    
    // Close loading dialog
    if (mounted) Navigator.pop(context);

    if (configs.isEmpty) {
      _showError('Geçersiz erişim kodu! Lütfen tekrar deneyiniz.');
      return;
    }

    // Determine which config to use
    ResourceConfig? selectedConfig;

    if (configs.length == 1) {
      selectedConfig = configs.first;
    } else {
      // Multiple resources found, let user choose
      selectedConfig = await showDialog<ResourceConfig>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Erişim Kaynağı Seçin'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: configs.length,
              itemBuilder: (context, index) {
                final cfg = configs[index];
                return ListTile(
                  leading: Icon(
                    cfg.type == ResourceType.folder
                        ? Icons.folder
                        : Icons.description,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(cfg.name),
                  subtitle: Text(
                    cfg.type == ResourceType.folder ? 'Klasör' : 'Dosya',
                  ),
                  onTap: () => Navigator.pop(context, cfg),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('İptal'),
            ),
          ],
        ),
      );
    }

    if (selectedConfig == null) return; // User cancelled selection

    setState(() => isLoading = true);

    try {
      googleDriveService = GoogleDriveService();
      // Initialize service (which will load service account credentials)
      await googleDriveService!.initialize();

      if (selectedConfig.type == ResourceType.file) {
        // --- FILE ACCESS MODE ---
        // Directly open the book without showing folder browser
        
        setState(() {
          // Hide storage selection but don't set useGoogleDrive=true yet 
          // because we are just opening a file, not browsing drive
          showStorageSelection = false;
          // We can set these to false to show the PDF viewer
          useGoogleDrive = false; 
          showMyBooks = false; 
          isLoading = false;
        });

        // Create a dummy items object since we have the ID to download
        final dummyItem = DriveItem(
          id: selectedConfig.id,
          name: selectedConfig.name.endsWith('.book') ? selectedConfig.name : '${selectedConfig.name}.book', // Ensure extension for logic
          mimeType: 'application/zip', // .book is a zip
          isFolder: false,
        );

        await _openBookFromGoogleDrive(dummyItem);
        
      } else {
        // --- FOLDER ACCESS MODE ---
        // Configure breadcrumbs for restricted view
        setState(() {
          driveBreadcrumbs = [
            BreadcrumbItem(name: selectedConfig!.name, path: selectedConfig.id),
          ];
        });

        // Load specific folder
        await _loadGoogleDriveFolder(selectedConfig.id);
        
        setState(() {
          showStorageSelection = false;
          useGoogleDrive = true;
          showMyBooks = false;
          isLoading = false;
        });
      }

    } catch (e) {
      setState(() => isLoading = false);
      _showError('Hata: $e');
      // Show selection again on error
      setState(() => showStorageSelection = true);
    }
  }

  Future<void> _makeFullscreen() async {
    setState(() => isFullScreen = !isFullScreen);
    // Web'de window_manager yok
    if (!kIsWeb) {
      await windowManager.setFullScreen(isFullScreen);
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
          // Check if already recent or ask
          final isRecent = await _recentFileService.isFileRecent(filePath);
          if (!isRecent) {
             // Ask user
             final shouldAdd = await showDialog<bool>(
               context: context,
               builder: (context) => AlertDialog(
                 title: const Text('Kısayol Ekle'),
                 content: const Text(
                     'Bu kitabı "Son Açılanlar" listesine eklemek ister misiniz? Böylece dosyayı tekrar aramak zorunda kalmazsınız.'),
                 actions: [
                   TextButton(
                     onPressed: () => Navigator.pop(context, false),
                     child: const Text('Hayır'),
                   ),
                   FilledButton(
                     onPressed: () => Navigator.pop(context, true),
                     child: const Text('Evet'),
                   ),
                 ],
               ),
             );

             if (shouldAdd == true) {
               await _addRecentFile(filePath, fileName);
             }
          } else {
             // Already in list, just update timestamp/order
             await _addRecentFile(filePath, fileName);
          }
          
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
      print('ZipDecoder failed: $e');
      // Fallback to system unzip (for LZMA/method 14 support)
      if (Platform.isLinux || Platform.isMacOS) {
        try {
          final tempDir = await getTemporaryDirectory();
          final extractDir = Directory(
            '${tempDir.path}/extract_${DateTime.now().millisecondsSinceEpoch}',
          );
          await extractDir.create();

          // Unzip specific files
          final result = await Process.run('unzip', [
            '-o', // overwrite
            zipPath,
            'original.pdf',
            'crop_coordinates.json',
            '-d',
            extractDir.path,
          ]);

          if (result.exitCode != 0) {
            throw Exception('Unzip command failed: ${result.stderr}');
          }

          final pdfFile = File('${extractDir.path}/original.pdf');
          if (!await pdfFile.exists()) {
            if (!mounted) return;
            Navigator.of(context).pop();
            _showError('original.pdf not found in the book file');
            return;
          }

          CropData? cropData;
          final jsonFile = File('${extractDir.path}/crop_coordinates.json');
          if (await jsonFile.exists()) {
            try {
              final jsonString = await jsonFile.readAsString();
              cropData = CropData.fromJsonString(jsonString);
            } catch (e) {
              print('Error parsing crop data: $e');
            }
          }

          if (!mounted) return;
          Navigator.of(context).pop();

          setState(() {
            openTabs.add(
              OpenPdfTab(
                pdfPath: pdfFile.path,
                title: 'Kitap',
                dropboxPath: null,
                cropData: cropData,
                zipFilePath: zipPath,
              ),
            );
            currentTabIndex = openTabs.length - 1;
            showFolderBrowser = false;
          });
          return;
        } catch (unzipError) {
          print('System unzip failed: $unzipError');
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      _showError('Failed to extract PDF from zip: $e');
    }
  }



  void _openFolderBrowser() {
    // For local mode, open file picker directly
    _pickLocalPdf();
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

    if (showMyBooks) {
      return _buildMyBooksView();
    }

    if (!useGoogleDrive) {
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
                child: Stack(
                  children: [
                    Container(
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
                                child: item.thumbnailLink != null
                                    ? ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(14),
                                            ),
                                        child: Image.network(
                                          item.thumbnailLink!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Icon(
                                                  isFolder
                                                      ? Icons.folder_rounded
                                                      : Icons.menu_book_rounded,
                                                  size: 40,
                                                  color: isFolder
                                                      ? Theme.of(
                                                          context,
                                                        ).colorScheme.tertiary
                                                      : Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                );
                                              },
                                        ),
                                      )
                                    : Icon(
                                        isFolder
                                            ? Icons.folder_rounded
                                            : Icons.menu_book_rounded,
                                        size: 40,
                                        color: isFolder
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.tertiary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
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

                      // Item name and actions
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        width: double.infinity,
                        child: Column(
                          children: [
                            Text(
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
                            if (!isFolder) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 28,
                                width: double.infinity,
                                child:
                                    downloadedBooks.any((b) => b.id == item.id)
                                    ? FilledButton.icon(
                                        onPressed:
                                            null, // Disabled if downloaded
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'İndirildi',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        style: FilledButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          backgroundColor: Colors.green,
                                          disabledBackgroundColor: Colors.green
                                              .withValues(alpha: 0.5),
                                          disabledForegroundColor: Colors.white,
                                        ),
                                      )
                                    : OutlinedButton.icon(
                                        onPressed: () => _startDownloadOrQueue(item),
                                        icon: const Icon(
                                          Icons.download_rounded,
                                          size: 14,
                                        ),
                                        label: const Text(
                                          'İndir',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          side: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                    // Download progress overlay
                    if (!isFolder && _downloadingBooks.contains(item.id))
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: CircularProgressIndicator(
                                  value: _downloadProgress[item.id] ?? 0.0,
                                  strokeWidth: 4,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '%${((_downloadProgress[item.id] ?? 0.0) * 100).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'İndiriliyor...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Cancel button
                              OutlinedButton.icon(
                                onPressed: () => _cancelDownload(item.id),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('İptal'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // Default fallback - should never reach here
    return const Center(
      child: Text('Please select a storage option from the menu'),
    );
  }

  Widget _buildMyBooksView() {
    if (downloadedBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz indirilmiş kitap yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Google Drive\'dan kitap indirebilirsiniz',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _selectGoogleDriveStorage,
              icon: const Icon(Icons.cloud_download_rounded),
              label: const Text('Google Drive\'a Git'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: downloadedBooks.length,
      itemBuilder: (context, index) {
        final book = downloadedBooks[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _openDownloadedBook(book),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(book.size / 1024 / 1024).toStringAsFixed(1)} MB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          InkWell(
                            onTap: () => _deleteBook(book),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDownloadedBook(DownloadedBook book) async {
    await _handleZipFile(book.localPath, book.name);
  }

  Future<void> _deleteBook(DownloadedBook book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kitabı Sil'),
        content: Text('${book.name} silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final file = File(book.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        await _bookStorageService.removeBook(book.id);
        await _loadDownloadedBooks();
      } catch (e) {
        _showError('Silme hatası: $e');
      }
    }
  }

  void _cancelDownload(String bookId) {
    print('🚫 Cancelling download for book: $bookId');
    setState(() {
      _downloadCancelFlags[bookId] = true;
      _downloadingBooks.remove(bookId);
      _downloadProgress.remove(bookId);
    });
    
    // Show immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İndirme iptal ediliyor...'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.orange,
      ),
    );
    
    // Process next in queue
    _processQueue();
  }

  void _startDownloadOrQueue(gdrive.DriveItem item) {
    print('📥 Download request for: ${item.name}');
    print('📊 Current downloads: ${_downloadingBooks.length}');
    print('📋 Queue length: ${_downloadQueue.length}');
    
    // Check if already in queue
    if (_downloadQueue.any((i) => i.id == item.id)) {
      _showError('Bu kitap zaten kuyrukta.');
      return;
    }

    // If max concurrent downloads reached, add to queue
    if (_downloadingBooks.length >= _maxConcurrentDownloads) {
      print('⏸️ Max downloads reached, adding to queue');
      setState(() {
        _downloadQueue.add(item);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} indirme kuyruğuna eklendi'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      print('▶️ Starting download immediately');
      _downloadBook(item);
    }
  }

  void _processQueue() {
    if (_downloadQueue.isNotEmpty &&
        _downloadingBooks.length < _maxConcurrentDownloads) {
      final nextItem = _downloadQueue.removeAt(0);
      _downloadBook(nextItem);
    }
  }

  void _removeFromQueue(String bookId) {
    setState(() {
      _downloadQueue.removeWhere((item) => item.id == bookId);
    });
  }

  Future<void> _downloadBook(gdrive.DriveItem item) async {
    if (googleDriveService == null) return;

    // Check if already downloaded
    if (downloadedBooks.any((b) => b.id == item.id)) {
      _showError('Bu kitap zaten indirilmiş.');
      return;
    }

    // Check if already downloading
    if (_downloadingBooks.contains(item.id)) {
      _showError('Bu kitap zaten indiriliyor.');
      return;
    }

    // Mark as downloading
    setState(() {
      _downloadingBooks.add(item.id);
      _downloadProgress[item.id] = 0.0;
      _downloadCancelFlags[item.id] = false;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final fileName = item.name;
      // Download to temp first with progress callback
      final tempFile = await googleDriveService!.downloadFile(
        item.id,
        fileName,
        fileSize: item.size,
        onProgress: (progress) {
          // Check for cancellation
          if (_downloadCancelFlags[item.id] == true) {
            throw Exception('Download cancelled by user');
          }
          
          if (mounted) {
            setState(() {
              _downloadProgress[item.id] = progress;
            });
          }
        },
      );

      // Check if cancelled before moving file
      if (_downloadCancelFlags[item.id] == true) {
        // Delete temp file
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return;
      }

      // Move file to permanent location
      final newPath = '${booksDir.path}/$fileName';
      await tempFile.copy(newPath);
      await tempFile.delete(); // Delete temp file

      final downloadedBook = DownloadedBook(
        id: item.id,
        name: item.name,
        localPath: newPath,
        size: item.size ?? 0,
        downloadedAt: DateTime.now(),
      );

      await _bookStorageService.addBook(downloadedBook);
      await _loadDownloadedBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kitap başarıyla indirildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İndirme iptal edildi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        _showError('İndirme hatası: $e');
      }
    } finally {
      // Remove from downloading state
      if (mounted) {
        setState(() {
          _downloadingBooks.remove(item.id);
          _downloadProgress.remove(item.id);
          _downloadCancelFlags.remove(item.id);
        });
        
        // Process next item in queue
        _processQueue();
      }
    }
  }

  Widget _buildStorageSelectionScreen() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRecentFilesList(),
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
                Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
              ],
              onTap: _selectGoogleDriveStorage,
            ),

            const SizedBox(height: 12),

            // My Books Card - Premium
            _buildPremiumStorageCard(
              icon: Icons.library_books_rounded,
              title: 'Kitaplarım',
              subtitle: 'İndirilen kitaplar',
              gradientColors: [
                Colors.orange,
                Colors.orange.withValues(alpha: 0.7),
              ],
              onTap: _selectMyBooks,
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

  Widget _buildRecentFilesList() {
    if (recentFiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Son Açılanlar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recentFiles.length,
            itemBuilder: (context, index) {
              final file = recentFiles[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Tooltip(
                  message: file.path,
                  child: InkWell(
                    onTap: () async {
                      // Validate if file exists
                      if (await File(file.path).exists()) {
                        _handleZipFile(file.path, file.name);
                      } else {
                        // Ask to remove if not found
                        final remove = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Dosya Bulunamadı'),
                            content: Text(
                                '"${file.name}" dosya yolunda bulunamadı. Listeden kaldırılsın mı?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Hayır'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Evet',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (remove == true) {
                          _removeRecentFile(file.path);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.book_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${file.addedAt.day}.${file.addedAt.month}.${file.addedAt.year}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).disabledColor,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
        const SizedBox(height: 24),
      ],
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
          title: const Text('TechAtlas'),
          actions: [
            // Kalem Modu Butonu (Fatih Kalem tarzı)
            IconButton(
              tooltip: 'Çizim Kalemi',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () async {
                final success = await DrawingPenLauncher.launch();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '✅ Çizim kalemi başlatıldı'
                            : '❌ Çizim kalemi başlatılamadı',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
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
                      useGoogleDrive
                          ? Icons.g_mobiledata_rounded
                          : Icons.folder_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      useGoogleDrive
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
                      onTap: () => _loadGoogleDriveFolder(currentDriveFolderId),
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
        body: Stack(
          children: [
            // Main content
            Column(
              children: [
                if (openTabs.isNotEmpty) _buildTabBar(),
                if ((openTabs.isEmpty || showFolderBrowser) &&
                    !isLoading &&
                    useGoogleDrive)
                  _buildDriveBreadcrumbs(),
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
            // Download queue panel - right side
            if (_downloadQueue.isNotEmpty)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.queue_rounded,
                              size: 24,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'İndirme Kuyruğu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _downloadQueue.clear();
                                });
                              },
                              icon: const Icon(Icons.clear_all_rounded),
                              tooltip: 'Tümünü Temizle',
                              iconSize: 20,
                            ),
                          ],
                        ),
                      ),
                      // Queue items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _downloadQueue.length,
                          itemBuilder: (context, index) {
                            final item = _downloadQueue[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  item.name.replaceAll('.book', ''),
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _removeFromQueue(item.id),
                                  tooltip: 'Kuyruktan Çıkar',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
