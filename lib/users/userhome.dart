import 'dart:math' as math;
import 'package:crowdsense/users/receive_emergency_alerts.dart';
import 'package:crowdsense/users/report_emergency.dart';
import 'package:crowdsense/users/submit%20feedbacs.dart';
import 'package:crowdsense/users/submit_complaints.dart';
import 'package:crowdsense/users/user%20view%20emergency%20departments.dart';
import 'package:crowdsense/users/view%20crowd%20status.dart';
import 'package:crowdsense/users/view_area_risk_page.dart';
import 'package:crowdsense/users/view_crowd_density.dart';
import 'package:crowdsense/users/view_emergency_instructions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../login.dart';
import 'change password.dart';
import 'manage profile.dart';

// ============================================================
// CROWDSENSE PALETTE & THEME CONSTANTS
// ============================================================

class _C {
  static const bg = Color(0xFF0A0F24);        // Command center deep navy
  static const card = Color(0xFF111A3D);      // Surface card
  static const cardLight = Color(0xFF162252); // Elevated tile
  static const ink = Color(0xFFF3F5FB);       // White primary text
  static const muted = Color(0xFF9AA5C9);     // Slate secondary text
  static const line = Color(0xFF1F2D5A);      // Border stroke
  static const indigo = Color(0xFF4338CA);    // Thermal Indigo
  static const mag = Color(0xFFC026D3);       // Magenta
  static const calm = Color(0xFF19C3A6);      // Mint/Emerald (Normal)
  static const hot = Color(0xFFFF4D4D);       // Alert Red (Critical)
  static const amber = Color(0xFFFF9F1C);     // Warning Amber
  static const yellow = Color(0xFFFFEC78);    // Highlight Yellow
}

// ============================================================
// MAIN (TEST RUNNER)
// ============================================================

void main() {
  runApp(const CrowdSenseUserApp());
}

class CrowdSenseUserApp extends StatelessWidget {
  const CrowdSenseUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CrowdSense User Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _C.bg,
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
      ),
      home: const UserHomePage(),
    );
  }
}

