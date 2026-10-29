import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

/// CrowdSense HTML പേജിലെ അതേ കളർ പാലറ്റ്
class CrowdSenseColors {
  static const ink = Color(0xFF0A0F24);
  static const ink2 = Color(0xFF111A3D);
  static const inkCard = Color(0xFF0E1533);
  static const paper = Color(0xFFF3F5FB);
  static const muted = Color(0xFF9AA5C9);
  static const line = Color(0x24FFFFFF); // rgba(255,255,255,0.14)
  static const lineDark = Color(0x33FFFFFF);

  // Thermal Ramp Accents
  static const indigo = Color(0xFF4338CA);
  static const magenta = Color(0xFFC026D3);
  static const hot = Color(0xFFFF4D4D);
  static const amber = Color(0xFFFF9F1C);
  static const yellow = Color(0xFFFFEC78);
  static const calm = Color(0xFF19C3A6);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CrowdSense',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: CrowdSenseColors.ink,
        textTheme: GoogleFonts.soraTextTheme(ThemeData.dark().textTheme),
      ),
      home: DisasterIpPage(),
    );
  }
}

class DisasterIpPage extends StatefulWidget {
  @override
  _DisasterIpPageState createState() => _DisasterIpPageState();
}

class _DisasterIpPageState extends State<DisasterIpPage>
    with TickerProviderStateMixin {
  final _ipController = TextEditingController();
  final _ipFocus = FocusNode();

  late final AnimationController _pulseCtrl; // Radar ring pulse
  late final AnimationController _scanCtrl;  // Live thermal scanning cycle
  late final AnimationController _enterCtrl; // Page entry fade/slide
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ipFocus.addListener(() => setState(() {}));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
  }

  @override
  void dispose() {
    _ipController.dispose();
    _ipFocus.dispose();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Stack(
          children: [
            // -----------------------------------------------------------
            // 1. COMMAND-CENTER BACKGROUND & RADAR GRID
            // -----------------------------------------------------------
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CrowdSenseColors.ink,
                      Color(0xFF0F1740),
                      CrowdSenseColors.ink,
                    ],
                  ),
                ),
                child: CustomPaint(
                  painter: _GridBackgroundPainter(),
                ),
              ),
            ),

            // Glow flare behind the core card
            Positioned(
              top: size.height * 0.18,
              left: size.width * 0.5 - 160,
              child: IgnorePointer(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        CrowdSenseColors.magenta.withOpacity(0.18),
                        CrowdSenseColors.indigo.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // -----------------------------------------------------------
            // 2. MAIN SCROLLABLE CONTENT
            // -----------------------------------------------------------
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 24,
                  ),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // -----------------------------------------
                            // TOP LOGO WITH DYNAMIC RADAR RING
                            // -----------------------------------------
                            SizedBox(
                              width: 105,
                              height: 105,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _pulseCtrl,
                                    builder: (context, _) {
                                      final t = _pulseCtrl.value;
                                      return Container(
                                        width: 60 + (45 * t),
                                        height: 60 + (45 * t),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: CrowdSenseColors.hot.withOpacity((1.0 - t) * 0.65),
                                            width: 1.5,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          CrowdSenseColors.yellow,
                                          CrowdSenseColors.hot,
                                          CrowdSenseColors.magenta,
                                          CrowdSenseColors.indigo,
                                        ],
                                        stops: [0.0, 0.35, 0.70, 1.0],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0x55FF4D4D),
                                          blurRadius: 20,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.sensors_rounded,
                                        color: Colors.white,
                                        size: 34,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // -----------------------------------------
                            // TITLE & SUBTITLE
                            // -----------------------------------------
                            Text(
                              'CrowdSense',
                              style: GoogleFonts.sora(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Real-time crowd density & anomaly detection',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sora(
                                color: CrowdSenseColors.muted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // -----------------------------------------
                            // HUD GLASSMORPHIC CONNECTION CONTAINER
                            // -----------------------------------------
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: CrowdSenseColors.ink2.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: CrowdSenseColors.line),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.45),
                                    blurRadius: 35,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // HUD Header / Status Indicator
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: CrowdSenseColors.calm,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'SYSTEM STANDBY',
                                            style: GoogleFonts.sora(
                                              color: CrowdSenseColors.calm,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'PORT: 8000',
                                        style: GoogleFonts.sora(
                                          color: CrowdSenseColors.muted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 18),
                                  const Divider(color: CrowdSenseColors.line, height: 1),
                                  const SizedBox(height: 18),

                                  // Server IP Label
                                  Text(
                                    'SERVER IP ADDRESS',
                                    style: GoogleFonts.sora(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  // Styled IP Field
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: CrowdSenseColors.ink.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _ipFocus.hasFocus
                                            ? CrowdSenseColors.amber
                                            : CrowdSenseColors.line,
                                        width: 1.3,
                                      ),
                                      boxShadow: _ipFocus.hasFocus
                                          ? [
                                        BoxShadow(
                                          color: CrowdSenseColors.amber.withOpacity(0.2),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                          : [],
                                    ),
                                    child: TextField(
                                      controller: _ipController,
                                      focusNode: _ipFocus,
                                      keyboardType: const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      cursorColor: CrowdSenseColors.amber,
                                      style: GoogleFonts.sora(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '192.168.1.10',
                                        hintStyle: GoogleFonts.sora(
                                          color: CrowdSenseColors.muted.withOpacity(0.6),
                                          fontSize: 13.5,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.videocam_outlined,
                                          color: CrowdSenseColors.calm,
                                          size: 20,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // Dynamic Thermal Scan Bar
                                  AnimatedBuilder(
                                    animation: _scanCtrl,
                                    builder: (context, _) {
                                      final v = (0.2 + (_scanCtrl.value * 0.75)).clamp(0.0, 1.0);
                                      return Column(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              height: 6,
                                              width: double.infinity,
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    CrowdSenseColors.indigo,
                                                    CrowdSenseColors.magenta,
                                                    CrowdSenseColors.hot,
                                                    CrowdSenseColors.amber,
                                                    CrowdSenseColors.yellow,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Zone Baseline',
                                                style: GoogleFonts.sora(
                                                  color: CrowdSenseColors.muted,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                              Text(
                                                'Anomaly Threshold ${(v * 100).toInt()}%',
                                                style: GoogleFonts.sora(
                                                  color: CrowdSenseColors.muted,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 22),

                                  // Connect Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: senddata,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: CrowdSenseColors.ink,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.hub_outlined,
                                            color: CrowdSenseColors.ink,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Connect Stream',
                                            style: GoogleFonts.sora(
                                              color: CrowdSenseColors.ink,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // -----------------------------------------
                            // SYSTEM SPECS BADGES
                            // -----------------------------------------
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _techBadge('CSRNet', CrowdSenseColors.indigo),
                                _techBadge('Optical Flow', CrowdSenseColors.magenta),
                                _techBadge('STCAE', CrowdSenseColors.hot),
                                _techBadge('Django / OpenCV', CrowdSenseColors.calm),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Footer Note
                            Text(
                              'Early detection · Faster response',
                              style: GoogleFonts.sora(
                                color: CrowdSenseColors.muted.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _techBadge(String title, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CrowdSenseColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.sora(
              color: CrowdSenseColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SEND DATA LOGIC (unchanged API & Navigation)
  // =========================================================
  void senddata() async {
    String ip = _ipController.text.trim();

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the server IP address',
            style: GoogleFonts.sora(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          backgroundColor: CrowdSenseColors.hot,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    SharedPreferences sh = await SharedPreferences.getInstance();
    await sh.setString('ip', ip);
    await sh.setString('url', 'http://$ip:8000');
    await sh.setString('imgurl', 'http://$ip:8000/');
    await sh.setString('imgurl2', 'http://$ip:8000/');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(),
      ),
    );
  }
}

/// ബാക്ക്ഗ്രൗണ്ടിൽ CCTV അനലിറ്റിക്സ് ഗ്രിഡ് വരയ്ക്കുന്ന കസ്റ്റം പെയിന്റർ
class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1.0;

    const step = 42.0;
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