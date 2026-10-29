// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:crowdsense/volunteer/report_ground_situation.dart';
// import 'package:crowdsense/volunteer/view%20emergency%20alert.dart';
// import 'package:crowdsense/volunteer/volunteer_change_password.dart';
// import 'package:flutter/material.dart';
// import 'package:geocoding/geocoding.dart' as geo;
// import 'package:google_fonts/google_fonts.dart';
// import 'package:http/http.dart' as http;
// import 'package:location/location.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../login.dart';
// import 'view%20profile.dart';
// import 'view_assigned_department.dart';
// import 'view_crowd_status.dart';
// import 'view_emergency_instructions.dart';
// import 'volunteer_tasks_page.dart';
//
// // ============================================================
// // CROWDSENSE DESIGN PALETTE TOKENS
// // ============================================================
// class _C {
//   static const ink = Color(0xFF0A0F24);
//   static const ink2 = Color(0xFF111A3D);
//   static const cardElevated = Color(0xFF162252);
//   static const line = Color(0x24FFFFFF);
//
//   static const textWhite = Color(0xFFFFFFFF);
//   static const textMuted = Color(0xFF9AA5C9);
//   static const textSub = Color(0xFFB9C2E0);
//
//   // Thermal Palette Ramp
//   static const indigo = Color(0xFF4338CA);
//   static const mag = Color(0xFFC026D3);
//   static const hot = Color(0xFFFF4D4D);
//   static const amber = Color(0xFFFF9F1C);
//   static const yellow = Color(0xFFFFEC78);
//   static const calm = Color(0xFF19C3A6);
//
//   static Color getThermalColor(double t) {
//     t = t.clamp(0.0, 1.0);
//     if (t < 0.25) {
//       return Color.lerp(indigo, mag, t / 0.25)!;
//     } else if (t < 0.55) {
//       return Color.lerp(mag, hot, (t - 0.25) / 0.30)!;
//     } else if (t < 0.80) {
//       return Color.lerp(hot, amber, (t - 0.55) / 0.25)!;
//     } else {
//       return Color.lerp(amber, yellow, (t - 0.80) / 0.20)!;
//     }
//   }
// }
//
// class VolunteerHomePage extends StatefulWidget {
//   const VolunteerHomePage({super.key});
//
//   @override
//   State<VolunteerHomePage> createState() => _VolunteerHomePageState();
// }
//
// class _VolunteerHomePageState extends State<VolunteerHomePage>
//     with TickerProviderStateMixin {
//   bool _isLoading = true;
//
//   // Volunteer Identity & Telemetry Scope
//   String _volunteerName = 'Volunteer Officer';
//   String _departmentName = 'Disaster Management Unit';
//   String _assignedArea = 'Zone C2 - Stadium Terminal';
//   String _areaRiskLevel = 'MODERATE';
//   int _activeCrowdEstimate = 0;
//   int _crowdCapacity = 2000;
//
//   // Live Geocoded GPS Location
//   String _currentLocationName = "Detecting GPS location...";
//
//   Map<String, dynamic>? _activeEmergency;
//   List<Map<String, dynamic>> _assignedTasks = [];
//
//   // Canvas Crowd Particles & Animations
//   late final AnimationController _pulseCtrl;
//   late final AnimationController _simCtrl;
//   final List<_SimParticle> _particles = [];
//
//   @override
//   void initState() {
//     super.initState();
//
//     _pulseCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     )..repeat(reverse: true);
//
//     final rnd = math.Random();
//     for (int i = 0; i < 160; i++) {
//       _particles.add(_SimParticle(
//         x: rnd.nextDouble() * 320,
//         y: rnd.nextDouble() * 120,
//         speed: 0.6 + rnd.nextDouble() * 0.8,
//       ));
//     }
//
//     _simCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 1),
//     )..addListener(_tickParticles)..repeat();
//
//     _fetchAndUpdateLocation();
//     loadVolunteerDashboard();
//   }
//
//   // ============================================================
//   // GPS LOCATION & REVERSE GEOCODING (USING `location`)
//   // ============================================================
//   Future<void> _fetchAndUpdateLocation() async {
//     try {
//       Location location = Location();
//
//       bool serviceEnabled = await location.serviceEnabled();
//       if (!serviceEnabled) {
//         serviceEnabled = await location.requestService();
//         if (!serviceEnabled) {
//           if (mounted) setState(() => _currentLocationName = "GPS service disabled");
//           return;
//         }
//       }
//
//       PermissionStatus permissionGranted = await location.hasPermission();
//       if (permissionGranted == PermissionStatus.denied) {
//         permissionGranted = await location.requestPermission();
//         if (permissionGranted != PermissionStatus.granted) {
//           if (mounted) setState(() => _currentLocationName = "Location permission denied");
//           return;
//         }
//       }
//
//       LocationData locationData = await location.getLocation();
//
//       if (locationData.latitude != null && locationData.longitude != null) {
//         final double lat = locationData.latitude!;
//         final double lon = locationData.longitude!;
//
//         try {
//           List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(lat, lon);
//           if (placemarks.isNotEmpty) {
//             geo.Placemark place = placemarks[0];
//             String resolvedArea = [
//               if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality,
//               if (place.locality != null && place.locality!.isNotEmpty) place.locality,
//               if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
//             ].join(', ');
//
//             if (mounted) {
//               setState(() {
//                 _currentLocationName = resolvedArea.isNotEmpty ? resolvedArea : "${place.name}, ${place.locality}";
//               });
//             }
//           }
//         } catch (geoError) {
//           debugPrint("Geocoding reverse lookup error: $geoError");
//           if (mounted) {
//             setState(() {
//               _currentLocationName = "${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}";
//             });
//           }
//         }
//
//         final SharedPreferences sh = await SharedPreferences.getInstance();
//         String baseUrl = sh.getString('url') ?? '';
//         String lid = sh.getString('lid') ?? '';
//         baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');
//
//         if (baseUrl.isNotEmpty && lid.isNotEmpty) {
//           final response = await http.post(
//             Uri.parse('$baseUrl/myapp/updatelocation/'),
//             body: {
//               'lid': lid,
//               'latitude': lat.toString(),
//               'longitude': lon.toString(),
//             },
//           ).timeout(const Duration(seconds: 10));
//
//           if (response.statusCode == 200) {
//             debugPrint("Location successfully updated on Django backend.");
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint("Error in _fetchAndUpdateLocation: $e");
//     }
//   }
//
//   void _tickParticles() {
//     const gateX = 220.0;
//     const gateY = 60.0;
//     const gap = 16.0;
//     final isBlocked = _areaRiskLevel.toUpperCase() == 'CRITICAL' || _areaRiskLevel.toUpperCase() == 'HIGH';
//
//     for (var p in _particles) {
//       double targetX = (p.stage == 0) ? gateX : 340.0;
//       double targetY = (p.stage == 0) ? gateY : p.exitY;
//
//       double dx = targetX - p.x;
//       double dy = targetY - p.y;
//       double dist = math.sqrt(dx * dx + dy * dy);
//       if (dist < 1) dist = 1;
//
//       double curSpeed = p.speed;
//       if (p.stage == 0 && isBlocked) {
//         double distToGate = math.sqrt(math.pow(gateX - p.x, 2) + math.pow(gateY - p.y, 2));
//         double infl = (1.0 - (distToGate / 80.0)).clamp(0.0, 1.0);
//         curSpeed *= (1.0 - (0.88 * infl));
//       }
//
//       p.x += (dx / dist) * curSpeed;
//       p.y += (dy / dist) * curSpeed + (math.Random().nextDouble() - 0.5) * 0.4;
//
//       if (p.stage == 0) {
//         if (p.x >= gateX - 2) {
//           if ((p.y - gateY).abs() <= gap) {
//             p.stage = 1;
//           } else {
//             p.x = gateX - 2;
//           }
//         }
//       } else {
//         if (p.x > 330) {
//           p.x = -5;
//           p.y = math.Random().nextDouble() * 120;
//           p.stage = 0;
//         }
//       }
//     }
//     if (mounted) setState(() {});
//   }
//
//   @override
//   void dispose() {
//     _pulseCtrl.dispose();
//     _simCtrl.dispose();
//     super.dispose();
//   }
//
//   void _navigateTo(Widget targetPage) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (context) => targetPage),
//     );
//   }
//
//   // ============================================================
//   // API INTEGRATION (FETCH DASHBOARD WITH TODAY'S TASKS)
//   // ============================================================
//   Future<void> loadVolunteerDashboard() async {
//     setState(() => _isLoading = true);
//
//     try {
//       final SharedPreferences sh = await SharedPreferences.getInstance();
//       String baseUrl = sh.getString('url') ?? '';
//       String lid = sh.getString('lid') ?? '';
//       baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');
//
//       if (baseUrl.isNotEmpty) {
//         final response = await http.post(
//           Uri.parse('$baseUrl/myapp/volunteer_dashboard_data/'),
//           body: {'lid': lid},
//         ).timeout(const Duration(seconds: 12));
//
//         if (response.statusCode == 200) {
//           final data = jsonDecode(response.body);
//           if (data['status'] == 'ok') {
//             setState(() {
//               _volunteerName = data['name'] ?? _volunteerName;
//               _departmentName = data['department'] ?? _departmentName;
//               _assignedArea = data['area'] ?? _assignedArea;
//               _areaRiskLevel = (data['risk_level'] ?? 'LOW').toString().toUpperCase();
//               _activeCrowdEstimate = data['crowd_count'] ?? 0;
//               _crowdCapacity = data['max_capacity'] ?? 2000;
//               _activeEmergency = data['active_emergency'];
//               _assignedTasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
//             });
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint("Dashboard data error: $e");
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }
//
//   // ============================================================
//   // LOGOUT (CLEARS PREFERENCES & REDIRECTS TO LOGIN)
//   // ============================================================
//   Future<void> _handleLogout() async {
//     final bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         backgroundColor: _C.ink2,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//           side: const BorderSide(color: _C.line),
//         ),
//         title: Text(
//           "Confirm Logout",
//           style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
//         ),
//         content: Text(
//           "Are you sure you want to end your field session and log out?",
//           style: GoogleFonts.sora(fontSize: 13, color: _C.textSub),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(ctx, false),
//             child: Text("CANCEL", style: GoogleFonts.sora(color: _C.textMuted, fontWeight: FontWeight.w600)),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.pop(ctx, true),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _C.hot,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//             ),
//             child: Text("LOGOUT", style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
//           ),
//         ],
//       ),
//     );
//
//     if (confirm == true) {
//       final SharedPreferences sh = await SharedPreferences.getInstance();
//       await sh.clear();
//       if (!mounted) return;
//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(builder: (context) => const LoginPage()),
//             (route) => false,
//       );
//     }
//   }
//
//   Color _getRiskColor(String level) {
//     switch (level.toUpperCase()) {
//       case 'CRITICAL':
//         return _C.hot;
//       case 'HIGH':
//         return _C.amber;
//       case 'MODERATE':
//       case 'MEDIUM':
//         return _C.yellow;
//       default:
//         return _C.calm;
//     }
//   }
//
//   // ============================================================
//   // BUILD
//   // ============================================================
//   @override
//   Widget build(BuildContext context) {
//     final double capacityLoad = (_crowdCapacity > 0)
//         ? ((_activeCrowdEstimate / _crowdCapacity) * 100).clamp(0.0, 100.0)
//         : 0.0;
//     final Color riskColor = _getRiskColor(_areaRiskLevel);
//
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         backgroundColor: _C.ink,
//         appBar: _buildTopBar(),
//         body: _isLoading
//             ? const Center(child: CircularProgressIndicator(color: _C.calm, strokeWidth: 2))
//             : RefreshIndicator(
//           onRefresh: () async {
//             await _fetchAndUpdateLocation();
//             await loadVolunteerDashboard();
//           },
//           color: _C.calm,
//           backgroundColor: _C.ink2,
//           child: ListView(
//             physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
//             children: [
//               // 1. Live Crowd Flow Radar Canvas
//               _buildLiveRadarCanvas(riskColor),
//               const SizedBox(height: 14),
//
//               // 2. Identity, Live Location Name & Thermal HUD Card
//               InkWell(
//                 borderRadius: BorderRadius.circular(18),
//                 onTap: () => _navigateTo(const VolunteerProfileViewPage()),
//                 child: _buildIdentityHudCard(capacityLoad, riskColor),
//               ),
//               const SizedBox(height: 16),
//
//               // 3. Priority Emergency Alert Directive
//               if (_activeEmergency != null) ...[
//                 _buildEmergencyAlertBanner(),
//                 const SizedBox(height: 16),
//               ],
//
//               // 4. Assigned Tactical Tasks Summary (TODAY'S TASKS)
//               _buildAssignedTasksSection(),
//               const SizedBox(height: 20),
//
//               // 5. Tactical Operational Command Modules
//               _buildSectionHeader("OPERATIONAL MODULES", Icons.dashboard_customize_rounded),
//               const SizedBox(height: 12),
//               _buildActionsGrid(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   PreferredSizeWidget _buildTopBar() {
//     return AppBar(
//       backgroundColor: _C.ink,
//       elevation: 0,
//       automaticallyImplyLeading: false,
//       title: Row(
//         children: [
//           Container(
//             width: 26,
//             height: 26,
//             decoration: const BoxDecoration(
//               shape: BoxShape.circle,
//               gradient: RadialGradient(
//                 colors: [_C.yellow, _C.hot, _C.mag, _C.indigo],
//               ),
//             ),
//           ),
//           const SizedBox(width: 10),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 "CROWDSENSE",
//                 style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.white),
//               ),
//               Text(
//                 "Field Volunteer Command",
//                 style: GoogleFonts.sora(fontSize: 10, color: _C.textMuted),
//               ),
//             ],
//           ),
//         ],
//       ),
//       actions: [
//         Padding(
//           padding: const EdgeInsets.only(right: 14),
//           child: InkWell(
//             onTap: _handleLogout,
//             borderRadius: BorderRadius.circular(10),
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//               decoration: BoxDecoration(
//                 color: _C.hot.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: _C.hot.withOpacity(0.45)),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.logout_rounded, size: 14, color: _C.hot),
//                   const SizedBox(width: 5),
//                   Text(
//                     "LOGOUT",
//                     style: GoogleFonts.sora(
//                       fontSize: 10.5,
//                       fontWeight: FontWeight.w700,
//                       color: _C.hot,
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ============================================================
//   // 1. LIVE RADAR CANVAS (RADAR ANIMATION)
//   // ============================================================
//   Widget _buildLiveRadarCanvas(Color riskColor) {
//     return Container(
//       height: 120,
//       decoration: BoxDecoration(
//         color: _C.ink2,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: _C.line),
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(16),
//         child: Stack(
//           children: [
//             CustomPaint(
//               size: const Size(double.infinity, 120),
//               painter: _VolunteerFlowPainter(
//                 particles: _particles,
//                 riskColor: riskColor,
//                 isSurge: _areaRiskLevel == 'CRITICAL' || _areaRiskLevel == 'HIGH',
//               ),
//             ),
//             Positioned(
//               top: 8,
//               left: 10,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: _C.ink.withOpacity(0.85),
//                   borderRadius: BorderRadius.circular(6),
//                   border: Border.all(color: _C.line),
//                 ),
//                 child: Text(
//                   "LIVE FLOW TELEMETRY · RADAR STREAM",
//                   style: GoogleFonts.sora(fontSize: 9.5, color: _C.textMuted, fontWeight: FontWeight.w600),
//                 ),
//               ),
//             ),
//             Positioned(
//               bottom: 8,
//               right: 10,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: riskColor.withOpacity(0.2),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Text(
//                   _areaRiskLevel == 'CRITICAL' ? "FLOW BOTTLENECK" : "FLOW NORMAL",
//                   style: GoogleFonts.sora(fontSize: 9, fontWeight: FontWeight.w700, color: riskColor),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ============================================================
//   // 2. IDENTITY HUD CARD
//   // ============================================================
//   Widget _buildIdentityHudCard(double capacityLoad, Color riskColor) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: _C.ink2.withOpacity(0.92),
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: _C.line),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.35),
//             blurRadius: 18,
//             offset: const Offset(0, 8),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(_volunteerName, style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
//                     const SizedBox(height: 2),
//                     Text(_departmentName, style: GoogleFonts.sora(fontSize: 11.5, color: _C.textMuted)),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: riskColor.withOpacity(0.18),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: riskColor.withOpacity(0.45)),
//                 ),
//                 child: Row(
//                   children: [
//                     FadeTransition(
//                       opacity: _pulseCtrl,
//                       child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: riskColor)),
//                     ),
//                     const SizedBox(width: 5),
//                     Text(
//                       "$_areaRiskLevel RISK",
//                       style: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w700, color: riskColor),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//
//           // LIVE CURRENT LOCATION NAME STRIP (GEOCODED)
//           const SizedBox(height: 10),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//             decoration: BoxDecoration(
//               color: _C.ink.withOpacity(0.6),
//               borderRadius: BorderRadius.circular(8),
//               border: Border.all(color: _C.line),
//             ),
//             child: Row(
//               children: [
//                 const Icon(Icons.my_location_rounded, size: 14, color: _C.calm),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     "Current: $_currentLocationName",
//                     style: GoogleFonts.sora(
//                       fontSize: 11,
//                       fontWeight: FontWeight.w600,
//                       color: _C.calm,
//                     ),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           const Divider(color: _C.line, height: 20),
//
//           // Area & Capacity telemetry
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   const Icon(Icons.location_on_rounded, size: 15, color: _C.amber),
//                   const SizedBox(width: 5),
//                   Text(_assignedArea, style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: _C.textSub)),
//                 ],
//               ),
//               Text(
//                 "$_activeCrowdEstimate / $_crowdCapacity ppl",
//                 style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//
//           ClipRRect(
//             borderRadius: BorderRadius.circular(6),
//             child: LinearProgressIndicator(
//               value: (capacityLoad / 100).clamp(0.0, 1.0),
//               minHeight: 6,
//               backgroundColor: Colors.white.withOpacity(0.06),
//               valueColor: AlwaysStoppedAnimation<Color>(
//                 _C.getThermalColor(capacityLoad / 100.0),
//               ),
//             ),
//           ),
//           const SizedBox(height: 5),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Text("Zone Occupancy", style: GoogleFonts.sora(fontSize: 10, color: _C.textMuted)),
//               Text(
//                 "${capacityLoad.toStringAsFixed(1)}% Capacity Load",
//                 style: GoogleFonts.sora(fontSize: 10.5, fontWeight: FontWeight.w600, color: riskColor),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ============================================================
//   // 3. EMERGENCY ALERT DIRECTIVE BANNER (NAVIGABLE)
//   // ============================================================
//   Widget _buildEmergencyAlertBanner() {
//     final alert = _activeEmergency!;
//     final String title = alert['title'] ?? 'Emergency Alerts';
//     final String instructions = alert['instructions'] ?? 'Follow field safety protocol';
//
//     return InkWell(
//       borderRadius: BorderRadius.circular(16),
//       onTap: () {
//         _navigateTo(const ViewEmergencyAlertsPage());
//       },
//       child: Container(
//         padding: const EdgeInsets.all(14),
//         decoration: BoxDecoration(
//           color: const Color(0xFF23101E),
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(color: _C.hot.withOpacity(0.55)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(5),
//                   decoration: BoxDecoration(color: _C.hot.withOpacity(0.2), shape: BoxShape.circle),
//                   child: const Icon(Icons.crisis_alert_rounded, size: 16, color: _C.hot),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     title,
//                     style: GoogleFonts.sora(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
//                   ),
//                 ),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                   decoration: BoxDecoration(color: _C.hot, borderRadius: BorderRadius.circular(5)),
//                   child: Text("RED ALERT", style: GoogleFonts.sora(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white)),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Container(
//               padding: const EdgeInsets.all(9),
//               decoration: BoxDecoration(
//                 color: _C.ink,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: _C.line),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.campaign_outlined, size: 15, color: _C.amber),
//                   const SizedBox(width: 7),
//                   Expanded(
//                     child: Text(
//                       instructions,
//                       style: GoogleFonts.sora(fontSize: 11, color: _C.amber, height: 1.35),
//                     ),
//                   ),
//                   const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _C.amber),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ============================================================
//   // 4. ASSIGNED TACTICAL TASKS (TODAY'S TASKS)
//   // ============================================================
//   Widget _buildAssignedTasksSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             // ഇന്നത്തെ ടാസ്‌കുകൾ സൂചിപ്പിക്കുന്ന ഹെഡർ
//             _buildSectionHeader("TODAY'S ASSIGNED TASKS", Icons.assignment_late_outlined),
//             InkWell(
//               onTap: () {
//                 _navigateTo(const VolunteerTasksPage());
//               },
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
//                 child: Row(
//                   children: [
//                     Text(
//                       "${_assignedTasks.length} Today",
//                       style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: _C.amber),
//                     ),
//                     const SizedBox(width: 3),
//                     const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: _C.amber),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 10),
//         if (_assignedTasks.isEmpty)
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: _C.ink2,
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(color: _C.line),
//             ),
//             child: Center(
//               child: Text(
//                 "No active tasks assigned to you for today.",
//                 style: GoogleFonts.sora(fontSize: 12, color: _C.textMuted),
//               ),
//             ),
//           )
//         else
//           ..._assignedTasks.take(2).map((task) => _buildTaskItem(task)),
//       ],
//     );
//   }
//
//   Widget _buildTaskItem(Map<String, dynamic> task) {
//     final String title = task['title'] ?? 'Verify Situation';
//     final String location = task['location'] ?? 'Access Point';
//     final String priority = (task['priority'] ?? 'HIGH').toString().toUpperCase();
//
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(14),
//         onTap: () {
//           _navigateTo(const VolunteerTasksPage());
//         },
//         child: Container(
//           margin: const EdgeInsets.only(bottom: 10),
//           padding: const EdgeInsets.all(13),
//           decoration: BoxDecoration(
//             color: _C.ink2,
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: _C.line),
//           ),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(title, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
//                     const SizedBox(height: 4),
//                     Row(
//                       children: [
//                         const Icon(Icons.place_outlined, size: 12, color: _C.textMuted),
//                         const SizedBox(width: 4),
//                         Text(location, style: GoogleFonts.sora(fontSize: 11, color: _C.textMuted)),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: (priority == 'CRITICAL' ? _C.hot : _C.amber).withOpacity(0.18),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   priority,
//                   style: GoogleFonts.sora(
//                     fontSize: 9.5,
//                     fontWeight: FontWeight.w800,
//                     color: priority == 'CRITICAL' ? _C.hot : _C.amber,
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               const Icon(Icons.chevron_right_rounded, size: 18, color: _C.textMuted),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ============================================================
//   // 5. OPERATIONAL COMMAND TILES
//   // ============================================================
//   Widget _buildActionsGrid() {
//     final List<Map<String, dynamic>> modules = [
//       {
//         'title': 'Report Ground Situation',
//         'subtitle': 'Upload live photos, crowd hazards & alerts',
//         'icon': Icons.add_photo_alternate_rounded,
//         'badge': 'FIELD INTEL',
//         'color': _C.calm,
//         'page': const ReportGroundSituationPage(),
//         'route': '/report_ground_situation',
//       },
//       {
//         'title': 'Crowd & Density Maps',
//         'subtitle': 'Live camera feeds & crowd density status',
//         'icon': Icons.analytics_rounded,
//         'badge': 'HEATMAP',
//         'color': _C.indigo,
//         'page': const ViewCrowdStatusPage(),
//         'route': '/view_crowd_status',
//       },
//       {
//         'title': 'Emergency Directives',
//         'subtitle': 'Evacuation instructions & crowd alerts',
//         'icon': Icons.campaign_rounded,
//         'badge': 'ALERTS',
//         'color': _C.amber,
//         'page': const ViewEmergencyAlertsPage(),
//         'route': '/view_emergency_alerts',
//       },
//       {
//         'title': 'Emergency Instructions',
//         'subtitle': 'Standard operating procedures, Do’s & Don’ts',
//         'icon': Icons.menu_book_rounded,
//         'badge': 'SOP PROTOCOL',
//         'color': const Color(0xFFF59E0B),
//         'page': const ViewEmergencyInstructionsPage(),
//         'route': '/view_emergency_instructions',
//       },
//       {
//         'title': 'Assigned Tactical Tasks',
//         'subtitle': 'Track deployments and checkpoint checkpoints',
//         'icon': Icons.checklist_rtl_rounded,
//         'badge': 'OPERATIONS',
//         'color': _C.mag,
//         'page': const VolunteerTasksPage(),
//         'route': '/volunteer_tasks_page',
//       },
//       {
//         'title': 'Emergency Department',
//         'subtitle': 'Unit details, helpline & assigned areas',
//         'icon': Icons.apartment_rounded,
//         'badge': 'UNIT',
//         'color': const Color(0xFF38BDF8),
//         'page': const ViewAssignedDepartmentPage(),
//         'route': '/view_assigned_department',
//       },
//       {
//         'title': 'Volunteer Profile',
//         'subtitle': 'Duty identity, sector authorization & badge',
//         'icon': Icons.badge_outlined,
//         'badge': 'IDENTITY',
//         'color': _C.textSub,
//         'page': const VolunteerProfileViewPage(),
//         'route': '/volunteer_profile_page',
//       },
//       {
//         'title': 'Change Password',
//         'subtitle': 'Update login credential & security key',
//         'icon': Icons.lock_reset_rounded,
//         'badge': 'SECURITY',
//         'color': const Color(0xFF6366F1),
//         'page': const VolunteerChangePasswordPage(),
//         'route': '/volunteer_change_password',
//       },
//     ];
//
//     return Column(
//       children: modules.map((item) {
//         final Color accent = item['color'] as Color;
//         final Widget? targetPage = item['page'] as Widget?;
//
//         return Container(
//           margin: const EdgeInsets.only(bottom: 11),
//           decoration: BoxDecoration(
//             color: _C.ink2,
//             borderRadius: BorderRadius.circular(16),
//             border: Border.all(color: _C.line),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.25),
//                 blurRadius: 10,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: Material(
//             color: Colors.transparent,
//             child: InkWell(
//               borderRadius: BorderRadius.circular(16),
//               splashColor: accent.withOpacity(0.12),
//               highlightColor: accent.withOpacity(0.06),
//               onTap: () {
//                 if (targetPage != null) {
//                   _navigateTo(targetPage);
//                 } else {
//                   Navigator.pushNamed(context, item['route']);
//                 }
//               },
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 44,
//                       height: 44,
//                       decoration: BoxDecoration(
//                         color: accent.withOpacity(0.14),
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(color: accent.withOpacity(0.35)),
//                       ),
//                       child: Icon(item['icon'] as IconData, size: 22, color: accent),
//                     ),
//                     const SizedBox(width: 13),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(
//                             children: [
//                               Text(
//                                 item['title'] as String,
//                                 style: GoogleFonts.sora(
//                                   fontSize: 13,
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                               const SizedBox(width: 6),
//                               Container(
//                                 padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
//                                 decoration: BoxDecoration(
//                                   color: accent.withOpacity(0.15),
//                                   borderRadius: BorderRadius.circular(4),
//                                 ),
//                                 child: Text(
//                                   item['badge'] as String,
//                                   style: GoogleFonts.sora(
//                                     fontSize: 8,
//                                     fontWeight: FontWeight.w800,
//                                     color: accent,
//                                     letterSpacing: 0.5,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 3),
//                           Text(
//                             item['subtitle'] as String,
//                             style: GoogleFonts.sora(
//                               fontSize: 10.5,
//                               color: _C.textMuted,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ],
//                       ),
//                     ),
//                     Container(
//                       width: 28,
//                       height: 28,
//                       decoration: BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Colors.white.withOpacity(0.05),
//                       ),
//                       child: const Icon(
//                         Icons.arrow_forward_ios_rounded,
//                         size: 11,
//                         color: _C.textSub,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
//
//   Widget _buildSectionHeader(String title, IconData icon) {
//     return Row(
//       children: [
//         Icon(icon, size: 14, color: _C.calm),
//         const SizedBox(width: 6),
//         Text(
//           title,
//           style: GoogleFonts.sora(
//             fontSize: 10.5,
//             fontWeight: FontWeight.w700,
//             color: _C.textSub,
//             letterSpacing: 0.8,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ============================================================
// // CANVAS FLOW PAINTER (RADAR SIMULATION PARTICLES)
// // ============================================================
// class _SimParticle {
//   double x;
//   double y;
//   double speed;
//   int stage;
//   double exitY;
//
//   _SimParticle({
//     required this.x,
//     required this.y,
//     required this.speed,
//     this.stage = 0,
//   }) : exitY = 60.0 + (math.Random().nextDouble() - 0.5) * 40.0;
// }
//
// class _VolunteerFlowPainter extends CustomPainter {
//   final List<_SimParticle> particles;
//   final Color riskColor;
//   final bool isSurge;
//
//   _VolunteerFlowPainter({
//     required this.particles,
//     required this.riskColor,
//     required this.isSurge,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     const gateX = 220.0;
//     const gateY = 60.0;
//     const gap = 16.0;
//
//     final gridPaint = Paint()
//       ..color = Colors.white.withOpacity(0.035)
//       ..strokeWidth = 1.0;
//     for (double x = 0; x < size.width; x += 40) {
//       canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
//     }
//     for (double y = 0; y < size.height; y += 40) {
//       canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
//     }
//
//     final barrierPaint = Paint()
//       ..color = Colors.white.withOpacity(0.5)
//       ..strokeWidth = 2.5
//       ..strokeCap = StrokeCap.round;
//     canvas.drawLine(const Offset(gateX, 0), const Offset(gateX, gateY - gap), barrierPaint);
//     canvas.drawLine(const Offset(gateX, gateY + gap), Offset(gateX, size.height), barrierPaint);
//
//     if (isSurge) {
//       final glowPaint = Paint()
//         ..color = riskColor.withOpacity(0.35)
//         ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
//       canvas.drawCircle(const Offset(gateX - 20, gateY), 35, glowPaint);
//     }
//
//     final dotPaint = Paint()..color = Colors.white.withOpacity(0.75);
//     for (var p in particles) {
//       canvas.drawCircle(Offset(p.x, p.y), 1.4, dotPaint);
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant _VolunteerFlowPainter oldDelegate) => true;
// }
//
//
//
//
//
//
//
//



