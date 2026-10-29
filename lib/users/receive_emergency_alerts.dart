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

  // Severity Colors
  static const hot = Color(0xFFFF4D4D);    // Critical Red Alert
  static const amber = Color(0xFFFF9F1C);  // High Emergency
  static const yellow = Color(0xFFFFEC78); // Medium Warning
  static const calm = Color(0xFF19C3A6);   // Safe / Resolved
  static const indigo = Color(0xFF4338CA);
}

class ReceiveEmergencyAlertsPage extends StatefulWidget {
  const ReceiveEmergencyAlertsPage({super.key});

  @override
  State<ReceiveEmergencyAlertsPage> createState() =>
      _ReceiveEmergencyAlertsPageState();
}

class _ReceiveEmergencyAlertsPageState
    extends State<ReceiveEmergencyAlertsPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _allAlerts = [];
  List<Map<String, dynamic>> _displayedAlerts = [];

  bool _isLoading = true;
  String _activeFilter = 'ALL'; // 'ALL', 'ACTIVE', 'CRITICAL'

  late final AnimationController _heatCtrl;
  late final AnimationController _beaconCtrl;
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

    _beaconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchAlerts();
    });
  }

  @override
  void dispose() {
    _heatCtrl.dispose();
    _beaconCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // FETCH ALERTS
  // ============================================================

  Future<void> fetchAlerts() async {
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

      final Uri url = Uri.parse('$baseUrl/myapp/user_view_emergency_alerts/');
      final response = await http.post(
        url,
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          setState(() {
            _allAlerts = List<Map<String, dynamic>>.from(data['data']);
            _applyFilter(_activeFilter);
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Failed to load alerts');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching emergency alerts: $e');
      _showMessage('Network connection error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilter(String filterKey) {
    setState(() {
      _activeFilter = filterKey;
      if (filterKey == 'ACTIVE') {
        _displayedAlerts =
            _allAlerts.where((a) => a['status'] == 'ACTIVE').toList();
      } else if (filterKey == 'CRITICAL') {
        _displayedAlerts =
            _allAlerts.where((a) => a['severity'] == 'CRITICAL').toList();
      } else {
        _displayedAlerts = List.from(_allAlerts);
      }
    });
  }

  Future<void> _callHelpline(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      Fluttertoast.showToast(msg: "No emergency hotline listed");
      return;
    }
    final Uri uri = Uri(scheme: 'tel', path: cleaned);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Fluttertoast.showToast(msg: "Cannot launch phone dialer");
    }
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
  // COLOR & SEVERITY PARSERS
  // ============================================================

  Color _getSeverityColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return _C.hot;
      case 'HIGH':
        return _C.amber;
      case 'MEDIUM':
        return _C.yellow;
      default:
        return _C.calm;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return _C.hot;
      case 'UNDER_CONTROL':
        return _C.amber;
      case 'RESOLVED':
        return _C.calm;
      default:
        return _C.textMuted;
    }
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
          // Ambient Warning Heat Glow
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _heatCtrl,
              builder: (context, _) {
                final t = _heatCtrl.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        -0.5 + 0.9 * math.sin(t * math.pi),
                        -0.6 + 0.6 * math.cos(t * math.pi),
                      ),
                      radius: 1.4,
                      colors: const [
                        Color(0x35FF4D4D),
                        Color(0x224338CA),
                        _C.ink,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),

          // Grid Lines
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // App Bar
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
                          'Emergency Alerts',
                          textAlign: TextAlign.center,
                          style: _sora(18, FontWeight.w600, _C.textWhite),
                        ),
                      ),
                      Material(
                        color: _C.calm.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _C.calm.withOpacity(0.3)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: fetchAlerts,
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

                // Filter Pill Selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Broadcasts'),
                      const SizedBox(width: 8),
                      _buildFilterChip('ACTIVE', 'Active Now'),
                      const SizedBox(width: 8),
                      _buildFilterChip('CRITICAL', 'Red Alerts'),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: _C.hot,
                      strokeWidth: 2.2,
                    ),
                  )
                      : _displayedAlerts.isEmpty
                      ? _buildEmptyState()
                      : FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: RefreshIndicator(
                        onRefresh: fetchAlerts,
                        color: _C.hot,
                        backgroundColor: _C.ink2,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                          itemCount: _displayedAlerts.length,
                          itemBuilder: (context, index) {
                            final alert = _displayedAlerts[index];
                            return _buildAlertCard(alert);
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
  // FILTER PILL
  // ============================================================

  Widget _buildFilterChip(String key, String label) {
    final bool isSelected = _activeFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => _applyFilter(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? _C.hot.withOpacity(0.2) : _C.ink2.withOpacity(0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _C.hot : _C.line,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : _C.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ALERT CARD
  // ============================================================

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final String title = alert['title'] ?? 'Emergency Notification';
    final String description = alert['description'] ?? '';
    final String instructions = alert['public_instructions'] ?? '';
    final String severity = alert['severity'] ?? 'HIGH';
    final String status = alert['status'] ?? 'ACTIVE';
    final String areaName = alert['area_name'] ?? 'Zone';
    final String areaCity = alert['area_city'] ?? '';
    final String deptName = alert['department_name'] ?? 'Emergency Unit';
    final String helpline = alert['department_helpline'] ?? '';
    final String time = alert['created_at'] ?? '';
    final bool isUserArea = alert['is_user_area'] == true;

    final Color sevColor = _getSeverityColor(severity);
    final Color statColor = _getStatusColor(status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUserArea ? sevColor.withOpacity(0.65) : _C.line,
          width: isUserArea ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isUserArea ? sevColor.withOpacity(0.2) : Colors.black38,
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sevColor.withOpacity(0.14),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              border: Border(bottom: BorderSide(color: sevColor.withOpacity(0.3))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (status == 'ACTIVE')
                      AnimatedBuilder(
                        animation: _beaconCtrl,
                        builder: (context, _) {
                          return Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sevColor,
                              boxShadow: [
                                BoxShadow(
                                  color: sevColor.withOpacity(0.6 * _beaconCtrl.value),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    Text(
                      '$severity SEVERITY',
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: sevColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: statColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: GoogleFonts.sora(
                      color: statColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Area Target
                Text(
                  title,
                  style: _sora(16, FontWeight.w700, _C.textWhite),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: isUserArea ? _C.calm : _C.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      areaCity.isNotEmpty ? '$areaName, $areaCity' : areaName,
                      style: GoogleFonts.sora(
                        color: isUserArea ? _C.calm : _C.textMuted,
                        fontSize: 12,
                        fontWeight: isUserArea ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (isUserArea) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _C.calm.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Your Area",
                          style: GoogleFonts.sora(
                            color: _C.calm,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),
                Text(
                  description,
                  style: GoogleFonts.sora(
                    color: _C.textSub,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 16),

                // Public Instructions / Evacuation Notice Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _C.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 16, color: _C.yellow),
                          const SizedBox(width: 6),
                          Text(
                            "Safety & Evacuation Guidelines:",
                            style: GoogleFonts.sora(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _C.yellow,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        instructions,
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Department Footer & SOS Helpline Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deptName,
                            style: GoogleFonts.sora(
                              color: _C.textWhite,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            time,
                            style: GoogleFonts.sora(
                              color: _C.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (helpline.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: () => _callHelpline(helpline),
                        icon: const Icon(Icons.phone_in_talk_rounded, size: 15),
                        label: Text(
                          "Call SOS",
                          style: GoogleFonts.sora(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.hot,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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

  // ============================================================
  // EMPTY STATE
  // ============================================================

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
                Icons.notifications_none_rounded,
                size: 32,
                color: _C.calm,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "All Clear · No Active Alerts",
              style: _sora(16, FontWeight.w600, _C.textWhite),
            ),
            const SizedBox(height: 6),
            Text(
              "No emergency warnings have been broadcast for this sector.",
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
// CCTV GRID PAINTER
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