import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_file.dart';

class RecentFileService {
  static const String _key = 'recent_files';

  Future<List<RecentFile>> getRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    if (jsonString == null) {
      return [];
    }
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((e) => RecentFile.fromJson(e)).toList();
  }

  Future<void> addRecentFile(RecentFile file) async {
    final files = await getRecentFiles();
    
    // Check for duplicates by path and remove old one to move it to top/updated
    files.removeWhere((f) => f.path == file.path);
    
    // Add to beginning of list
    files.insert(0, file);
    
    // Limit to 10 recent files
    if (files.length > 10) {
      files.removeLast();
    }
    
    await _saveFiles(files);
  }

  Future<void> removeRecentFile(String path) async {
    final files = await getRecentFiles();
    files.removeWhere((f) => f.path == path);
    await _saveFiles(files);
  }

  Future<bool> isFileRecent(String path) async {
    final files = await getRecentFiles();
    return files.any((f) => f.path == path);
  }

  Future<void> _saveFiles(List<RecentFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(files.map((f) => f.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
