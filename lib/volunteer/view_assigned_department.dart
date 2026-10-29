import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ViewAssignedDepartmentPage extends StatefulWidget {
  const ViewAssignedDepartmentPage({super.key});

  @override
  State<ViewAssignedDepartmentPage> createState() =>
      _ViewAssignedDepartmentPageState();
}

class _ViewAssignedDepartmentPageState
    extends State<ViewAssignedDepartmentPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _deptData;
  String _message = '';
  bool _hasDept = true;

  // Theme Tokens
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
    fetchAssignedDepartment();
  }

  Future<void> fetchAssignedDepartment() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final url = Uri.parse('$baseUrl/myapp/volunteer_view_assigned_department/');

      final response = await http.post(
        url,
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          setState(() {
            _deptData = res['data'];
            _hasDept = true;
            _isLoading = false;
          });
        } else if (res['status'] == 'no_dept') {
          setState(() {
            _hasDept = false;
            _message = res['message'] ?? 'No department assigned';
            _isLoading = false;
          });
        } else {
          setState(() {
            _message = res['message'] ?? 'Failed to load department details';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _message = 'Server response error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk.toUpperCase()) {
      case 'CRITICAL':
        return hot;
      case 'HIGH':
        return amber;
      case 'MODERATE':
        return yellow;
      default:
        return calm;
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
          "Assigned Department",
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: calm, strokeWidth: 2))
          : !_hasDept
          ? _buildEmptyState(_message, Icons.domain_disabled_rounded)
          : _message.isNotEmpty
          ? _buildErrorRetry()
          : RefreshIndicator(
        onRefresh: fetchAssignedDepartment,
        color: calm,
        backgroundColor: ink2,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            _buildDeptHeaderCard(),
            const SizedBox(height: 16),
            _buildSectionTitle("OFFICIAL COMMUNICATION & BASE"),
            _buildContactInfoCard(),
            const SizedBox(height: 18),
            _buildSectionTitle("TACTICAL JURISDICTION / ASSIGNED SECTORS"),
            _buildAssignedAreasList(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeptHeaderCard() {
    final name = _deptData?['department_name'] ?? 'Department Unit';
    final code = _deptData?['department_code'] ?? 'N/A';
    final isActive = _deptData?['is_active'] ?? true;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ink2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: indigo.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: indigo.withOpacity(0.4)),
            ),
            child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: cardElevated,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: line),
                      ),
                      child: Text(
                        "CODE: $code",
                        style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w700, color: textSub),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isActive ? calm : hot).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isActive ? "OPERATIONAL" : "INACTIVE",
                        style: GoogleFonts.sora(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isActive ? calm : hot,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ink2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.support_agent_rounded, "Helpline", _deptData?['helpline_number']),
          _buildInfoRow(Icons.phone_outlined, "Contact", _deptData?['contact_number']),
          _buildInfoRow(Icons.email_outlined, "Email", _deptData?['department_email']),
          _buildInfoRow(Icons.location_city_rounded, "HQ Address", _deptData?['office_address']),
        ],
      ),
    );
  }

  Widget _buildAssignedAreasList() {
    final List areas = _deptData?['assigned_areas'] ?? [];

    if (areas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ink2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: line),
        ),
        child: Center(
          child: Text(
            "No specific zones or sectors assigned under this unit.",
            style: GoogleFonts.sora(fontSize: 12, color: textMuted),
          ),
        ),
      );
    }

    return Column(
      children: areas.map((area) {
        final String risk = (area['current_risk_level'] ?? 'LOW').toString().toUpperCase();
        final Color riskColor = _getRiskColor(risk);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ink2,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      area['name'] ?? 'Zone Area',
                      style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: riskColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      "$risk RISK",
                      style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w800, color: riskColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "${area['city'] ?? ''}, ${area['district'] ?? ''}, ${area['state'] ?? ''} - ${area['pincode'] ?? ''}",
                style: GoogleFonts.sora(fontSize: 11.5, color: textMuted),
              ),
              const Divider(color: line, height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded, size: 15, color: calm),
                      const SizedBox(width: 5),
                      Text(
                        "Capacity Limit: ${area['max_crowd_capacity'] ?? 0} ppl",
                        style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSub),
                      ),
                    ],
                  ),
                  if (area['latitude'] != null && area['longitude'] != null)
                    Text(
                      "${area['latitude']}, ${area['longitude']}",
                      style: GoogleFonts.sora(fontSize: 10, color: textMuted),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: textMuted),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(fontSize: 13, color: textSub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorRetry() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_message, style: GoogleFonts.sora(color: hot, fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: fetchAssignedDepartment,
            style: ElevatedButton.styleFrom(backgroundColor: ink2),
            child: Text("RETRY", style: GoogleFonts.sora(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w700, color: textSub, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: calm),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label, style: GoogleFonts.sora(fontSize: 11.5, color: textMuted)),
          ),
          Expanded(
            child: Text(
              (value != null && value.toString().trim().isNotEmpty) ? value.toString() : 'N/A',
              style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}