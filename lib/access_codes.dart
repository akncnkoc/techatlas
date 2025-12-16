import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

enum ResourceType {
  folder,
  file,
}

class ResourceConfig {
  final String id;
  final String name;
  final ResourceType type;

  const ResourceConfig({
    required this.id,
    required this.name,
    required this.type,
  });

  factory ResourceConfig.fromJson(Map<String, dynamic> json) {
    // Backend returns 'type' or 'resource_type'
    final typeStr = json['type'] ?? json['resource_type'] ?? 'folder';
    
    return ResourceConfig(
      // Backend returns 'drive_id' or 'id'
      id: json['drive_id'] ?? json['id'],
      name: json['name'] ?? json['resource_name'] ?? 'Unknown',
      type: (typeStr == 'file')
          ? ResourceType.file
          : ResourceType.folder,
    );
  }
}

class AccessCodeService {
  // Base URL for the backend
  static const String _baseUrl = 'http://127.0.0.1:8000';
  
  // Fallback local codes (updated to return lists)
  static const Map<String, List<ResourceConfig>> _localFallbackCodes = {};

  /// Verifies the code and returns a LIST of resources
  static Future<List<ResourceConfig>> verifyCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();

    try {
      debugPrint('🔍 Verifying code with backend: $_baseUrl/api/verify-code');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'code': normalizedCode}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          debugPrint('✅ Backend verification successful');
          
          final Map<String, dynamic> responseData = data['data'];
          
          if (responseData.containsKey('resources')) {
             final List<dynamic> resourcesJson = responseData['resources'];
             return resourcesJson.map((json) => ResourceConfig.fromJson(json)).toList();
          } else {
            // Backward compatibility or if API returns single object
             return [ResourceConfig.fromJson(responseData)];
          }
        } else {
          debugPrint('❌ Backend returned failure: ${data['message']}');
          return []; 
        }
      } else {
        debugPrint('⚠️ Backend returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Backend connection failed: $e');
      debugPrint('info: Trying local fallback codes...');
    }

    // Fallback logic
    if (_localFallbackCodes.containsKey(normalizedCode)) {
      debugPrint('✅ Found in local fallback');
      return _localFallbackCodes[normalizedCode]!;
    }

    return [];
  }
}
