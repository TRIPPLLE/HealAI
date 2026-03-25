import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'health_service.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import 'medication_service.dart';
import 'medication_screen.dart';
import 'intelligence_screen.dart';
import 'ai_chat_screen.dart';
import 'dart:ui';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await MedicationService.initializeNotifications();
  
  await Supabase.initialize(
    url: 'https://xowqknkxnbalzgapohoo.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhvd3Frbmt4bmJhbHpnYXBvaG9vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5Njc2OTEsImV4cCI6MjA4OTU0MzY5MX0.dPUU8ffHfJRD-aiAvj9kkNqH5TSi88dpGOkBSPidGZQ',
    debug: true,
  );
  
  runApp(const HealthMonitorApp());
}

class HealthMonitorApp extends StatelessWidget {
  const HealthMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Health Pillar',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
          surface: const Color(0xFFF8F9FA),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final session = snapshot.data?.session;
        if (session != null) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final HealthService _healthService = HealthService();
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;
  Map<String, dynamic>? _currentData;
  Map<String, dynamic>? _profileData;
  bool _loading = false;
  bool _backendOnline = false;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeController.forward();
    _fetchAndSync();
  }

  Future<void> _fetchAndSync() async {
    if (mounted) setState(() => _loading = true);
    try {
      // Fetch everything in parallel for maximum speed
      await Future.wait([
        _checkBackendStatus(),
        if (_userId != null) _loadUserProfile(),
        _syncHealthData(),
      ]);
    } catch (e) {
      debugPrint("Sync Error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkBackendStatus() async {
    try {
      final check = await http.get(Uri.parse(_healthService.backendUrl)).timeout(const Duration(seconds: 3));
      if (mounted) setState(() => _backendOnline = check.statusCode != 404);
    } catch (_) {
      if (mounted) setState(() => _backendOnline = false);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', _userId!)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() => _profileData = data);
      }
    } catch (e) {
      debugPrint("Profile Loading Error: $e");
    }
  }

  Future<void> _syncHealthData() async {
    try {
      bool authorized = await _healthService.requestPermissions();
      if (authorized && _userId != null) {
        final data = await _healthService.fetchData();
        await _healthService.syncWithBackend(_userId!, data);
        if (mounted) {
          setState(() {
            _currentData = data;
          });
        }
      }
    } catch (e) {
      debugPrint("Health Sync Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Background Mesh Gradient Blobs (Green & Blue)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00C853).withOpacity(0.08), // Vibrant Green
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2979FF).withOpacity(0.06), // Vibrant Blue
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00BFA5).withOpacity(0.07), // Teal
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(),
              ),
            ),
          ),
          
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _fetchAndSync,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildPrimaryStatus(),
                    const SizedBox(height: 32),
                    _buildMedicationQuickLook(),
                    const SizedBox(height: 32),
                    Text(
                      "Vital Stats",
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMetricsGrid(),
                    const SizedBox(height: 32),
                    _buildIntelligenceQuickLook(),
                    const SizedBox(height: 32),
                    _buildAlertsSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF6C63FF),
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: Text("AI Agent", style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMedicationQuickLook() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MedicationScreen(userId: _userId ?? '')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medication_liquid_rounded, color: Color(0xFF6C63FF), size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Medication Manager",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    "Track adherence & reminders",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildIntelligenceQuickLook() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IntelligenceScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFA5).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: const Color(0xFF00BFA5).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.public_rounded, color: Color(0xFF00BFA5), size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Global Health Intelligence",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    "WHO & CDC Risk Insights",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black26, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Greetings,",
                  style: GoogleFonts.outfit(color: Colors.black45, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _backendOnline ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            Text(
              _profileData?['full_name'] ?? "User",
              style: GoogleFonts.outfit(
                color: const Color(0xFF1A1A1A),
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _healthService.openHealthConnectSettings(),
              child: Row(
                children: [
                  const Icon(Icons.settings_input_component, size: 14, color: Color(0xFF6C63FF)),
                  const SizedBox(width: 4),
                  Text(
                    "Manage Sources",
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF6C63FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1A1A1A)),
        ),
      ],
    );
  }

  Widget _buildPrimaryStatus() {
    int steps = _currentData?['steps'] ?? 0;
    double progress = (steps / 10000).clamp(0.0, 1.0);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00F2FE).withOpacity(0.9),
            const Color(0xFF4FACFE).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FACFE).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF6C63FF), size: 18),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$steps",
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      "Daily Goal: 10k",
                      style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 15, spreadRadius: 2),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 75,
                    height: 75,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 9,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      color: Colors.white,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _buildMetricTile(
          "Heart Rate",
          "${_currentData?['heart_rate']?.toStringAsFixed(0) ?? '0'}",
          "bpm",
          Icons.monitor_heart_rounded,
          const [Color(0xFFFF512F), Color(0xFFDD2476)],
        ),
        _buildMetricTile(
          "Sleep",
          "${_currentData?['sleep_hours']?.toStringAsFixed(1) ?? '0'}",
          "hrs",
          Icons.bedtime_rounded,
          const [Color(0xFF00B4DB), Color(0xFF0083B0)],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, String unit, IconData icon, List<Color> gradient) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.02)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradient[0].withOpacity(0.15), gradient[1].withOpacity(0.15)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: gradient[0], size: 22),
            ),
            const Spacer(),
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.black45, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(color: const Color(0xFF1A1A1A), fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.outfit(color: Colors.black26, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    List<Widget> alerts = [];
    if (_currentData != null) {
      if ((_currentData?['heart_rate'] ?? 0) > 100) {
        alerts.add(_buildAlertCard("Critical Heart Rate", "BPM is above 100. Take a rest.", Colors.redAccent));
      }
      if ((_currentData?['sleep_hours'] ?? 8) < 6) {
        alerts.add(_buildAlertCard("Sleep Deficit", "Under 6 hours recorded. Improve rest.", Colors.orangeAccent));
      }
      if ((_currentData?['steps'] ?? 5000) < 3000) {
        alerts.add(_buildAlertCard("Inactive Status", "Step goal not met. Stay active!", Colors.cyanAccent));
      }
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Critical Alerts",
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...alerts,
      ],
    );
  }

  Widget _buildAlertCard(String title, String desc, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  desc,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: const Icon(Icons.dashboard_rounded, color: Color(0xFF6C63FF), size: 30), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.public_rounded, color: Color(0xFF00BFA5), size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const IntelligenceScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.medication_rounded, color: Color(0xFF6C63FF), size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MedicationScreen(userId: _userId ?? ''),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.black26, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoryScreen(userId: _userId ?? '', healthService: _healthService),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_pin_rounded, color: Colors.black26, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(profileData: _profileData),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic>? profileData;
  const ProfileScreen({super.key, this.profileData});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("User Profile", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Color(0xFF6C63FF),
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              profileData?['full_name'] ?? "User",
              style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              user?.email ?? "",
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            _buildInfoTile("Age", "${profileData?['age'] ?? '--'} years"),
            _buildInfoTile("Birth Date", profileData?['birth_date'] ?? '--'),
            _buildInfoTile("User ID", user?.id.substring(0, 8) ?? '--', isLast: true),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.white),
                label: Text("Logout Account", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16)),
          Text(value, style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  final String userId;
  final HealthService healthService;

  const HistoryScreen({super.key, required this.userId, required this.healthService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final response = await http.get(
        Uri.parse("${widget.healthService.backendUrl}/health-history/${widget.userId}"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _history = data['history'];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("History Fetch Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Health History", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                final date = DateTime.parse(item['timestamp']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.event_note, color: Color(0xFF6C63FF)),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMM dd').format(date),
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Steps: ${item['steps']} • HR: ${item['heart_rate']?.toStringAsFixed(0)} • Sleep: ${item['sleep_hours']?.toStringAsFixed(1)}h",
                              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