import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:crowdsense/volunteer/report_ground_situation.dart';
import 'package:crowdsense/volunteer/view%20emergency%20alert.dart';
import 'package:crowdsense/volunteer/volunteer_change_password.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login.dart';
import 'view%20profile.dart';
import 'view_assigned_department.dart';
import 'view_crowd_status.dart';
import 'view_emergency_instructions.dart';
import 'volunteer_tasks_page.dart';

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

  static const indigo = Color(0xFF4338CA);
  static const mag = Color(0xFFC026D3);
  static const hot = Color(0xFFFF4D4D);
  static const amber = Color(0xFFFF9F1C);
  static const yellow = Color(0xFFFFEC78);
  static const calm = Color(0xFF19C3A6);

  static Color getThermalColor(double t) {
    t = t.clamp(0.0, 1.0).toDouble();
    if (t < 0.25) {
      return Color.lerp(indigo, mag, t / 0.25)!;
    } else if (t < 0.55) {
      return Color.lerp(mag, hot, (t - 0.25) / 0.30)!;
    } else if (t < 0.80) {
      return Color.lerp(hot, amber, (t - 0.55) / 0.25)!;
    } else {
      return Color.lerp(amber, yellow, (t - 0.80) / 0.20)!;
    }
  }
}

class VolunteerHomePage extends StatefulWidget {
  const VolunteerHomePage({super.key});

