import 'package:health/health.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class HealthService {
  final Health health = Health();
  
  String get backendUrl {
    if (kIsWeb) return "http://94.100.26.132:8000";
    if (Platform.isAndroid || Platform.isIOS) return "http://94.100.26.132:8000";
    return "http://94.100.26.132:8000";
  }

  Future<bool> requestPermissions() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_SESSION,
    ];

    final bool hasPermissions = await health.hasPermissions(types) ?? false;
    if (!hasPermissions) {
      return await health.requestAuthorization(types);
    }
    return true;
  }

  Future<void> openHealthConnectSettings() async {
    try {
      await health.installHealthConnect(); // This opens the Store or the app settings
    } catch (e) {
      debugPrint("Could not open Health Connect: $e");
    }
  }

  Future<Map<String, dynamic>> fetchData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final types = [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.SLEEP_SESSION,
    ];

    // Using named parameters as required by Health 11.1.x
    List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
      types: types,
      startTime: yesterday,
      endTime: now,
    );

    int totalSteps = 0;
    double avgHeartRate = 0;
    int hrCount = 0;
    double totalSleepDuration = 0;

    for (var p in healthData) {
      final value = p.value;
      if (value is NumericHealthValue) {
        if (p.type == HealthDataType.STEPS) {
          totalSteps += value.numericValue.toInt();
        } else if (p.type == HealthDataType.HEART_RATE) {
          avgHeartRate += value.numericValue.toDouble();
          hrCount++;
        }
      } else if (p.type == HealthDataType.SLEEP_SESSION) {
        totalSleepDuration += (p.dateTo.difference(p.dateFrom).inMinutes) / 60.0;
      }
    }

    if (hrCount > 0) avgHeartRate /= hrCount;

    return {
      "steps": totalSteps,
      "heart_rate": avgHeartRate,
      "sleep_hours": totalSleepDuration,
      "timestamp": now.toIso8601String(),
    };
  }

  Future<void> syncWithBackend(String userId, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse("$backendUrl/health-data"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "steps": data["steps"],
        "heart_rate": data["heart_rate"],
        "sleep_hours": data["sleep_hours"],
        "timestamp": data["timestamp"],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to sync with backend: ${response.body}");
    }
  }
}

