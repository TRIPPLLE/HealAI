import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class HealthIntelligence {
  final String id;
  final String source;
  final String title;
  final String summary;
  final String riskLevel;
  final String category;
  final String geographicRelevance;
  final String preventiveActions;
  final DateTime publishedAt;
  final Map<String, dynamic> metadata;

  HealthIntelligence({
    required this.id,
    required this.source,
    required this.title,
    required this.summary,
    required this.riskLevel,
    required this.category,
    required this.geographicRelevance,
    required this.preventiveActions,
    required this.publishedAt,
    required this.metadata,
  });

  factory HealthIntelligence.fromJson(Map<String, dynamic> json) {
    return HealthIntelligence(
      id: json['id']?.toString() ?? "",
      source: json['source']?.toString() ?? "Unknown",
      title: json['title']?.toString() ?? "No Title",
      summary: json['summary']?.toString() ?? "",
      riskLevel: json['risk_level']?.toString() ?? "low",
      category: json['category']?.toString() ?? "General",
      geographicRelevance: json['geographic_relevance']?.toString() ?? "Global",
      preventiveActions: json['preventive_actions']?.toString() ?? "",
      publishedAt: json['published_at'] != null 
          ? DateTime.tryParse(json['published_at'].toString()) ?? DateTime.now() 
          : DateTime.now(),
      metadata: json['metadata'] != null 
          ? Map<String, dynamic>.from(json['metadata']) 
          : <String, dynamic>{},
    );
  }
}

class IntelligenceService {
  String get backendUrl {
    if (kIsWeb) return "http://127.0.0.1:8000";
    if (Platform.isAndroid || Platform.isIOS) return "http://192.168.68.108:8000";
    return "http://127.0.0.1:8000";
  }

  Future<List<HealthIntelligence>> getLatestIntelligence() async {
    final response = await http.get(Uri.parse("$backendUrl/intelligence/latest"))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List list = decoded['intelligence'] ?? [];
      return list.map((m) => HealthIntelligence.fromJson(Map<String, dynamic>.from(m as Map))).toList();
    } else {
      throw Exception("Failed to fetch global health intelligence");
    }
  }

  Future<void> triggerRefresh() async {
    await http.post(Uri.parse("$backendUrl/intelligence/refresh"))
        .timeout(const Duration(seconds: 30));
  }
}
