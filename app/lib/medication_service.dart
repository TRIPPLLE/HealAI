import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class Medication {
  final String? id;
  final String name;
  final String dosage;
  final String frequency;
  final List<String> scheduledTimes;
  final List<int>? daysOfWeek; // 1=Mon, 7=Sun

  Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.scheduledTimes,
    this.daysOfWeek,
  });

  Map<String, dynamic> toJson(String userId) {
    return {
      "user_id": userId,
      "name": name,
      "dosage": dosage,
      "frequency": frequency,
      "scheduled_times": scheduledTimes,
      "days_of_week": daysOfWeek,
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'],
      name: json['name'],
      dosage: json['dosage'],
      frequency: json['frequency'],
      scheduledTimes: List<String>.from(json['scheduled_times']),
      daysOfWeek: json['days_of_week'] != null ? List<int>.from(json['days_of_week']) : null,
    );
  }
}

class MedicationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  String get backendUrl {
    if (kIsWeb) return "http://127.0.0.1:8000";
    if (Platform.isAndroid || Platform.isIOS) return "http://192.168.68.108:8000";
    return "http://127.0.0.1:8000";
  }

  static Future<void> initializeNotifications() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
    );

    // Request permissions for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Exact alarms for Android 13+ (Required for exact timing)
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  Future<void> addMedication(String userId, Medication med) async {
    final response = await http.post(
      Uri.parse("$backendUrl/medications"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(med.toJson(userId)),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      // Schedule notifications locally
      await scheduleNotifications(med);
    } else {
      throw Exception("Failed to add medication: ${response.body}");
    }
  }

  Future<List<Medication>> getMedications(String userId) async {
    final response = await http.get(Uri.parse("$backendUrl/medications/$userId"))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body)['medications'];
      return list.map((m) => Medication.fromJson(m)).toList();
    } else {
      throw Exception("Failed to fetch medications");
    }
  }

  Future<void> logAdherence(String userId, String medicationId, DateTime scheduledTime, String status, {DateTime? actualTime}) async {
    final response = await http.post(
      Uri.parse("$backendUrl/adherence"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "medication_id": medicationId,
        "scheduled_time": scheduledTime.toIso8601String(),
        "status": status,
        "actual_intake_time": actualTime?.toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception("Failed to log: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> getAnalysis(String userId) async {
    final response = await http.get(Uri.parse("$backendUrl/adherence-analysis/$userId"))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to fetch adherence analysis");
    }
  }

  Future<void> scheduleNotifications(Medication med) async {
    // Default to all days if daysOfWeek is null or empty
    final days = (med.daysOfWeek == null || med.daysOfWeek!.isEmpty) 
        ? [1, 2, 3, 4, 5, 6, 7] 
        : med.daysOfWeek!;
    
    for (var timeStr in med.scheduledTimes) {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      for (var day in days) {
        final tz.TZDateTime scheduledDate = _nextInstanceOfDayAndTime(day, hour, minute);

        await _notificationsPlugin.zonedSchedule(
          // Unique ID for each day-time combination
          (med.name.hashCode + timeStr.hashCode + day).abs(),
          'Time for your medication: ${med.name}',
          'Dosage: ${med.dosage}',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'medication_reminders',
              'Medication Reminders',
              channelDescription: 'Notifications for medication schedules',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: med.id,
        );
      }
    }
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int day, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