  @override
  State<VolunteerHomePage> createState() => _VolunteerHomePageState();
}

class _VolunteerHomePageState extends State<VolunteerHomePage>
    with TickerProviderStateMixin {
  bool _isLoading = true;

  String _volunteerName = 'Volunteer Officer';
  String _departmentName = 'Disaster Management Unit';
  String _assignedArea = 'Zone C2 - Stadium Terminal';
  String _areaRiskLevel = 'MODERATE';
  int _activeCrowdEstimate = 0;
  int _crowdCapacity = 2000;

  String _currentLocationName = "Detecting GPS location...";

  Map<String, dynamic>? _activeEmergency;
  List<Map<String, dynamic>> _assignedTasks = [];

  late final AnimationController _pulseCtrl; // blink + glow
  late final AnimationController _simCtrl; // crowd simulation tick
  late final AnimationController _bgCtrl; // drifting heat blobs
  late final AnimationController _enterCtrl; // staggered reveal
  late final AnimationController _shineCtrl; // light sweep
  final List<_SimParticle> _particles = [];
  final math.Random _rnd = math.Random();

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 24))
      ..repeat();

    _shineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat();

    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();

    for (int i = 0; i < 190; i++) {
      _particles.add(_SimParticle(
        x: _rnd.nextDouble() * 320,
        y: _rnd.nextDouble() * 120,
        speed: 0.6 + _rnd.nextDouble() * 0.8,
        rnd: _rnd,
      ));
    }

    // Particles tick without rebuilding the whole page; the painter
    // repaints from the same controller.
    _simCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(_tickParticles)
      ..repeat();

    _fetchAndUpdateLocation();
    loadVolunteerDashboard();
  }

  // ============================================================
  // GPS LOCATION & REVERSE GEOCODING
  // ============================================================
  Future<void> _fetchAndUpdateLocation() async {
    try {
      Location location = Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          if (mounted) setState(() => _currentLocationName = "GPS service disabled");
          return;
        }
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          if (mounted) setState(() => _currentLocationName = "Location permission denied");
          return;
        }
      }

      LocationData locationData = await location.getLocation();

      if (locationData.latitude != null && locationData.longitude != null) {
        final double lat = locationData.latitude!;
        final double lon = locationData.longitude!;

        try {
          List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(lat, lon);
          if (placemarks.isNotEmpty) {
            geo.Placemark place = placemarks[0];
            String resolvedArea = [
              if (place.subLocality != null && place.subLocality!.isNotEmpty) place.subLocality,
              if (place.locality != null && place.locality!.isNotEmpty) place.locality,
              if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
            ].join(', ');

            if (mounted) {
              setState(() {
                _currentLocationName = resolvedArea.isNotEmpty ? resolvedArea : "${place.name}, ${place.locality}";
              });
            }
          }
        } catch (geoError) {
          debugPrint("Geocoding reverse lookup error: $geoError");
          if (mounted) {
            setState(() {
              _currentLocationName = "${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}";
            });
          }
        }

        final SharedPreferences sh = await SharedPreferences.getInstance();
        String baseUrl = sh.getString('url') ?? '';
        String lid = sh.getString('lid') ?? '';
        baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

        if (baseUrl.isNotEmpty && lid.isNotEmpty) {
          // Both key styles are sent: the login tracker uses lat/lon,
          // this page originally used latitude/longitude.
          final response = await http.post(
            Uri.parse('$baseUrl/myapp/updatelocation/'),
            body: {
              'lid': lid,
              'lat': lat.toString(),
              'lon': lon.toString(),
              'latitude': lat.toString(),
              'longitude': lon.toString(),
            },
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            debugPrint("Location successfully updated on Django backend.");
          }
        }
      }
    } catch (e) {
      debugPrint("Error in _fetchAndUpdateLocation: $e");
    }
  }

  void _tickParticles() {
    const gateX = 220.0;
    const gateY = 60.0;
    const gap = 16.0;
    final isBlocked = _areaRiskLevel.toUpperCase() == 'CRITICAL' ||
        _areaRiskLevel.toUpperCase() == 'HIGH';

    for (final p in _particles) {
      final double targetX = (p.stage == 0) ? gateX : 340.0;
      final double targetY = (p.stage == 0) ? gateY : p.exitY;

      final double dx = targetX - p.x;
      final double dy = targetY - p.y;
      double dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 1) dist = 1;

      double curSpeed = p.speed;
      if (p.stage == 0 && isBlocked) {
        final double distToGate =
        math.sqrt(math.pow(gateX - p.x, 2) + math.pow(gateY - p.y, 2));
        final double infl = (1.0 - (distToGate / 80.0)).clamp(0.0, 1.0).toDouble();
        curSpeed *= (1.0 - (0.88 * infl));
      }

      p.x += (dx / dist) * curSpeed;
      p.y += (dy / dist) * curSpeed + (_rnd.nextDouble() - 0.5) * 0.4;
      p.y = p.y.clamp(1.0, 119.0).toDouble();

      if (p.stage == 0) {
        if (p.x >= gateX - 2) {
          if ((p.y - gateY).abs() <= gap) {
            p.stage = 1;
          } else {
            p.x = gateX - 2;
          }
        }
      } else {
        if (p.x > 330) {
          p.x = -5;
          p.y = _rnd.nextDouble() * 120;
          p.stage = 0;
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _simCtrl.dispose();
    _bgCtrl.dispose();
    _enterCtrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  void _navigateTo(Widget targetPage) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetPage),
    );
  }

  // ============================================================
  // API: DASHBOARD DATA
  // ============================================================
  Future<void> loadVolunteerDashboard() async {
    setState(() => _isLoading = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isNotEmpty) {
        final response = await http.post(
          Uri.parse('$baseUrl/myapp/volunteer_dashboard_data/'),
          body: {'lid': lid},
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'ok') {
            setState(() {
              _volunteerName = data['name'] ?? _volunteerName;
              _departmentName = data['department'] ?? _departmentName;
              _assignedArea = data['area'] ?? _assignedArea;
              _areaRiskLevel = (data['risk_level'] ?? 'LOW').toString().toUpperCase();
              _activeCrowdEstimate = data['crowd_count'] ?? 0;
              _crowdCapacity = data['max_capacity'] ?? 2000;
              _activeEmergency = data['active_emergency'];
              _assignedTasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Dashboard data error: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _enterCtrl.forward(from: 0);
      }
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.ink2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _C.line),
        ),
        title: Text(
          "Confirm Logout",
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to end your field session and log out?",
          style: GoogleFonts.sora(fontSize: 13, color: _C.textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("CANCEL", style: GoogleFonts.sora(color: _C.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.hot,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("LOGOUT", style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Stop the background location timer started at login.
      Social_intelligent.instance.stop();
      final SharedPreferences sh = await SharedPreferences.getInstance();
      await sh.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  Color _getRiskColor(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return _C.hot;
      case 'HIGH':
        return _C.amber;
      case 'MODERATE':
      case 'MEDIUM':
        return _C.yellow;
      default:
        return _C.calm;
    }
  }

  /// Staggered fade-up reveal (same as the web ".rv" elements)
  Widget _reveal(int i, Widget child) {
    final double start = (i * 0.12).clamp(0.0, 0.7).toDouble();
    final anim = CurvedAnimation(
      parent: _enterCtrl,
      curve: Interval(start, math.min(1.0, start + 0.5),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .06), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final double capacityLoad = (_crowdCapacity > 0)
        ? ((_activeCrowdEstimate / _crowdCapacity) * 100).clamp(0.0, 100.0).toDouble()
        : 0.0;
    final Color riskColor = _getRiskColor(_areaRiskLevel);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _C.ink,
        appBar: _buildTopBar(),
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _HeatBackdropPainter(_bgCtrl)),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _C.ink.withOpacity(.55),
                        _C.ink.withOpacity(.78),
                        _C.ink.withOpacity(.92),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: _C.calm, strokeWidth: 2))
                : RefreshIndicator(
              onRefresh: () async {
                await _fetchAndUpdateLocation();
                await loadVolunteerDashboard();
              },
              color: _C.calm,
              backgroundColor: _C.ink2,
              child: ListView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _reveal(0, _buildLiveRadarCanvas(riskColor)),
                  const SizedBox(height: 14),
                  _reveal(
                    1,
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _navigateTo(const VolunteerProfileViewPage()),
                      child: _buildIdentityHudCard(capacityLoad, riskColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _reveal(2, _buildStatRow(capacityLoad, riskColor)),
                  const SizedBox(height: 16),
                  if (_activeEmergency != null) ...[
                    _reveal(3, _buildEmergencyAlertBanner()),
                    const SizedBox(height: 16),
                  ],
                  _reveal(4, _buildAssignedTasksSection()),
                  const SizedBox(height: 20),
                  _reveal(
                    5,
                    _buildSectionHeader(
                        "OPERATIONAL MODULES", Icons.dashboard_customize_rounded),
                  ),
                  const SizedBox(height: 12),
                  _reveal(6, _buildActionsGrid()),
                  const SizedBox(height: 22),
                  Center(
                    child: Text('Early detection. Faster response.',
                        style: GoogleFonts.sora(
                            color: _C.textMuted.withOpacity(0.8),
                            fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar() {
    return AppBar(
      backgroundColor: _C.ink,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // pulsing heat orb (same as the web logo)
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) => Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [_C.yellow, _C.hot, _C.mag, _C.indigo],
                  stops: [0.0, 0.35, 0.70, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _C.hot.withOpacity(0.15 + 0.25 * _pulseCtrl.value),
                    blurRadius: 10 + 8 * _pulseCtrl.value,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "CrowdSense",
                style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: Colors.white),
              ),
              Text(
                "Field Volunteer Command",
                style: GoogleFonts.sora(fontSize: 10, color: _C.textMuted),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _C.hot.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.hot.withOpacity(0.45)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded, size: 14, color: _C.hot),
                  const SizedBox(width: 5),
                  Text(
                    "LOGOUT",
                    style: GoogleFonts.sora(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _C.hot,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GLASS CONTAINER
  // ============================================================
  Widget _glass({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 20,
    Color? border,
    Color? tint,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: (tint ?? _C.ink).withOpacity(0.74),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border ?? _C.line),
          ),
          child: child,
        ),
      ),
    );
  }

  // ============================================================
  // 1. LIVE THERMAL FLOW CANVAS
  // ============================================================
  Widget _buildLiveRadarCanvas(Color riskColor) {
    final bool surge = _areaRiskLevel == 'CRITICAL' || _areaRiskLevel == 'HIGH';
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: _C.ink2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _VolunteerFlowPainter(
                  repaint: _simCtrl,
                  particles: _particles,
                  riskColor: riskColor,
                  isSurge: surge,
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.ink.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _pulseCtrl,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: _C.hot),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "LIVE FLOW · THERMAL STREAM",
                      style: GoogleFonts.sora(
                          fontSize: 9.5,
                          color: _C.textSub,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: riskColor.withOpacity(0.5)),
                ),
                child: Text(
                  surge ? "SUDDEN ACCUMULATION" : "FLOW NORMAL",
                  style: GoogleFonts.sora(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: riskColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 2. IDENTITY HUD CARD
  // ============================================================
  Widget _buildIdentityHudCard(double capacityLoad, Color riskColor) {
    final String initial =
    _volunteerName.trim().isEmpty ? 'V' : _volunteerName.trim()[0].toUpperCase();

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [_C.yellow, _C.hot, _C.mag, _C.indigo],
                    stops: [0.0, 0.35, 0.70, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: _C.hot.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: GoogleFonts.sora(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_volunteerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(_departmentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sora(
                            fontSize: 11.5, color: _C.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _pulseCtrl,
                      child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: riskColor)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$_areaRiskLevel RISK",
                      style: GoogleFonts.sora(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: riskColor),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Live GPS strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1636),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded, size: 14, color: _C.calm),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Current: $_currentLocationName",
                    style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _C.calm),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // HUD rows
          _hudRow(Icons.location_on_rounded, "Assigned area", _assignedArea),
          _hudRow(Icons.groups_rounded, "People in zone",
              "$_activeCrowdEstimate / $_crowdCapacity"),

          const SizedBox(height: 12),

          // Thermal occupancy bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: Colors.white.withOpacity(0.07),
                ),
                FractionallySizedBox(
                  widthFactor: (capacityLoad / 100).clamp(0.0, 1.0).toDouble(),
                  child: Container(
                    height: 6,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _C.indigo,
                        _C.mag,
                        _C.hot,
                        _C.amber,
                        _C.yellow,
                      ], stops: [
                        0,
                        .3,
                        .55,
                        .8,
                        1
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Low density",
                  style: GoogleFonts.sora(fontSize: 10, color: _C.textMuted)),
              Text(
                "${capacityLoad.toStringAsFixed(1)}% capacity load",
                style: GoogleFonts.sora(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _C.getThermalColor(capacityLoad / 100.0)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hudRow(IconData icon, String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _C.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _C.amber),
          const SizedBox(width: 8),
          Text(k, style: GoogleFonts.sora(color: _C.textMuted, fontSize: 12)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK STATS
  // ============================================================
  Widget _buildStatRow(double capacityLoad, Color riskColor) {
    return Row(
      children: [
        Expanded(
            child: _statTile(Icons.groups_rounded, "$_activeCrowdEstimate",
                "People", _C.indigo)),
        const SizedBox(width: 10),
        Expanded(
            child: _statTile(Icons.speed_rounded,
                "${capacityLoad.toStringAsFixed(0)}%", "Peak load", riskColor)),
        const SizedBox(width: 10),
        Expanded(
            child: _statTile(Icons.assignment_turned_in_rounded,
                "${_assignedTasks.length}", "Tasks today", _C.calm)),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: accent),
          ),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: Colors.white)),
          const SizedBox(height: 1),
          Text(label,
              style: GoogleFonts.sora(fontSize: 10.5, color: _C.textMuted)),
        ],
      ),
    );
  }

  // ============================================================
  // 3. EMERGENCY ALERT BANNER (pulsing glow)
  // ============================================================
  Widget _buildEmergencyAlertBanner() {
    final alert = _activeEmergency!;
    final String title = alert['title'] ?? 'Emergency Alerts';
    final String instructions = alert['instructions'] ?? 'Follow field safety protocol';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _C.hot.withOpacity(0.10 + 0.22 * _pulseCtrl.value),
                blurRadius: 10 + 12 * _pulseCtrl.value,
                spreadRadius: 1 + 2 * _pulseCtrl.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _navigateTo(const ViewEmergencyAlertsPage()),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF23101E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.hot.withOpacity(0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: _C.hot.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.crisis_alert_rounded,
                        size: 16, color: _C.hot),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.sora(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: _C.hot, borderRadius: BorderRadius.circular(6)),
                    child: Text("RED ALERT",
                        style: GoogleFonts.sora(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _C.ink,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_outlined,
                        size: 15, color: _C.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        instructions,
                        style: GoogleFonts.sora(
                            fontSize: 11, color: _C.amber, height: 1.4),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: _C.amber),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 4. TODAY'S TASKS
  // ============================================================
  Widget _buildAssignedTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader("TODAY'S ASSIGNED TASKS", Icons.assignment_late_outlined),
            InkWell(
              onTap: () => _navigateTo(const VolunteerTasksPage()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      "${_assignedTasks.length} Today",
                      style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _C.amber),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: _C.amber),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_assignedTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _C.ink2.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.line),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: _C.calm, size: 22),
                const SizedBox(height: 6),
                Text(
                  "No active tasks assigned to you for today.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(fontSize: 12, color: _C.textMuted),
                ),
              ],
            ),
          )
        else
          ..._assignedTasks.take(2).map((task) => _buildTaskItem(task)),
      ],
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final String title = task['title'] ?? 'Verify Situation';
    final String location = task['location'] ?? 'Access Point';
    final String priority = (task['priority'] ?? 'HIGH').toString().toUpperCase();
    final Color pc = priority == 'CRITICAL' ? _C.hot : _C.amber;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateTo(const VolunteerTasksPage()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _C.ink2.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.line),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // priority colour rail
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: pc,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: GoogleFonts.sora(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.place_outlined,
                                      size: 12, color: _C.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.sora(
                                            fontSize: 11,
                                            color: _C.textMuted)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: pc.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(priority,
                              style: GoogleFonts.sora(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: pc)),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: _C.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // 5. OPERATIONAL MODULES (2-column grid)
  // ============================================================
  Widget _buildActionsGrid() {
    final List<Map<String, dynamic>> modules = [
      {
        'title': 'Report Ground Situation',
        'subtitle': 'Upload live photos, hazards & alerts',
        'icon': Icons.add_photo_alternate_rounded,
        'badge': 'FIELD INTEL',
        'color': _C.calm,
        'page': const ReportGroundSituationPage(),
        'route': '/report_ground_situation',
      },
      {
        'title': 'Crowd & Density Maps',
        'subtitle': 'Live camera feeds & density status',
        'icon': Icons.analytics_rounded,
        'badge': 'HEATMAP',
        'color': const Color(0xFF7C74FF),
        'page': const ViewCrowdStatusPage(),
        'route': '/view_crowd_status',
      },
      {
        'title': 'Emergency Directives',
        'subtitle': 'Evacuation instructions & alerts',
        'icon': Icons.campaign_rounded,
        'badge': 'ALERTS',
        'color': _C.amber,
        'page': const ViewEmergencyAlertsPage(),
        'route': '/view_emergency_alerts',
      },
      {
        'title': 'Emergency Instructions',
        'subtitle': 'SOPs, Do’s & Don’ts',
        'icon': Icons.menu_book_rounded,
        'badge': 'SOP',
        'color': _C.yellow,
        'page': const ViewEmergencyInstructionsPage(),
        'route': '/view_emergency_instructions',
      },
      {
        'title': 'Assigned Tasks',
        'subtitle': 'Track deployments & checkpoints',
        'icon': Icons.checklist_rtl_rounded,
        'badge': 'OPERATIONS',
        'color': const Color(0xFFE066F0),
        'page': const VolunteerTasksPage(),
        'route': '/volunteer_tasks_page',
      },
      {
        'title': 'Emergency Department',
        'subtitle': 'Unit details, helpline & areas',
        'icon': Icons.apartment_rounded,
        'badge': 'UNIT',
        'color': const Color(0xFF38BDF8),
        'page': const ViewAssignedDepartmentPage(),
        'route': '/view_assigned_department',
      },
      {
        'title': 'Volunteer Profile',
        'subtitle': 'Duty identity & authorization',
        'icon': Icons.badge_outlined,
        'badge': 'IDENTITY',
        'color': _C.textSub,
        'page': const VolunteerProfileViewPage(),
        'route': '/volunteer_profile_page',
      },
      {
        'title': 'Change Password',
        'subtitle': 'Update login credential',
        'icon': Icons.lock_reset_rounded,
        'badge': 'SECURITY',
        'color': _C.hot,
        'page': const VolunteerChangePasswordPage(),
        'route': '/volunteer_change_password',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        mainAxisExtent: 158,
      ),
      itemBuilder: (context, i) {
        final item = modules[i];
        final Color accent = item['color'] as Color;
        final Widget? targetPage = item['page'] as Widget?;

        return Container(
          decoration: BoxDecoration(
            color: _C.ink2.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              splashColor: accent.withOpacity(0.14),
              highlightColor: accent.withOpacity(0.06),
              onTap: () {
                if (targetPage != null) {
                  _navigateTo(targetPage);
                } else {
                  Navigator.pushNamed(context, item['route'] as String);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent.withOpacity(0.38)),
                          ),
                          child: Icon(item['icon'] as IconData,
                              size: 21, color: accent),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              item['badge'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  letterSpacing: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      item['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['subtitle'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                          fontSize: 10, height: 1.3, color: _C.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2.5), color: _C.calm),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 14, color: _C.textMuted),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.sora(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _C.textSub,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SIMULATION PARTICLE
// ============================================================
class _SimParticle {
  double x;
  double y;
  double speed;
  int stage;
  double exitY;

  _SimParticle({
    required this.x,
    required this.y,
    required this.speed,
    required math.Random rnd,
    this.stage = 0,
  }) : exitY = 60.0 + (rnd.nextDouble() - 0.5) * 40.0;
}

// ============================================================
// BACKGROUND: drifting thermal blobs + zone grid
// ============================================================
class _HeatBackdropPainter extends CustomPainter {
  final Animation<double> anim;
  _HeatBackdropPainter(this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height;
    final t = anim.value * 2 * math.pi;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, H),
          const [_C.ink, Color(0xFF0F1740)],
        ),
    );

    final gp = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(W * i / 4, 0), Offset(W * i / 4, H), gp);
    }
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(0, H * i / 3), Offset(W, H * i / 3), gp);
    }

    final blobs = <List<double>>[
      [0.20, 0.20, 0.55, 0.0, 1.0],
      [0.82, 0.50, 0.60, 2.1, 1.0],
      [0.30, 0.85, 0.50, 4.0, 2.0],
    ];
    for (final b in blobs) {
      final cx = W * (b[0] + 0.14 * math.sin(t * b[4] + b[3]));
      final cy = H * (b[1] + 0.09 * math.cos(t * b[4] + b[3] * 1.3));
      final r = math.max(W, H) * b[2] * (0.9 + 0.1 * math.sin(t * 2 + b[3]));
      final shader = ui.Gradient.radial(
        Offset(cx, cy),
        r,
        [
          _C.yellow.withOpacity(0.22),
          _C.hot.withOpacity(0.20),
          _C.mag.withOpacity(0.16),
          _C.indigo.withOpacity(0.10),
          _C.indigo.withOpacity(0.0),
        ],
        const [0.0, 0.22, 0.48, 0.74, 1.0],
      );
      canvas.drawCircle(Offset(cx, cy), r, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatBackdropPainter old) => false;
}

// ============================================================
// FLOW PAINTER: gate bottleneck with a thermal glow
// ============================================================
class _VolunteerFlowPainter extends CustomPainter {
  final List<_SimParticle> particles;
  final Color riskColor;
  final bool isSurge;

  _VolunteerFlowPainter({
    required Listenable repaint,
    required this.particles,
    required this.riskColor,
    required this.isSurge,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    const double vw = 320.0, vh = 120.0;
    const gateX = 220.0;
    const gateY = 60.0;
    const gap = 16.0;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [_C.ink, Color(0xFF0F1740)],
        ),
    );

    // work in a virtual 320x120 space, scaled to the real canvas
    canvas.save();
    canvas.scale(size.width / vw, size.height / vh);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;
    for (double x = 0; x <= vw; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, vh), gridPaint);
    }
    for (double y = 0; y <= vh; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(vw, y), gridPaint);
    }

    // density near the gate drives the thermal glow
    int near = 0;
    for (final p in particles) {
      final dx = gateX - p.x, dy = gateY - p.y;
      if (dx * dx + dy * dy < 45 * 45 && p.stage == 0) near++;
    }
    final double intensity = (near / 26).clamp(0.0, 1.0).toDouble();
    final double a = 0.22 + 0.7 * intensity;

    final glow = ui.Gradient.radial(
      const Offset(gateX - 22, gateY),
      60,
      [
        _C.yellow.withOpacity(a * 0.9),
        _C.hot.withOpacity(a * 0.8),
        _C.mag.withOpacity(a * 0.6),
        _C.indigo.withOpacity(a * 0.3),
        _C.indigo.withOpacity(0),
      ],
      const [0.0, 0.22, 0.48, 0.74, 1.0],
    );
    canvas.drawCircle(const Offset(gateX - 22, gateY), 60, Paint()..shader = glow);

    // wall with gate opening
    final barrierPaint = Paint()
      ..color = Colors.white.withOpacity(0.75)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(gateX, 0), const Offset(gateX, gateY - gap), barrierPaint);
    canvas.drawLine(const Offset(gateX, gateY + gap), const Offset(gateX, vh), barrierPaint);

    // people
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.78);
    for (final p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), 1.3, dotPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VolunteerFlowPainter old) =>
      old.riskColor != riskColor || old.isSurge != isSurge;
}