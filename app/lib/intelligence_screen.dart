import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'intelligence_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class IntelligenceScreen extends StatefulWidget {
  const IntelligenceScreen({super.key});

  @override
  State<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends State<IntelligenceScreen> {
  final IntelligenceService _service = IntelligenceService();
  List<HealthIntelligence> _alerts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final alerts = await _service.getLatestIntelligence();
      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching intelligence: $e"), backgroundColor: Colors.redAccent),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshData() async {
    try {
      await _service.triggerRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Refresh started in background..."), backgroundColor: Colors.blueAccent),
      );
      // Wait a bit and reload
      await Future.delayed(const Duration(seconds: 3));
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Refresh failed: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch $urlString"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Color _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Global Intelligence",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF6C63FF)),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF)))
          : _alerts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _alerts.length,
                  itemBuilder: (context, index) {
                    return _buildAlertCard(_alerts[index]);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rss_feed_rounded, size: 80, color: Colors.black12),
          const SizedBox(height: 20),
          Text(
            "No Intelligence Data Yet",
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black45),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap refresh to fetch latest WHO/CDC news",
            style: GoogleFonts.outfit(color: Colors.black26),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
            child: const Text("Refresh Now", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(HealthIntelligence alert) {
    final riskColor = _getRiskColor(alert.riskLevel);
    final url = alert.metadata['url'] ?? "";
    
    return GestureDetector(
      onTap: url.isNotEmpty ? () => _launchUrl(url) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: riskColor.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: riskColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Risk Level
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.priority_high_rounded, size: 14, color: riskColor),
                        const SizedBox(width: 4),
                        Text(
                          alert.riskLevel.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: riskColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat.yMMMd().format(alert.publishedAt),
                    style: GoogleFonts.outfit(color: Colors.black26, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    alert.summary,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(color: Colors.black54, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  
                  // Details Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChip(Icons.category_rounded, alert.category, Colors.indigoAccent),
                        const SizedBox(width: 8),
                        _buildChip(Icons.public_rounded, alert.geographicRelevance, Colors.teal),
                        const SizedBox(width: 8),
                        _buildChip(Icons.source_rounded, alert.source, Colors.purpleAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_rounded, size: 18, color: riskColor),
                      const SizedBox(width: 8),
                      Text(
                        "Suggested Actions",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          color: riskColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    alert.preventiveActions,
                    style: GoogleFonts.outfit(color: Colors.black45, fontSize: 13, height: 1.4, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