// ============================================================
// USER HOME PAGE
// ============================================================

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _radarCtrl;

  @override
  void initState() {
    super.initState();

    // Radar scanning wave
    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Subtle breathing pulse for alerts
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    // Floating chip micro-motion
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  // Smooth Push Transition Helper
  void _navigateTo(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => page,
        transitionsBuilder: (context, anim, secAnim, child) {
          const begin = Offset(0.08, 0.0);
          const end = Offset.zero;
          final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: end).animate(curve),
            child: FadeTransition(opacity: curve, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // Background subtle thermal ambient glows
          Positioned(
            top: -100,
            right: -80,
            child: _glowSphere(320, _C.indigo.withOpacity(0.2)),
          ),
          Positioned(
            bottom: 120,
            left: -120,
            child: _glowSphere(300, _C.calm.withOpacity(0.12)),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // APP BAR / HEADER
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [_C.indigo, _C.calm],
                                ),
                                border: Border.all(color: _C.line),
                              ),
                              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CrowdSense",
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _C.ink,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _C.calm,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Telemetry Online · Town Centre",
                                      style: GoogleFonts.manrope(
                                        fontSize: 11.5,
                                        color: _C.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Quick Profile Action
                        IconButton(
                          onPressed: () => _navigateTo(const LoginPage()),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _C.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _C.line),
                            ),
                            child: const Icon(Icons.logout, color: _C.calm, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // RADAR LIVE STATUS SUMMARY HERO CARD
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _buildTelemetryCard(),
                  ),
                ),

                // SECTION 1: CROWD INTELLIGENCE & SAFETY
                _buildSectionHeader("CROWD INTELLIGENCE", Icons.radar_rounded),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 135,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildGridTile(
                        title: "Current Crowd Density",
                        subtitle: "View real-time map",
                        icon: Icons.density_medium_rounded,
                        accent: _C.calm,
                        badge: "Live",
                        onTap: () => _navigateTo(const ViewCrowdDensityPage()),
                      ),
                      _buildGridTile(
                        title: "Crowd Status",
                        subtitle: "Movement & pacing",
                        icon: Icons.groups_rounded,
                        accent: _C.indigo,
                        onTap: () => _navigateTo(const ViewAllCrowdStatusPage()),
                      ),
                      _buildGridTile(
                        title: "Area Risk Level",
                        subtitle: "Zone hazard rating",
                        icon: Icons.analytics_outlined,
                        accent: _C.amber,
                        onTap: () => _navigateTo(const ViewAreaRiskPage()),
                      ),
                      _buildGridTile(
                        title: "Emergency Alerts",
                        subtitle: "Evacuation & broadcast",
                        icon: Icons.notifications_active_rounded,
                        accent: _C.hot,
                        badge: "Active",
                        onTap: () => _navigateTo(const ReceiveEmergencyAlertsPage()),
                      ),
                    ]),
                  ),
                ),

                // SECTION 2: EMERGENCY RESPONSE & REPORTING
                _buildSectionHeader("EMERGENCY OPERATIONS", Icons.health_and_safety_rounded),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildListTile(
                        title: "Report Emergency Situation",
                        subtitle: "Instant SOS trigger with live coordinates",
                        icon: Icons.warning_amber_rounded,
                        accent: _C.hot,
                        isAlert: true,
                        onTap: () => _navigateTo(const ReportEmergencyPage()),
                      ),

                      const SizedBox(height: 10),
                      _buildListTile(
                        title: "Nearby Emergency Department",
                        subtitle: "Stations, contact numbers & distance",
                        icon: Icons.local_hospital_rounded,
                        accent: _C.calm,
                        onTap: () => _navigateTo(const ViewNearbyEmergencyDeptPage()),
                      ),
                      const SizedBox(height: 10),
                      _buildListTile(
                        title: "Emergency Instructions",
                        subtitle: "Standard operating guides & safe exits",
                        icon: Icons.menu_book_rounded,
                        accent: _C.yellow,
                        onTap: () => _navigateTo(const ViewEmergencyInstructionsPage()),
                      ),
                    ]),
                  ),
                ),

                // SECTION 3: ACCOUNT & SECURITY
                _buildSectionHeader("ACCOUNT & SECURITY", Icons.lock_outline_rounded),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 110,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildGridTile(
                        title: "Manage Profile",
                        subtitle: "Edit user info",
                        icon: Icons.badge_outlined,
                        accent: _C.indigo,
                        onTap: () => _navigateTo(const ManageProfilePage()),
                      ),
                      _buildGridTile(
                        title: "Change Password",
                        subtitle: "Update login key",
                        icon: Icons.password_rounded,
                        accent: _C.calm,
                        onTap: () => _navigateTo(const ChangePasswordPage()),
                      ),
                    ]),
                  ),
                ),

                // SECTION 4: SUPPORT & COMMUNITY
                _buildSectionHeader("COMMUNITY FEEDBACK", Icons.chat_bubble_outline_rounded),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 110,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildGridTile(
                        title: "Submit Feedback",
                        subtitle: "App & site reviews",
                        icon: Icons.rate_review_outlined,
                        accent: _C.amber,
                        onTap: () => _navigateTo(const SubmitFeedbackPage()),
                      ),
                      _buildGridTile(
                        title: "Submit Complaints",
                        subtitle: "Report issues",
                        icon: Icons.report_problem_outlined,
                        accent: _C.hot,
                        onTap: () => _navigateTo(const SubmitComplaintsPage()),
                      ),
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WIDGET BUILDERS
  // ============================================================

  Widget _glowSphere(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, top: 22, bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _C.muted),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _C.muted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Live Telemetry status card on the top
  Widget _buildTelemetryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (context, _) {
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _C.calm,
                          boxShadow: [
                            BoxShadow(
                              color: _C.calm.withOpacity(0.4 * _pulseCtrl.value),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 9),
                  Text(
                    "SECTOR STATUS: NORMAL",
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.calm,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _C.line),
                ),
                child: Text(
                  "Zone B · Gate 2",
                  style: GoogleFonts.manrope(fontSize: 11, color: _C.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Crowd Flow Steady & Uncongested",
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _C.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "CSRNet density estimation detects no accumulation bottlenecks at the exits.",
            style: GoogleFonts.manrope(fontSize: 12.5, color: _C.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Thermal gradient load line
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 6,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_C.indigo, _C.mag, _C.amber, _C.calm],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Density: 34%", style: GoogleFonts.manrope(fontSize: 11, color: _C.muted)),
              Text("Movement: Steady", style: GoogleFonts.manrope(fontSize: 11, color: _C.calm)),
              Text("Risk: Low", style: GoogleFonts.manrope(fontSize: 11, color: _C.calm)),
            ],
          ),
        ],
      ),
    );
  }

  // Grid Tile Component
  Widget _buildGridTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _C.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _C.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    color: _C.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // List Tile Component
  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    bool isAlert = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isAlert ? _C.hot.withOpacity(0.08) : _C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isAlert ? _C.hot.withOpacity(0.4) : _C.line),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isAlert ? const Color(0xFFFF9494) : _C.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(fontSize: 12, color: _C.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _C.muted),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DUMMY TARGET PAGES (Connect these to your actual views)
// ============================================================

class _SampleDetailScaffold extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;

  const _SampleDetailScaffold({
    required this.title,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.ink, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: _C.ink),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Icon(icon, size: 36, color: accent),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: _C.ink),
              ),
              const SizedBox(height: 10),
              Text(
                "Integrate your backend API logic and custom form widgets here for $title.",
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(fontSize: 13.5, color: _C.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




class ViewCrowdStatusPage extends StatelessWidget {
  const ViewCrowdStatusPage({super.key});
  @override
  Widget build(BuildContext context) => const _SampleDetailScaffold(
      title: "Crowd Status", icon: Icons.groups_rounded, accent: _C.indigo);
}

class ViewAreaRiskLevelPage extends StatelessWidget {
  const ViewAreaRiskLevelPage({super.key});
  @override
  Widget build(BuildContext context) => const _SampleDetailScaffold(
      title: "Area Risk Level", icon: Icons.analytics_outlined, accent: _C.amber);
}









