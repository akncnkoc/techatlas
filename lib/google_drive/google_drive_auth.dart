import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:googleapis_auth/auth_io.dart' as auth_io;

class GoogleDriveAuth {
  static final GoogleDriveAuth _instance = GoogleDriveAuth._internal();
  factory GoogleDriveAuth() => _instance;
  GoogleDriveAuth._internal();

  auth.AutoRefreshingAuthClient? _authClient;
  bool _isInitialized = false;

  // Initialize service account authentication
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('GoogleDriveAuth already initialized');
      return;
    }

    try {
      debugPrint('🔐 Initializing Google Drive service account auth...');

      // Read service account credentials from assets
      final credentialsJson = await rootBundle.loadString(
        'service_account.json',
      );
      final credentials = auth.ServiceAccountCredentials.fromJson(
        json.decode(credentialsJson),
      );

      debugPrint('✅ Service account email: ${credentials.email}');

      // Create authenticated client with Drive API scopes
      final scopes = [
        drive.DriveApi.driveScope,
        drive.DriveApi.driveFileScope,
        drive.DriveApi.driveReadonlyScope,
      ];

      _authClient = await auth_io.clientViaServiceAccount(credentials, scopes);
      _isInitialized = true;

      debugPrint('✅ Google DriveAuth initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Google Drive Auth: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  // Check if authenticated
  bool get isAuthenticated => _authClient != null && _isInitialized;

  // Get authenticated HTTP client
  auth.AuthClient? getAuthClient() {
    if (!isAuthenticated) {
      debugPrint('⚠️ Not authenticated. Call initialize() first.');
      return null;
    }
    return _authClient;
  }

  // Get Drive API instance
  drive.DriveApi? getDriveApi() {
    final client = getAuthClient();
    if (client == null) {
      debugPrint('⚠️ Cannot create DriveApi: not authenticated');
      return null;
    }
    return drive.DriveApi(client);
  }

  // Close the auth client
  void dispose() {
    _authClient?.close();
    _authClient = null;
    _isInitialized = false;
    debugPrint('🔒 Google Drive Auth disposed');
  }
}
