import 'package:flutter/material.dart';
import './dropbox/dropbox_service.dart';
import './dropbox/models.dart';
import 'login_page.dart';
import 'viewer/pdf_drawing_viewer_page.dart';
import 'widgets/dropbox_pdf_thumbnail.dart';

class FolderHomePage extends StatefulWidget {
  final String dropboxToken;
  
  const FolderHomePage({super.key, required this.dropboxToken});

  @override
  State<FolderHomePage> createState() => _FolderHomePageState();
}

class _FolderHomePageState extends State<FolderHomePage> {
  late DropboxService dropboxService;
  List<DropboxItem> folders = [];
  List<DropboxItem> pdfs = [];
  List<OpenPdfTab> openTabs = [];
  int currentTabIndex = 0;
  bool isLoading = true;
  bool showFolderBrowser = false; // Yeni PDF seçmek için folder görünümü
  
  List<BreadcrumbItem> breadcrumbs = [
    BreadcrumbItem(name: 'Elif Yayınları', path: ''),
  ];

  @override
  void initState() {
    super.initState();
    dropboxService = DropboxService(widget.dropboxToken);
    _loadFolder('');
  }

  String get currentPath => breadcrumbs.last.path;

  Future<void> _loadFolder(String path) async {
    setState(() => isLoading = true);
    
    try {
      final items = await dropboxService.listFolder(path);
      
      print('=== FOLDER CONTENTS: $path ===');
      print('Total items found: ${items.length}');
      
      final foldersList = items.where((item) => item.isFolder).toList();
      final pdfsList = items.where((item) => item.isPdf).toList();
      
      print('Total folders: ${foldersList.length}');
      print('Total PDFs: ${pdfsList.length}');
      print('=== END ===');
      
      setState(() {
        folders = foldersList;
        pdfs = pdfsList;
        isLoading = false;
      });
      
      if (foldersList.isEmpty && pdfsList.isEmpty) {
        _showError('This folder is empty');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load folder: $e');
      print('❌ Error loading folder: $e');
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
    setState(() {
      showFolderBrowser = true;
    });
  }

  void _closeFolderBrowser() {
    setState(() {
      showFolderBrowser = false;
    });
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

  Future<void> _showOpenPdfDialog() async {
    final Set<String> alreadyOpen = openTabs.map((t) => t.dropboxPath ?? '').toSet();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Dropbox\'tan PDF Aç'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: pdfs.isEmpty
                ? const Center(child: Text('Bu klasörde PDF yok'))
                : ListView.separated(
                    itemCount: pdfs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final pdf = pdfs[index];
                      final isDisabled = alreadyOpen.contains(pdf.path);
                      return ListTile(
                        title: Text(pdf.name),
                        enabled: !isDisabled,
                        trailing: isDisabled
                            ? const Icon(Icons.check, color: Colors.grey)
                            : const Icon(Icons.add),
                        onTap: isDisabled
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                _openPdfFromDropbox(pdf);
                              },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPdfFromDropbox(DropboxItem pdf) async {
    final existingIndex = openTabs.indexWhere((tab) => tab.dropboxPath == pdf.path);
    if (existingIndex != -1) {
      setState(() {
        currentTabIndex = existingIndex;
        showFolderBrowser = false; // Folder browser'ı kapat
      });
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final file = await dropboxService.downloadFile(pdf.path);
      Navigator.of(context).pop();

      setState(() {
        openTabs.add(OpenPdfTab(
          pdfPath: file.path,
          title: pdf.name,
          dropboxPath: pdf.path,
        ));
        currentTabIndex = openTabs.length - 1;
        showFolderBrowser = false; // Folder browser'ı kapat
      });
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Failed to open PDF: $e');
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < breadcrumbs.length; i++) ...[
                    InkWell(
                      onTap: () => _navigateToBreadcrumb(i),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: i == breadcrumbs.length - 1
                            ? BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: Text(
                          breadcrumbs[i].name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == breadcrumbs.length - 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == breadcrumbs.length - 1
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    if (i < breadcrumbs.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
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
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected && !showFolderBrowser
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: isSelected && !showFolderBrowser
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                              color: isSelected && !showFolderBrowser
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
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
                                padding: const EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: isSelected && !showFolderBrowser
                                      ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
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
            color: showFolderBrowser
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _openFolderBrowser,
              child: Container(
                padding: const EdgeInsets.all(11),
                child: Icon(
                  Icons.add_rounded,
                  size: 22,
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
    
    if (folders.isEmpty && pdfs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.folder_off,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Bu klasör boş',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dropbox\'a dosya veya klasör ekleyin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
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
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: folders.length + pdfs.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          final folder = folders[index];
          return GestureDetector(
            onTap: () => _navigateToFolder(folder.path, folder.name),
            child: Card(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.folder_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      folder.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          final pdfIndex = index - folders.length;
          final pdf = pdfs[pdfIndex];
          return GestureDetector(
            onTap: () => _openPdfFromDropbox(pdf),
            child: Card(
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: DropboxPdfThumbnail(
                          key: ValueKey(pdf.path),
                          pdfPath: pdf.path,
                          dropboxService: dropboxService,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    width: double.infinity,
                    child: Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            pdf.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: openTabs.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && openTabs.isNotEmpty) {
          closeTab(currentTabIndex);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Elif Yayınları - Dropbox'),
          actions: [
            if (openTabs.isEmpty && !isLoading)
              IconButton(
                tooltip: 'Yenile',
                icon: const Icon(Icons.refresh),
                onPressed: () => _loadFolder(currentPath),
              ),
            IconButton(
              tooltip: 'Çıkış Yap',
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginPage(onLogin: (_, __) async => false)),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (openTabs.isNotEmpty) _buildTabBar(),
            if ((openTabs.isEmpty || showFolderBrowser) && !isLoading) _buildBreadcrumbs(),
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
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
