import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================
// CROWDSENSE DESIGN TOKENS
// ============================================================

class _C {
  static const ink = Color(0xFF0A0F24);
  static const ink2 = Color(0xFF111A3D);
  static const cardElevated = Color(0xFF162252);
  static const line = Color(0x24FFFFFF);

  static const textWhite = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF9AA5C9);
  static const textSub = Color(0xFFB9C2E0);

  // Thermal Ramp & Alerts
  static const indigo = Color(0xFF4338CA);
  static const magenta = Color(0xFFC026D3);
  static const hot = Color(0xFFFF4D4D);
  static const amber = Color(0xFFFF9F1C);
  static const yellow = Color(0xFFFFEC78);
  static const calm = Color(0xFF19C3A6);
}

class ViewNearbyEmergencyDeptPage extends StatefulWidget {
  const ViewNearbyEmergencyDeptPage({super.key});

  @override
  State<ViewNearbyEmergencyDeptPage> createState() =>
      _ViewNearbyEmergencyDeptPageState();
}

class _ViewNearbyEmergencyDeptPageState
    extends State<ViewNearbyEmergencyDeptPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allDepartments = [];
  List<Map<String, dynamic>> _filteredDepartments = [];

  bool _isLoading = true;

  late final AnimationController _heatCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  TextStyle _sora(double size, FontWeight w, Color c, {double spacing = -0.3}) {
    return GoogleFonts.sora(
      fontSize: size,
      fontWeight: w,
      color: c,
      letterSpacing: spacing,
    );
  }

  @override
  void initState() {
    super.initState();

    _heatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    final curve = CurvedAnimation(
      parent: _enterCtrl,
      curve: Curves.easeOutCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curve);

    _searchController.addListener(_filterDepartments);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchEmergencyDepartments();
    });
  }

  @override
  void dispose() {
    _heatCtrl.dispose();
    _pulseCtrl.dispose();
    _enterCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEARCH / FILTER
  // ============================================================

  void _filterDepartments() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDepartments = List.from(_allDepartments);
      } else {
        _filteredDepartments = _allDepartments.where((d) {
          final name = (d['department_name'] ?? '').toString().toLowerCase();
          final code = (d['department_code'] ?? '').toString().toLowerCase();
          final phone = (d['contact_number'] ?? '').toString().toLowerCase();
          final helpline = (d['helpline_number'] ?? '').toString().toLowerCase();
          final address = (d['office_address'] ?? '').toString().toLowerCase();
          final areas = (d['assigned_areas'] as List? ?? [])
              .map((a) => (a['name'] ?? '').toString().toLowerCase())
              .join(' ');

          return name.contains(query) ||
              code.contains(query) ||
              phone.contains(query) ||
              helpline.contains(query) ||
              address.contains(query) ||
              areas.contains(query);
        }).toList();
      }
    });
  }

  // ============================================================
  // FETCH DEPARTMENTS
  // ============================================================

  Future<void> fetchEmergencyDepartments() async {
    setState(() => _isLoading = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isEmpty || baseUrl == 'null') {
        _showMessage('Server URL is not configured');
        return;
      }

      final Uri url = Uri.parse('$baseUrl/myapp/user_view_emergency_department/');
      final response = await http.post(
        url,
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          setState(() {
            _allDepartments = List<Map<String, dynamic>>.from(data['data']);
            _filteredDepartments = List.from(_allDepartments);
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Failed to load departments');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching departments: $e');
      _showMessage('Network error while connecting to server');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // DIALER & EMAIL LAUNCHERS
  // ============================================================

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      Fluttertoast.showToast(msg: "Invalid contact number");
      return;
    }
    final Uri launchUri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      Fluttertoast.showToast(msg: "Could not open dialer for $phoneNumber");
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.trim().isEmpty) return;
    final Uri launchUri = Uri(scheme: 'mailto', path: email.trim());
    // if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    // } else {
    //   Fluttertoast.showToast(msg: "Could not open email client");
    // }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.sora(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: _C.hot.withOpacity(0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _C.hot),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.ink,
      body: Stack(
        children: [
          // Ambient Radial Background Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _heatCtrl,
              builder: (context, _) {
                final t = _heatCtrl.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        0.4 - 0.8 * math.sin(t * math.pi),
                        -0.5 + 0.6 * math.cos(t * math.pi),
                      ),
                      radius: 1.3,
                      colors: const [
                        Color(0x384338CA),
                        Color(0x20C026D3),
                        _C.ink,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // CCTV Grid Lines
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Material(
                        color: _C.ink2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _C.line),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.maybePop(context),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Emergency Departments',
                          textAlign: TextAlign.center,
                          style: _sora(18, FontWeight.w600, _C.textWhite),
                        ),
                      ),
                      // Refresh Button
                      Material(
                        color: _C.calm.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _C.calm.withOpacity(0.3)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: fetchEmergencyDepartments,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: _C.calm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search & Filter Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _C.ink2.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.line),
                    ),
                    child: TextField(
                      controller: _searchController,
                      cursorColor: _C.calm,
                      style: GoogleFonts.sora(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: "Search department name, code, area...",
                        hintStyle: GoogleFonts.sora(
                          color: _C.textMuted,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: _C.calm,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: _C.textMuted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Department List
                Expanded(
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: _C.calm,
                      strokeWidth: 2.2,
                    ),
                  )
                      : _filteredDepartments.isEmpty
                      ? _buildEmptyState()
                      : FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: RefreshIndicator(
                        onRefresh: fetchEmergencyDepartments,
                        color: _C.calm,
                        backgroundColor: _C.ink2,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                          itemCount: _filteredDepartments.length,
                          itemBuilder: (context, index) {
                            final dept = _filteredDepartments[index];
                            return _buildDepartmentCard(dept);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DEPARTMENT CARD WIDGET
  // ============================================================

  Widget _buildDepartmentCard(Map<String, dynamic> dept) {
    final String name = dept['department_name'] ?? 'Emergency Unit';
    final String code = dept['department_code'] ?? '';
    final String contact = dept['contact_number'] ?? '';
    final String helpline = dept['helpline_number'] ?? '';
    final String email = dept['department_email'] ?? '';
    final String address = dept['office_address'] ?? 'Office address unavailable';
    final bool isUserArea = dept['is_user_area'] == true;
    final List assignedAreas = dept['assigned_areas'] as List? ?? [];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUserArea ? _C.calm.withOpacity(0.5) : _C.line,
          width: isUserArea ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Icon, Dept Name, Code & Priority Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: (isUserArea ? _C.calm : _C.indigo).withOpacity(0.2),
                  border: Border.all(
                    color: (isUserArea ? _C.calm : _C.indigo).withOpacity(0.5),
                  ),
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  color: isUserArea ? _C.calm : _C.yellow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: _sora(16, FontWeight.w700, _C.textWhite),
                          ),
                        ),
                        if (code.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E1636),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _C.line),
                            ),
                            child: Text(
                              code,
                              style: GoogleFonts.sora(
                                color: _C.yellow,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (isUserArea)
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseCtrl,
                            builder: (context, _) {
                              return Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _C.calm,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _C.calm.withOpacity(0.5 * _pulseCtrl.value),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Assigned to Your Registered Area",
                            style: GoogleFonts.sora(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _C.calm,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        "District Quick Response Unit",
                        style: GoogleFonts.sora(
                          color: _C.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Address Information
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF090D20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: _C.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: GoogleFonts.sora(
                      color: _C.textSub,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Assigned Surveillance Areas Chips
          if (assignedAreas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "Operational Sectors Covered:",
              style: GoogleFonts.sora(
                color: _C.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: assignedAreas.map((area) {
                final areaName = area['name'] ?? 'Sector';
                final city = area['city'] ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1636),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _C.line),
                  ),
                  child: Text(
                    city.isNotEmpty ? "$areaName ($city)" : areaName,
                    style: GoogleFonts.sora(
                      color: _C.textWhite,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: _C.line, height: 1),
          const SizedBox(height: 14),

          // Contact Actions
          Row(
            children: [
              // 24/7 Helpline SOS Button
              if (helpline.isNotEmpty)
                Expanded(
                  child: Material(
                    color: _C.hot.withOpacity(0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _C.hot.withOpacity(0.5)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _makePhoneCall(helpline),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.emergency_rounded,
                                color: _C.hot, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              "Helpline",
                              style: GoogleFonts.sora(
                                color: _C.hot,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              if (helpline.isNotEmpty && contact.isNotEmpty)
                const SizedBox(width: 10),

              // Regular Office Phone Call
              if (contact.isNotEmpty)
                Expanded(
                  child: Material(
                    color: _C.calm.withOpacity(0.15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _C.calm.withOpacity(0.4)),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _makePhoneCall(contact),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.call_outlined,
                                color: _C.calm, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              "Call Office",
                              style: GoogleFonts.sora(
                                color: _C.calm,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              if (email.isNotEmpty) ...[
                const SizedBox(width: 10),
                Material(
                  color: _C.cardElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: _C.line),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _sendEmail(email),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.mail_outline_rounded,
                        color: _C.textWhite,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Empty Search / Empty List State
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.ink2,
                border: Border.all(color: _C.line),
              ),
              child: const Icon(
                Icons.local_hospital_outlined,
                size: 32,
                color: _C.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No Emergency Units Found",
              style: _sora(16, FontWeight.w600, _C.textWhite),
            ),
            const SizedBox(height: 6),
            Text(
              "No emergency departments match your search or area filter.",
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(color: _C.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CCTV GRID PAINTER (Consistent with CrowdSense Theme)
// ============================================================

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    const double step = 60.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}