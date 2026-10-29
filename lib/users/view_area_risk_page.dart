import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _C {
  static const ink = Color(0xFF0A0F24);
  static const ink2 = Color(0xFF111A3D);
  static const cardElevated = Color(0xFF162252);
  static const line = Color(0x24FFFFFF);

  static const textWhite = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF9AA5C9);
  static const textSub = Color(0xFFB9C2E0);

  static const hot = Color(0xFFFF4D4D);    // Critical / High
  static const amber = Color(0xFFFF9F1C);  // Moderate / Medium
  static const calm = Color(0xFF19C3A6);   // Low / Normal
  static const purple = Color(0xFF8B5CF6);
}

class ViewAreaRiskPage extends StatefulWidget {
  const ViewAreaRiskPage({super.key});

  @override
  State<ViewAreaRiskPage> createState() => _ViewAreaRiskPageState();
}

class _ViewAreaRiskPageState extends State<ViewAreaRiskPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _areaRiskList = [];
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    fetchAreaRisks();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchAreaRisks() async {
    setState(() => _isLoading = true);
    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final response = await http.post(
        Uri.parse('$baseUrl/myapp/user_view_area_risk_level/'),
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _areaRiskList = List<Map<String, dynamic>>.from(data['areas'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching area risks: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRiskColor(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return _C.hot;
      case 'HIGH':
        return const Color(0xFFFF6B4A);
      case 'MODERATE':
      case 'MEDIUM':
        return _C.amber;
      default:
        return _C.calm;
    }
  }

  IconData _getRiskIcon(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        return Icons.warning_amber_rounded;
      case 'MODERATE':
      case 'MEDIUM':
        return Icons.info_outline_rounded;
      default:
        return Icons.verified_user_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.ink,
      appBar: AppBar(
        backgroundColor: _C.ink,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Sector Risk & Directives',
          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _C.calm),
            onPressed: fetchAreaRisks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _C.calm, strokeWidth: 2))
          : _areaRiskList.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: fetchAreaRisks,
        color: _C.calm,
        backgroundColor: _C.ink2,
        child: ListView.builder(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          itemCount: _areaRiskList.length,
          itemBuilder: (context, index) => _buildAreaRiskCard(_areaRiskList[index]),
        ),
      ),
    );
  }

  Widget _buildAreaRiskCard(Map<String, dynamic> area) {
    final String name = area['name'] ?? 'Monitored Sector';
    final String location = "${area['city'] ?? ''}, ${area['district'] ?? ''}";
    final String risk = area['risk_level'] ?? 'LOW';
    final bool isMyArea = area['is_my_area'] == true;
    final List alerts = area['alerts'] ?? [];
    final List anomalies = area['recent_anomalies'] ?? [];
    final Color riskColor = _getRiskColor(risk);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (risk == 'CRITICAL' || isMyArea) ? riskColor.withOpacity(0.55) : _C.line,
          width: isMyArea ? 1.6 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.sora(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (isMyArea) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _C.calm.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "MY SECTOR",
                                style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w700, color: _C.calm),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(location, style: GoogleFonts.sora(fontSize: 12, color: _C.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _pulseCtrl,
                        child: Icon(_getRiskIcon(risk), size: 14, color: riskColor),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "$risk RISK",
                        style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: riskColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Active Emergency Directives
          if (alerts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded, size: 16, color: _C.hot),
                      const SizedBox(width: 6),
                      Text(
                        "ACTIVE EMERGENCY DIRECTIVES (${alerts.length})",
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _C.hot,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...alerts.map((al) => _buildEmergencyAlertCard(al)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Recent Anomaly Detections Section
          if (anomalies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.motion_photos_on_outlined, size: 15, color: _C.purple),
                      const SizedBox(width: 6),
                      Text(
                        "AI ANOMALY LOGS",
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _C.purple,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...anomalies.map((an) => _buildAnomalyTile(an)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (alerts.isEmpty && anomalies.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _C.ink,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 16, color: _C.calm),
                    const SizedBox(width: 8),
                    Text(
                      "No active emergency directives or anomalies reported.",
                      style: GoogleFonts.sora(fontSize: 11.5, color: _C.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmergencyAlertCard(Map<String, dynamic> alert) {
    final String title = alert['title'] ?? 'Emergency Directive';
    final String instructions = alert['public_instructions'] ?? '';
    final String description = alert['description'] ?? '';
    final String dept = alert['department'] ?? 'Control Center';
    final String updated = alert['updated_at'] ?? '';
    final String severity = alert['severity'] ?? 'HIGH';
    final Color sevColor = _getRiskColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1428),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sevColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sevColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severity,
                  style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w800, color: sevColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: GoogleFonts.sora(fontSize: 11.5, color: _C.textSub, height: 1.35)),
          const SizedBox(height: 10),

          // Public evacuation / safety guideline
          if (instructions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.ink,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.amber.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 15, color: _C.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      instructions,
                      style: GoogleFonts.sora(fontSize: 11, color: _C.amber, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Dispatched: $dept", style: GoogleFonts.sora(fontSize: 10, color: _C.textMuted)),
              Text(updated, style: GoogleFonts.sora(fontSize: 10, color: _C.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyTile(Map<String, dynamic> anom) {
    final String type = anom['type'] ?? 'Unknown Movement';
    final double conf = (anom['confidence'] as num?)?.toDouble() ?? 0.0;
    final String cam = anom['camera_identifier'] ?? 'CCTV';
    final String time = anom['detected_at'] ?? '';
    final String snapUrl = anom['frame_snapshot'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.ink,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(type, style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              Text("$conf% Conf", style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: _C.purple)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Node: $cam", style: GoogleFonts.sora(fontSize: 10.5, color: _C.textMuted)),
              Text(time, style: GoogleFonts.sora(fontSize: 10, color: _C.textMuted)),
            ],
          ),
          if (snapUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                snapUrl,
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_moon_outlined, size: 48, color: _C.textMuted),
          const SizedBox(height: 12),
          Text(
            "No Risk Assessment Available",
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            "No areas are currently broadcasting active risk assessments.",
            style: GoogleFonts.sora(fontSize: 12, color: _C.textMuted),
          ),
        ],
      ),
    );
  }
}