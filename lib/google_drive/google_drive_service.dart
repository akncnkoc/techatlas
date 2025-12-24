import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'google_drive_auth.dart';
import 'models.dart';

class GoogleDriveService {
  final GoogleDriveAuth _auth = GoogleDriveAuth();
  bool _isInitialized = false;

  // Initialize the service (this will also initialize auth)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _auth.initialize();
      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  // Check if service is ready
  bool get isReady => _isInitialized && _auth.isAuthenticated;

  // List files and folders in a specific folder (or root if folderId is null)
  Future<List<DriveItem>> listFiles({String? folderId}) async {
    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      final driveApi = _auth.getDriveApi();
      if (driveApi == null) {
        throw Exception(
          'Not authenticated. Service account initialization failed.',
        );
      }

      // Build query to get files
      String query = '';
      if (folderId != null) {
        query = "'$folderId' in parents and trashed = false";
      } else {
        query = "'root' in parents and trashed = false";
      }

      // List files
      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, size, thumbnailLink)',
        orderBy: 'folder,name',
      );

      final allItems =
          fileList.files
              ?.map(
                (file) => DriveItem.fromJson({
                  'id': file.id,
                  'name': file.name,
                  'mimeType': file.mimeType,
                  'size': file.size,
                  'thumbnailLink': file.thumbnailLink,
                }),
              )
              .toList() ??
          [];

      // Separate folders, books, and images
      final folders = allItems.where((item) => item.isFolder).toList();
      final books = allItems.where((item) => item.isBook).toList();
      final images = allItems
          .where(
            (item) =>
                !item.isFolder &&
                !item.isBook &&
                (item.mimeType?.startsWith('image/') ?? false),
          )
          .toList();

      final List<DriveItem> result = [...folders];

      // Match images to books
      for (final book in books) {
        final bookNameWithoutExt = book.name.replaceAll('.book', '');

        // Find matching image (exact match or with _cover suffix)
        final coverImage = images.firstWhere(
          (img) {
            final imgName = img.name.toLowerCase();
            final targetName = bookNameWithoutExt.toLowerCase();
            return imgName.startsWith(targetName);
          },
          orElse: () => DriveItem(id: '', name: '', isFolder: false), // Dummy
        );

        if (coverImage.id.isNotEmpty) {
          result.add(
            DriveItem(
              id: book.id,
              name: book.name,
              isFolder: book.isFolder,
              mimeType: book.mimeType,
              size: book.size,
              thumbnailLink: coverImage.thumbnailLink,
            ),
          );
        } else {
          result.add(book);
        }
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Search for .book files specifically
  Future<List<DriveItem>> searchBookFiles() async {
    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      final driveApi = _auth.getDriveApi();
      if (driveApi == null) {
        throw Exception(
          'Not authenticated. Service account initialization failed.',
        );
      }

      // Search for files ending with .book OR images
      final query =
          "(name contains '.book' or mimeType contains 'image/') and trashed = false";

      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, size, thumbnailLink)',
        orderBy: 'name',
      );

      final allItems =
          fileList.files
              ?.map(
                (file) => DriveItem.fromJson({
                  'id': file.id,
                  'name': file.name,
                  'mimeType': file.mimeType,
                  'size': file.size,
                  'thumbnailLink': file.thumbnailLink,
                }),
              )
              .toList() ??
          [];

      final books = allItems.where((item) => item.isBook).toList();
      final images = allItems.where((item) => !item.isBook).toList();

      // Match images to books
      final List<DriveItem> result = [];
      for (final book in books) {
        final bookNameWithoutExt = book.name.replaceAll('.book', '');

        // Find matching image (exact match or with _cover suffix)
        final coverImage = images.firstWhere(
          (img) {
            final imgName = img.name.toLowerCase();
            final targetName = bookNameWithoutExt.toLowerCase();
            return imgName.startsWith(targetName);
          },
          orElse: () => DriveItem(id: '', name: '', isFolder: false), // Dummy
        );

        if (coverImage.id.isNotEmpty) {
          // Create a new DriveItem with the image's thumbnail
          result.add(
            DriveItem(
              id: book.id,
              name: book.name,
              isFolder: book.isFolder,
              mimeType: book.mimeType,
              size: book.size,
              thumbnailLink:
                  coverImage.thumbnailLink, // Use cover image thumbnail
            ),
          );
        } else {
          result.add(book);
        }
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Download a file from Google Drive
  Future<File> downloadFile(
    String fileId,
    String fileName, {
    int? fileSize,
    Function(double)? onProgress,
  }) async {
    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      final driveApi = _auth.getDriveApi();
      if (driveApi == null) {
        throw Exception(
          'Not authenticated. Service account initialization failed.',
        );
      }

      // Get file content
      final drive.Media media =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      // Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$fileName';
      final file = File(filePath);

      // Write bytes to file with progress tracking
      final bytes = <int>[];
      await for (var chunk in media.stream) {
        bytes.addAll(chunk);
        if (onProgress != null && fileSize != null && fileSize > 0) {
          onProgress(bytes.length / fileSize);
        }
      }
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      rethrow;
    }
  }

  // Download file and return bytes (for web platform)
  Future<Uint8List> downloadFileBytes(String fileId) async {
    try {
      // Ensure service is initialized
      if (!_isInitialized) {
        await initialize();
      }

      final driveApi = _auth.getDriveApi();
      if (driveApi == null) {
        throw Exception(
          'Not authenticated. Service account initialization failed.',
        );
      }

      // Get file content
      final drive.Media media =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      // Collect bytes
      final bytes = <int>[];
      await for (var chunk in media.stream) {
        bytes.addAll(chunk);
      }

      return Uint8List.fromList(bytes);
    } catch (e) {
      rethrow;
    }
  }
}
