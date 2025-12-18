import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher_string.dart';

class UpdateService {
  static const String _owner = 'akncnkoc';
  static const String _repo = 'techatlas';
  static const String _installerName = 'TechAtlas_Setup.exe';

  Future<UpdateInfo?> checkForUpdates() async {
    try {
      // 1. Get current version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$_owner/$_repo/releases/latest',
        ),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        print('❌ Failed to fetch updates: ${response.statusCode}');
        return null;
      }

      final release = jsonDecode(response.body);
      final tagName = release['tag_name'] as String;
      final assets = release['assets'] as List;

      // 3. Compare versions
      // Assumes tag format "v1.0.0" or "1.0.0"
      final cleanRemote = tagName.replaceAll('v', '').split('+')[0];
      final cleanLocal = currentVersion.replaceAll('v', '').split('+')[0];

      print('🔎 Comparing Local: $cleanLocal vs Remote: $cleanRemote');

      if (!_isRemoteNewer(cleanLocal, cleanRemote)) {
        return null; // Local is same or newer
      }

      // 4. Find installer asset
      String? downloadUrl;
      for (final asset in assets) {
        if (asset['name'] == _installerName) {
          downloadUrl = asset['browser_download_url'];
          break;
        }
      }

      // Fallback: If installer not found, use zip or source url?
      // For now, if we can't find the installer, we can't auto-update easily.
      // But we can still return the info so the user can download manually.
      downloadUrl ??= release['html_url'];

      return UpdateInfo(
        version: tagName,
        releaseNotes: release['body'] ?? '',
        downloadUrl: downloadUrl!,
        isInstaller: downloadUrl.endsWith('.exe'),
      );
    } catch (e) {
      print('❌ Update check error: $e');
      return null;
    }
  }

  Future<void> performUpdate(String downloadUrl) async {
    try {
      if (!downloadUrl.endsWith('.exe')) {
        // Fallback: Just open the URL in browser
        await launchUrlString(downloadUrl);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/$_installerName';

      // Download
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Execute
      await Process.start(filePath, []);

      // Exit app
      exit(0);
    } catch (e) {
      print('❌ Update execution error: $e');
      rethrow;
    }
  }

  /// Returns true if [remote] is semantically newer than [local]
  bool _isRemoteNewer(String local, String remote) {
    try {
      final List<int> localParts = local.split('.').map(int.parse).toList();
      final List<int> remoteParts = remote.split('.').map(int.parse).toList();

      final int length = localParts.length > remoteParts.length
          ? localParts.length
          : remoteParts.length;

      for (int i = 0; i < length; i++) {
        final int l = i < localParts.length ? localParts[i] : 0;
        final int r = i < remoteParts.length ? remoteParts[i] : 0;

        if (r > l) return true;
        if (r < l) return false;
      }
      return false; // Equal or local is newer
    } catch (e) {
      print('⚠️ Version parsing failed: $e');
      // Fallback to string comparison if not numeric
      return remote != local;
    }
  }
}

class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final bool isInstaller;

  UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.isInstaller,
  });
}
