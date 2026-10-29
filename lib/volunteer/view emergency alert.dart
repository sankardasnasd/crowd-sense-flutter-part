import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ViewEmergencyAlertsPage extends StatefulWidget {
  const ViewEmergencyAlertsPage({super.key});

  @override
  State<ViewEmergencyAlertsPage> createState() => _ViewEmergencyAlertsPageState();
}

class _ViewEmergencyAlertsPageState extends State<ViewEmergencyAlertsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _alerts = [];
  int _activeCount = 0;
  String _errorMessage = '';
  String _selectedStatusFilter = 'ALL';

  // CrowdSense Dark Tokens
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

  @override
  void initState() {
    super.initState();
    fetchEmergencyAlerts();
  }

  Future<void> fetchEmergencyAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final url = Uri.parse('$baseUrl/myapp/volunteer_view_emergency_alerts/');

      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'status': _selectedStatusFilter,
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          setState(() {
            _alerts = List<Map<String, dynamic>>.from(res['data'] ?? []);
            _activeCount = res['active_count'] ?? 0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = res['message'] ?? 'Failed to load emergency directives';
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

  Color _getSeverityColor(String sev) {
    switch (sev.toUpperCase()) {
      case 'CRITICAL':
        return hot;
      case 'HIGH':
        return amber;
      case 'MEDIUM':
        return yellow;
      default:
        return calm;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return hot;
      case 'UNDER_CONTROL':
        return amber;
      case 'RESOLVED':
        return calm;
      default:
        return textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: ink,
        elevation: 0,
        title: Text(
          "Emergency Directives",
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: calm),
            onPressed: fetchEmergencyAlerts,
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: calm, strokeWidth: 2))
                : _errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage, style: GoogleFonts.sora(color: hot, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: fetchEmergencyAlerts,
                    style: ElevatedButton.styleFrom(backgroundColor: ink2),
                    child: Text("RETRY", style: GoogleFonts.sora(color: Colors.white)),
                  )
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchEmergencyAlerts,
              color: calm,
              backgroundColor: ink2,
              child: _alerts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                itemCount: _alerts.length,
                itemBuilder: (context, index) {
                  return _buildAlertCard(_alerts[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['ALL', 'ACTIVE', 'UNDER_CONTROL', 'RESOLVED'];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _selectedStatusFilter == f;

          return ChoiceChip(
            label: Text(
              f == 'ALL' ? 'ALL ($activeDisplay)' : f.replaceAll('_', ' '),
              style: GoogleFonts.sora(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : textMuted,
              ),
            ),
            selected: isSelected,
            selectedColor: cardElevated,
            backgroundColor: ink2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isSelected ? calm : line),
            ),
            onSelected: (val) {
              if (val) {
                setState(() => _selectedStatusFilter = f);
                fetchEmergencyAlerts();
              }
            },
          );
        },
      ),
    );
  }

  String get activeDisplay => _activeCount > 0 ? "$_activeCount Active" : "${_alerts.length}";

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = (alert['severity'] ?? 'HIGH').toString().toUpperCase();
    final status = (alert['status'] ?? 'ACTIVE').toString().toUpperCase();
    final Color sevColor = _getSeverityColor(severity);
    final Color statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ink2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: severity == 'CRITICAL' ? hot.withOpacity(0.6) : line,
          width: severity == 'CRITICAL' ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badges Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: sevColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sevColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded, size: 12, color: sevColor),
                      const SizedBox(width: 4),
                      Text(
                        "$severity SEVERITY",
                        style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w800, color: sevColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Alert Title
            Text(
              alert['title'] ?? 'Emergency Alert',
              style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),

            // Area and Department Meta
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: calm),
                const SizedBox(width: 4),
                Text(
                  alert['area_name'] ?? 'Assigned Zone',
                  style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSub),
                ),
                const SizedBox(width: 10),
                Text("•", style: GoogleFonts.sora(color: textMuted)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    alert['department_name'] ?? '',
                    style: GoogleFonts.sora(fontSize: 11, color: textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              alert['description'] ?? '',
              style: GoogleFonts.sora(fontSize: 12, color: textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),

            // Public / Safety Directives Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: amber.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.campaign_rounded, size: 17, color: amber),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "SAFETY & EVACUATION DIRECTIVE",
                          style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w800, color: amber),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          alert['public_instructions'] ?? 'Follow crowd dispersal plan.',
                          style: GoogleFonts.sora(fontSize: 11.5, color: Colors.white, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: line, height: 22),

            // Timestamp footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: textMuted),
                    const SizedBox(width: 4),
                    Text(
                      "Issued: ${alert['created_at']}",
                      style: GoogleFonts.sora(fontSize: 10, color: textMuted),
                    ),
                  ],
                ),
                if (status == 'ACTIVE')
                  Text(
                    "ACTION REQUIRED",
                    style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w800, color: hot),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ink2, shape: BoxShape.circle, border: Border.all(color: line)),
            child: const Icon(Icons.check_circle_outline_rounded, size: 40, color: calm),
          ),
          const SizedBox(height: 14),
          Text(
            "No Emergency Directives",
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "All sectors in your jurisdiction are reported normal.",
            style: GoogleFonts.sora(fontSize: 11.5, color: textMuted),
          ),
        ],
      ),
    );
  }
}