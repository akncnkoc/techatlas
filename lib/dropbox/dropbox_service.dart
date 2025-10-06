import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DropboxService {
  final String accessToken;
  
  DropboxService(this.accessToken);

  Future<List<DropboxItem>> listFolder(String path) async {
    try {
      print('========================================');
      print('📂 Listing folder: "$path"');
      print('🔑 Token (first 10 chars): ${accessToken.substring(0, min(10, accessToken.length))}...');
      
      final response = await http.post(
        Uri.parse('https://api.dropboxapi.com/2/files/list_folder'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'path': path.isEmpty ? '' : path,
          'recursive': false,
          'include_mounted_folders': true,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out. Check your internet connection.');
        },
      );

      print('📊 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final entries = data['entries'] as List;
        print('✅ Found ${entries.length} items');
        
        for (var entry in entries) {
          final tag = entry['.tag'];
          final name = entry['name'];
          print('   ${tag == 'folder' ? '📁' : '📄'} $name');
        }
        
        print('========================================');
        return entries.map((e) => DropboxItem.fromJson(e)).toList();
      } else {
        print('❌ Error response: ${response.body}');
        print('========================================');
        throw Exception('Failed to list folder (${response.statusCode}): ${response.body}');
      }
    } on SocketException catch (e) {
      print('❌ Socket exception: $e');
      print('========================================');
      throw Exception('Network error: Please check your internet connection');
    } on TimeoutException catch (e) {
      print('❌ Timeout exception: $e');
      print('========================================');
      throw Exception('Request timed out: Please check your internet connection');
    } catch (e) {
      print('❌ Unexpected error: $e');
      print('========================================');
      rethrow;
    }
  }

  Future<File> downloadFile(String path) async {
    try {
      print('⬇️ Downloading file: $path');
      
      final response = await http.post(
        Uri.parse('https://content.dropboxapi.com/2/files/download'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Dropbox-API-Arg': jsonEncode({'path': path}),
        },
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Download timed out');
        },
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final fileName = path.split('/').last;
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        print('✅ File downloaded successfully: ${file.path}');
        return file;
      } else {
        throw Exception('Failed to download file (${response.statusCode}): ${response.body}');
      }
    } on SocketException catch (e) {
      throw Exception('Network error during download: $e');
    } on TimeoutException catch (e) {
      throw Exception('Download timed out: $e');
    } catch (e) {
      print('❌ Download error: $e');
      rethrow;
    }
  }

  Future<Uint8List?> getThumbnail(String path) async {
    try {
      final response = await http.post(
        Uri.parse('https://content.dropboxapi.com/2/files/get_thumbnail_v2'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Dropbox-API-Arg': jsonEncode({
            'resource': {'.tag': 'path', 'path': path},
            'format': 'jpeg',
            'size': 'w256h256',
            'mode': 'strict',
          }),
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('⚠️ Thumbnail error: $e');
    }
    return null;
  }
}

class DropboxItem {
  final String name;
  final String path;
  final bool isFolder;
  final String tag;

  DropboxItem({
    required this.name,
    required this.path,
    required this.isFolder,
    required this.tag,
  });

  factory DropboxItem.fromJson(Map<String, dynamic> json) {
    return DropboxItem(
      name: json['name'],
      path: json['path_display'] ?? json['path_lower'],
      isFolder: json['.tag'] == 'folder',
      tag: json['.tag'],
    );
  }

  bool get isPdf => !isFolder && name.toLowerCase().endsWith('.pdf');
}
