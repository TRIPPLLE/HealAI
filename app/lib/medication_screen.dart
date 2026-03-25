import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'medication_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class MedicationScreen extends StatefulWidget {
  final String userId;
  const MedicationScreen({super.key, required this.userId});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final MedicationService _service = MedicationService();
  List<Medication> _medications = [];
  Map<String, dynamic>? _analysis;
  bool _loading = true;
  List<dynamic> _adherenceLogs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    try {
      // Fetch data in parallel for better performance
      final results = await Future.wait([
        _service.getMedications(widget.userId),
        _service.getAnalysis(widget.userId),
      ]);

      if (mounted) {
        setState(() {
          _medications = results[0] as List<Medication>;
          _analysis = (results[1] as Map<String, dynamic>)['analysis'];
          _adherenceLogs = (results[1] as Map<String, dynamic>)['logs'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error loading medication data: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    List<String> selectedTimes = [];
    List<int> selectedDays = [1, 2, 3, 4, 5, 6, 7]; // Default to all days

    bool dialogLoading = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 30,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add Medication",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildTextField("Medicine Name", nameController),
              const SizedBox(height: 16),
              _buildTextField("Dosage (e.g., 500mg)", dosageController),
              const SizedBox(height: 24),
              Text(
                "Scheduled Times",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ...selectedTimes.map((t) => Chip(
                        label: Text(t, style: const TextStyle(color: Colors.white)),
                        backgroundColor: const Color(0xFF6C63FF),
                        onDeleted: () => setModalState(() => selectedTimes.remove(t)),
                      )),
                  ActionChip(
                    label: const Icon(Icons.add, color: Colors.white),
                    backgroundColor: Colors.white12,
                    onPressed: () async {
                      final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (time != null) {
                        setModalState(() => selectedTimes.add("${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}"));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                "Repeat Days",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][i - 1], style: const TextStyle(color: Colors.white)),
                      selected: selectedDays.contains(i),
                      onSelected: (selected) {
                        setModalState(() {
                          if (selected) {
                            selectedDays.add(i);
                          } else {
                            if (selectedDays.length > 1) selectedDays.remove(i);
                          }
                        });
                      },
                      backgroundColor: Colors.white12,
                      selectedColor: const Color(0xFF6C63FF).withOpacity(0.5),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: dialogLoading ? null : () async {
                    if (nameController.text.isNotEmpty && dosageController.text.isNotEmpty && selectedTimes.isNotEmpty) {
                      setModalState(() => dialogLoading = true);
                      
                      // Determine frequency
                      final frequency = selectedDays.length == 7 ? 'daily' : 'specific_days';
                      
                      final med = Medication(
                        name: nameController.text,
                        dosage: dosageController.text,
                        frequency: frequency,
                        scheduledTimes: selectedTimes,
                        daysOfWeek: selectedDays,
                      );
                      
                      try {
                        await _service.addMedication(widget.userId, med);
                        if (context.mounted) {
                          Navigator.pop(context);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Medication added successfully!")),
                          );
                        }
                      } catch (e) {
                        setModalState(() => dialogLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Failed to save: ${e.toString()}"),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fill in all fields and add at least one time.")),
                      );
                    }
                  },
                  child: dialogLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Save Medication", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF6C63FF))),
        filled: true,
        fillColor: Colors.white10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Medication Pillar", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAnalysisSummary(),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Your Medications",
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6C63FF), size: 30),
                          onPressed: _showAddMedicationDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._medications.map((m) => _buildMedicationCard(m)),
                    if (_medications.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text("No medications added yet.", style: GoogleFonts.outfit(color: Colors.grey)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAnalysisSummary() {
    if (_analysis == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6C63FF).withOpacity(0.8), const Color(0xFF3F3D56).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                "Adherence Insights",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildAnalysisItem("Rate", "${_analysis?['adherence_rate'] ?? '0'}%"),
              _buildAnalysisItem("Missed", "${_analysis?['missed_last_7_days'] ?? '0'}"),
              _buildAnalysisItem("Delay", "${_analysis?['avg_timing_delay_mins'] ?? '0'}m"),
            ],
          ),
          if ((_analysis?['missed_last_7_days'] ?? 0) > 1 || (_analysis?['irregular_timing'] ?? false) == true)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                (_analysis?['missed_last_7_days'] ?? 0) > 1 
                  ? "⚠ Frequent missed doses detected." 
                  : "ℹ Intake timing is inconsistent.",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(label, style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildMedicationCard(Medication med) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF6C63FF).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.medication_rounded, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(med.dosage, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Text(
            _getScheduleSummary(med),
            style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...med.scheduledTimes.map((timeStr) => _buildDoseRow(med, timeStr)),
        ],
      ),
    );
  }

  String _getScheduleSummary(Medication med) {
    if (med.daysOfWeek == null || med.daysOfWeek!.length == 7) return "Every day";
    final days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    final sortedDays = List<int>.from(med.daysOfWeek!)..sort();
    return sortedDays.map((d) => days[d - 1]).join(", ");
  }

  Widget _buildDoseRow(Medication med, String timeStr) {
    final status = _getDoseStatus(med.id!, timeStr);
    
    if (status == "not_scheduled") return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timeStr,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (status == "pending")
            Row(
              children: [
                _buildSmallButton(Icons.check_circle_outline, "Log", Colors.greenAccent, () => _logDose(med, timeStr, 'taken')),
                const SizedBox(width: 8),
                _buildSmallButton(Icons.cancel_outlined, "Missed", Colors.redAccent, () => _logDose(med, timeStr, 'missed')),
              ],
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'taken' ? Colors.greenAccent.withOpacity(0.1) : Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == 'taken' ? "Done" : "Missed",
                    style: GoogleFonts.outfit(
                      color: status == 'taken' ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white60),
                  onPressed: () => _logDose(med, timeStr, status == 'taken' ? 'missed' : 'taken'),
                  tooltip: "Change decision",
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSmallButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  String _getDoseStatus(String medicationId, String timeStr) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Check if medication is even scheduled for today
    if (medicationId.isNotEmpty) {
      final med = _medications.firstWhere((m) => m.id == medicationId);
      if (med.daysOfWeek != null && !med.daysOfWeek!.contains(now.weekday)) {
        return "not_scheduled";
      }
    }

    final log = _adherenceLogs.firstWhere(
      (l) => l['medication_id'] == medicationId && 
             l['scheduled_time'].startsWith(todayStr) && 
             l['scheduled_time'].contains(timeStr),
      orElse: () => null,
    );
    
    if (log == null) return "pending";
    return log['status'];
  }

  Future<void> _logDose(Medication med, String timeStr, String status) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final scheduledDateTime = DateTime.parse("$today $timeStr");

    try {
      await _service.logAdherence(widget.userId, med.id!, scheduledDateTime, status, actualTime: status == 'taken' ? now : null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Dose marked as $status")));
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to log: $e"), backgroundColor: Colors.redAccent));
    }
  }
}
