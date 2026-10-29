import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// CROWDSENSE DESIGN TOKENS
// ============================================================

class _C {
  static const ink = Color(0xFF0A0F24);
  static const ink2 = Color(0xFF111A3D);
  static const line = Color(0x24FFFFFF);

  static const textWhite = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF9AA5C9);
  static const textSub = Color(0xFFB9C2E0);

  // Thermal Density Ramp
  static const indigo = Color(0xFF4338CA);
  static const hot = Color(0xFFFF4D4D);    // Critical / Overcrowded
  static const amber = Color(0xFFFF9F1C);  // High Density
  static const yellow = Color(0xFFFFEC78); // Moderate
  static const calm = Color(0xFF19C3A6);   // Normal Flow
}

class ViewCrowdDensityPage extends StatefulWidget {
  const ViewCrowdDensityPage({super.key});

  @override
  State<ViewCrowdDensityPage> createState() => _ViewCrowdDensityPageState();
}

class _ViewCrowdDensityPageState extends State<ViewCrowdDensityPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _cameraFeeds = [];
  bool _isLoading = true;
  String _baseUrl = '';
  Timer? _autoRefreshTimer;

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
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();

    final curve = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curve);

    fetchDensityTelemetry();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) fetchDensityTelemetry(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _heatCtrl.dispose();
    _pulseCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchDensityTelemetry({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');
      _baseUrl = baseUrl;

      if (baseUrl.isEmpty || baseUrl == 'null') {
        _showMessage('Server URL is not configured');
        return;
      }

      final Uri url = Uri.parse('$baseUrl/myapp/user_view_crowd_density/');
      final response = await http.post(
        url,
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          setState(() {
            _cameraFeeds = List<Map<String, dynamic>>.from(data['data']);
          });
        } else {
          if (!silent) _showMessage(data['message']?.toString() ?? 'Failed to load density data');
        }
      } else {
        if (!silent) _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching crowd density: $e');
      if (!silent) _showMessage('Network connection error');
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
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

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return _C.hot;
      case 'HIGH':
        return _C.amber;
      case 'MODERATE':
        return _C.yellow;
      case 'NORMAL':
      default:
        return _C.calm;
    }
  }

  String _formatStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'CRITICAL':
        return 'CRITICAL SURGE';
      case 'HIGH':
        return 'HIGH DENSITY';
      case 'MODERATE':
        return 'MODERATE';
      case 'NORMAL':
      default:
        return 'NORMAL FLOW';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.ink,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _heatCtrl,
              builder: (context, _) {
                final t = _heatCtrl.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        -0.5 + 0.8 * math.sin(t * math.pi),
                        -0.6 + 0.6 * math.cos(t * math.pi),
                      ),
                      radius: 1.4,
                      colors: const [
                        Color(0x354338CA),
                        Color(0x22C026D3),
                        _C.ink,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _GridPainter()),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                          'Crowd Density Telemetry',
                          textAlign: TextAlign.center,
                          style: _sora(17, FontWeight.w600, _C.textWhite),
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
                          onTap: () => fetchDensityTelemetry(),
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
                Expanded(
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(color: _C.calm, strokeWidth: 2.2),
                  )
                      : _cameraFeeds.isEmpty
                      ? _buildEmptyState()
                      : FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: RefreshIndicator(
                        onRefresh: () => fetchDensityTelemetry(),
                        color: _C.calm,
                        backgroundColor: _C.ink2,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                          itemCount: _cameraFeeds.length,
                          itemBuilder: (context, index) {
                            final feed = _cameraFeeds[index];
                            return _buildCameraDensityCard(feed);
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

  Widget _buildCameraDensityCard(Map<String, dynamic> feed) {
    final String identifier = feed['camera_identifier'] ?? 'CAM-01';
    final String locationDetails = feed['location_details'] ?? 'Surveillance Point';
    final String area = feed['area_name'] ?? 'Surveillance Area';
    final String city = feed['area_city'] ?? '';
    final String areaRisk = feed['area_risk_level'] ?? 'LOW';
    final String lat = feed['latitude'] ?? '';
    final String lon = feed['longitude'] ?? '';
    final int count = int.tryParse(feed['count']?.toString() ?? '0') ?? 0;
    final int maxCapacity = int.tryParse(feed['max_capacity']?.toString() ?? '500') ?? 500;
    final int loadPercentage = int.tryParse(feed['load_percentage']?.toString() ?? '0') ?? 0;
    final String status = feed['status'] ?? 'NORMAL';
    final String densityMap = feed['density_map'] ?? '';
    final String time = feed['recorded_at'] ?? 'Live';
    final bool isUserArea = feed['is_user_area'] == true;

    final Color statusColor = _getStatusColor(status);
    final String fullImgUrl = densityMap.isNotEmpty
        ? (densityMap.startsWith('http') ? densityMap : '$_baseUrl$densityMap')
        : '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isUserArea ? statusColor.withOpacity(0.55) : _C.line,
          width: isUserArea ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Icon(Icons.videocam_rounded, color: statusColor, size: 22),
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
                              identifier,
                              style: _sora(15.5, FontWeight.w700, _C.textWhite),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUserArea)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _C.calm.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Your Area",
                                style: GoogleFonts.sora(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: _C.calm,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.place_outlined, size: 13, color: isUserArea ? _C.calm : _C.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              city.isNotEmpty ? '$locationDetails · $area ($city)' : '$locationDetails · $area',
                              style: GoogleFonts.sora(
                                fontSize: 11.5,
                                color: isUserArea ? _C.calm : _C.textMuted,
                                fontWeight: isUserArea ? FontWeight.w600 : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Headcount vs Area Max Capacity metrics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF090D20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.line),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ESTIMATED HEADCOUNT",
                            style: GoogleFonts.sora(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _C.textMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "$count",
                                style: GoogleFonts.sora(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                "/ $maxCapacity area limit",
                                style: GoogleFonts.sora(
                                  fontSize: 11,
                                  color: _C.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (context, _) {
                                return Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: statusColor,
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusColor.withOpacity(0.5 * _pulseCtrl.value),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _formatStatusLabel(status),
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Progress Bar Load Line
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(height: 7, width: double.infinity, color: const Color(0xFF162252)),
                        FractionallySizedBox(
                          widthFactor: (loadPercentage / 100).clamp(0.02, 1.0),
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_C.indigo, statusColor],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Area Safe Threshold Load",
                          style: GoogleFonts.sora(fontSize: 10.5, color: _C.textMuted)),
                      Text(
                        "$loadPercentage%",
                        style: GoogleFonts.sora(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Thermal Heatmap Image
          if (fullImgUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.blur_on_rounded, size: 15, color: _C.yellow),
                      const SizedBox(width: 6),
                      Text(
                        "CSRNet AI Density Map (Thermal Output)",
                        style: GoogleFonts.sora(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _C.yellow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: const Color(0xFF090D20),
                      child: Image.network(
                        fullImgUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image_outlined, size: 20, color: _C.textMuted),
                                const SizedBox(width: 6),
                                Text(
                                  "Heatmap stream unavailable",
                                  style: GoogleFonts.sora(fontSize: 12, color: _C.textMuted),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: _C.calm, strokeWidth: 2),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Footer GPS, Recorded Timestamp & Area Risk
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: _C.textMuted),
                    const SizedBox(width: 5),
                    Text(time, style: GoogleFonts.sora(fontSize: 11, color: _C.textMuted)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _C.indigo.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _C.line),
                  ),
                  child: Text(
                    "Sector Risk: $areaRisk",
                    style: GoogleFonts.sora(
                      fontSize: 10.5,
                      color: _C.yellow,
                      fontWeight: FontWeight.w600,
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
              child: const Icon(Icons.videocam_off_outlined, size: 30, color: _C.textMuted),
            ),
            const SizedBox(height: 16),
            Text("No Active Feeds Detected", style: _sora(16, FontWeight.w600, _C.textWhite)),
            const SizedBox(height: 6),
            Text(
              "No CCTV cameras or crowd density logs are currently broadcasting in your area.",
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