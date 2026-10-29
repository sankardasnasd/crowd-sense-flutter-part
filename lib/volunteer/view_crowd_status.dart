import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ViewCrowdStatusPage extends StatefulWidget {
  const ViewCrowdStatusPage({super.key});

  @override
  State<ViewCrowdStatusPage> createState() => _ViewCrowdStatusPageState();
}

class _ViewCrowdStatusPageState extends State<ViewCrowdStatusPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _areasData = [];
  List<Map<String, dynamic>> _areasDropdown = [];
  String _selectedAreaId = 'ALL';
  String _errorMessage = '';

  // CrowdSense Dark Theme Tokens
  static const Color ink = Color(0xFF0A0F24);
  static const Color ink2 = Color(0xFF111A3D);
  static const Color cardElevated = Color(0xFF162252);
  static const Color line = Color(0x24FFFFFF);
  static const Color textMuted = Color(0xFF9AA5C9);
  static const Color textSub = Color(0xFFB9C2E0);
  static const Color calm = Color(0xFF19C3A6);
  static const Color hot = Color(0xFFFF4D4D);
  static const Color amber = Color(0xFFFF9F1C);
  static const Color yellow = Color(0xFFFFEC78);
  static const Color indigo = Color(0xFF4338CA);

  @override
  void initState() {
    super.initState();
    fetchCrowdStatus();
  }

  Future<void> fetchCrowdStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final url = Uri.parse('$baseUrl/myapp/volunteer_view_crowd_status/');
      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'area_id': _selectedAreaId,
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          setState(() {
            _areasData = List<Map<String, dynamic>>.from(res['data'] ?? []);
            _areasDropdown =
            List<Map<String, dynamic>>.from(res['areas_dropdown'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = res['message'] ?? 'Failed to load telemetry data.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Server error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error: $e";
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return hot;
      case 'HIGH':
        return amber;
      case 'MODERATE':
      case 'MEDIUM':
        return yellow;
      default:
        return calm;
    }
  }

  void _showImagePreviewDialog(String imgUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ink2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.sora(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: textMuted, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imgUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: ink,
                    alignment: Alignment.center,
                    child: Text("Preview unavailable",
                        style: GoogleFonts.sora(
                            fontSize: 11, color: textMuted)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: ink,
        elevation: 0,
        title: Text(
          "Crowd & Density Maps",
          style: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: calm),
            onPressed: fetchCrowdStatus,
            tooltip: "Refresh Telemetry",
          ),
        ],
      ),
      body: Column(
        children: [
          // Area Filter Dropdown Strip
          _buildAreaDropdownFilter(),

          Expanded(
            child: _isLoading
                ? const Center(
                child:
                CircularProgressIndicator(color: calm, strokeWidth: 2))
                : _errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage,
                      style: GoogleFonts.sora(
                          color: hot, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: fetchCrowdStatus,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ink2),
                    child: Text("RETRY",
                        style: GoogleFonts.sora(color: Colors.white)),
                  )
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchCrowdStatus,
              color: calm,
              backgroundColor: ink2,
              child: _areasData.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                itemCount: _areasData.length,
                itemBuilder: (context, index) {
                  return _buildAreaCard(_areasData[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // AREA DROPDOWN FILTER
  // ============================================================
  Widget _buildAreaDropdownFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: ink2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAreaId,
          isExpanded: true,
          dropdownColor: cardElevated,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: calm),
          items: [
            DropdownMenuItem<String>(
              value: 'ALL',
              child: Text(
                "All Assigned Sectors",
                style: GoogleFonts.sora(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            ..._areasDropdown.map((area) {
              return DropdownMenuItem<String>(
                value: area['id'].toString(),
                child: Text(
                  area['name'] ?? '',
                  style: GoogleFonts.sora(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              );
            }),
          ],
          onChanged: (newVal) {
            if (newVal != null && newVal != _selectedAreaId) {
              setState(() => _selectedAreaId = newVal);
              fetchCrowdStatus();
            }
          },
        ),
      ),
    );
  }

  // ============================================================
  // AREA & TELEMETRY CARD
  // ============================================================
  Widget _buildAreaCard(Map<String, dynamic> area) {
    final String risk =
    (area['current_risk_level'] ?? 'LOW').toString().toUpperCase();
    final Color riskColor = _getStatusColor(risk);
    final double occupancy =
        (area['occupancy_percentage'] as num?)?.toDouble() ?? 0.0;
    final List cameras = area['cameras'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: ink2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Area Name & Risk Pill
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        area['area_name'] ?? 'Sector Checkpoint',
                        style: GoogleFonts.sora(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: riskColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        "$risk RISK",
                        style: GoogleFonts.sora(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: riskColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Live Count & Occupancy
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Live Crowd: ${area['total_live_crowd']} ppl",
                      style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSub),
                    ),
                    Text(
                      "${occupancy.toStringAsFixed(1)}% Capacity (${area['max_capacity']} max)",
                      style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: riskColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Occupancy Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (occupancy / 100).clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: Colors.white.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: line, height: 1),

          // CAMERAS LISTING
          if (cameras.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  "No active CCTV cameras configured for this zone.",
                  style: GoogleFonts.sora(fontSize: 11.5, color: textMuted),
                ),
              ),
            )
          else
            ...cameras.map((cam) => _buildCameraItem(cam)),
        ],
      ),
    );
  }

  Widget _buildCameraItem(Map<String, dynamic> cam) {
    final String densityStatus =
    (cam['density_status'] ?? 'NORMAL').toString().toUpperCase();
    final Color densityColor = _getStatusColor(densityStatus);
    final String heatmapUrl = cam['density_map_url'] ?? '';
    final Map<String, dynamic>? anomaly = cam['latest_anomaly'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cardElevated.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cam Name & Density Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.videocam_outlined, size: 16, color: calm),
                  const SizedBox(width: 6),
                  Text(
                    cam['camera_identifier'] ?? 'CAM_ID',
                    style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: densityColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  "$densityStatus DENSITY",
                  style: GoogleFonts.sora(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: densityColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Text(
            cam['location_details'] ?? '',
            style: GoogleFonts.sora(fontSize: 11, color: textMuted),
          ),
          const SizedBox(height: 10),

          // Real-time Count & Telemetry Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "CSRNet Count: ${cam['crowd_count']} heads",
                style: GoogleFonts.sora(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              Text(
                cam['recorded_at'] ?? '',
                style: GoogleFonts.sora(fontSize: 10, color: textMuted),
              ),
            ],
          ),

          // HEATMAP MAP IMAGE PREVIEW (IF AVAILABLE)
          if (heatmapUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showImagePreviewDialog(
                  heatmapUrl, "Density Heatmap - ${cam['camera_identifier']}"),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.network(
                      heatmapUrl,
                      height: 130,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 70,
                        color: ink,
                        alignment: Alignment.center,
                        child: Text("Heatmap unavailable",
                            style: GoogleFonts.sora(
                                fontSize: 10.5, color: textMuted)),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.fullscreen_rounded,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 3),
                            Text("Heatmap Zoom",
                                style: GoogleFonts.sora(
                                    fontSize: 9, color: Colors.white)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],

          // ANOMALY DETECTION NOTICE (STAMPEDE/TURBULENCE ALERT)
          if (anomaly != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: hot.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hot.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: hot),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Anomaly: ${anomaly['type']} (${anomaly['confidence']}%)",
                          style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: hot),
                        ),
                        Text(
                          "Detected: ${anomaly['detected_at']}",
                          style: GoogleFonts.sora(
                              fontSize: 9.5, color: textSub),
                        ),
                      ],
                    ),
                  ),
                  if (anomaly['frame'] != null &&
                      (anomaly['frame'] as String).isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.image_outlined,
                          size: 18, color: hot),
                      onPressed: () => _showImagePreviewDialog(
                          anomaly['frame'], "Anomaly Frame Capture"),
                    ),
                ],
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
          const Icon(Icons.analytics_outlined, size: 42, color: textMuted),
          const SizedBox(height: 12),
          Text(
            "No Crowd Status Records",
            style: GoogleFonts.sora(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "No telemetry logs or CCTV feeds detected for the selection.",
            style: GoogleFonts.sora(fontSize: 11.5, color: textMuted),
          ),
        ],
      ),
    );
  }
}