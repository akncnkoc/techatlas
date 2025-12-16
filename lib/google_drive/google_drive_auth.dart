import 'dart:convert';
import 'dart:io';

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

      // Read service account credentials
      String credentialsJson;
      
      if (kIsWeb) {
        // Web: Load from assets
        credentialsJson = await rootBundle.loadString('service_account.json');
      } else {
        // Desktop/Mobile: Try to load from executable directory first
        try {
          final exeDir = Platform.resolvedExecutable;
          final exeDirPath = Directory(exeDir).parent.path;
          final serviceAccountFile = File('$exeDirPath/service_account.json');
          
          if (await serviceAccountFile.exists()) {
            debugPrint('📁 Loading service_account.json from: ${serviceAccountFile.path}');
            credentialsJson = await serviceAccountFile.readAsString(encoding: utf8);
          } else {
            // Fallback to assets
            debugPrint('⚠️ service_account.json not found in executable directory, trying assets...');
            credentialsJson = await rootBundle.loadString('service_account.json');
          }
        } catch (e) {
          // Fallback to assets if file reading fails
          debugPrint('⚠️ Failed to load from file, trying assets: $e');
          credentialsJson = await rootBundle.loadString('service_account.json');
        }
      }
      
      final Map<String, dynamic> jsonMap = json.decode(credentialsJson);
      
      // Fix for common Private Key formatting issues
      if (jsonMap.containsKey('private_key')) {
        String key = jsonMap['private_key'] as String;
        if (key.contains(r'\n')) {
          debugPrint('🔧 Fixing escaped newlines in private key...');
          key = key.replaceAll(r'\n', '\n');
        }
        
        // Remove any carriage returns which might cause issues on Windows
        if (key.contains('\r')) {
           debugPrint('🔧 Removing carriage returns from private key...');
           key = key.replaceAll('\r', '');
        }
        
        jsonMap['private_key'] = key;
      }

      final credentials = auth.ServiceAccountCredentials.fromJson(jsonMap);

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
