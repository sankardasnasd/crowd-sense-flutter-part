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
  static const cardElevated = Color(0xFF162252);
  static const line = Color(0x24FFFFFF);

  static const textWhite = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF9AA5C9);
  static const textSub = Color(0xFFB9C2E0);

  // Status & Priority Accents
  static const hot = Color(0xFFFF4D4D);    // Critical
  static const amber = Color(0xFFFF9F1C);  // Medium / Caution
  static const yellow = Color(0xFFFFEC78); // Advisory Highlights
  static const calm = Color(0xFF19C3A6);   // Safe / Standard
  static const indigo = Color(0xFF4338CA);
}

class ViewEmergencyInstructionsPage extends StatefulWidget {
  const ViewEmergencyInstructionsPage({super.key});

  @override
  State<ViewEmergencyInstructionsPage> createState() =>
      _ViewEmergencyInstructionsPageState();
}

class _ViewEmergencyInstructionsPageState
    extends State<ViewEmergencyInstructionsPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allInstructions = [];
  List<Map<String, dynamic>> _filteredInstructions = [];

  bool _isLoading = true;
  String _activeFilter = 'ALL'; // 'ALL', 'CRITICAL', 'GENERAL_ADVISORY'

  late final AnimationController _heatCtrl;
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

    _searchController.addListener(_filterList);
    fetchInstructions();
  }

  @override
  void dispose() {
    _heatCtrl.dispose();
    _enterCtrl.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEARCH & FILTER
  // ============================================================

  void _filterList() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredInstructions = _allInstructions.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final summary = (item['summary'] ?? '').toString().toLowerCase();
        final type = (item['instruction_type'] ?? '').toString().toLowerCase();
        final dept = (item['department_name'] ?? '').toString().toLowerCase();

        final matchesQuery = title.contains(query) ||
            summary.contains(query) ||
            type.contains(query) ||
            dept.contains(query);

        if (_activeFilter == 'CRITICAL') {
          return matchesQuery &&
              (item['severity_level'] ?? '').toString().toUpperCase() == 'CRITICAL';
        } else if (_activeFilter == 'GENERAL_ADVISORY') {
          return matchesQuery &&
              (item['instruction_type'] ?? '').toString().toUpperCase() ==
                  'GENERAL_ADVISORY';
        }
        return matchesQuery;
      }).toList();
    });
  }

  // ============================================================
  // FETCH INSTRUCTIONS
  // ============================================================

  Future<void> fetchInstructions() async {
    setState(() => _isLoading = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isEmpty || baseUrl == 'null') {
        _showMessage('Server URL is not configured');
        return;
      }

      final Uri url = Uri.parse('$baseUrl/myapp/user_view_emergency_instructions/');
      final response =
      await http.post(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          setState(() {
            _allInstructions = List<Map<String, dynamic>>.from(data['data']);
            _filterList();
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Failed to load instructions');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching instructions: $e');
      _showMessage('Network connection error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.ink,
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _heatCtrl,
              builder: (context, _) {
                final t = _heatCtrl.value;
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        -0.4 + 0.8 * math.sin(t * math.pi),
                        -0.6 + 0.5 * math.cos(t * math.pi),
                      ),
                      radius: 1.3,
                      colors: const [
                        Color(0x354338CA),
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
                          'Safety Instructions',
                          textAlign: TextAlign.center,
                          style: _sora(18, FontWeight.w600, _C.textWhite),
                        ),
                      ),
                      Material(
                        color: _C.yellow.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _C.yellow.withOpacity(0.3)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: fetchInstructions,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: _C.yellow,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
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
                        hintText: "Search protocols, exit guides, rules...",
                        hintStyle: GoogleFonts.sora(color: _C.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: _C.yellow, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: _C.textMuted, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),

                // Severity Filter Chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Protocols'),
                      const SizedBox(width: 8),
                      _buildFilterChip('CRITICAL', 'Critical Exits'),
                      const SizedBox(width: 8),
                      _buildFilterChip('GENERAL_ADVISORY', 'General Advice'),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(color: _C.yellow, strokeWidth: 2.2),
                  )
                      : _filteredInstructions.isEmpty
                      ? _buildEmptyState()
                      : FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: RefreshIndicator(
                        onRefresh: fetchInstructions,
                        color: _C.yellow,
                        backgroundColor: _C.ink2,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                          itemCount: _filteredInstructions.length,
                          itemBuilder: (context, index) {
                            final item = _filteredInstructions[index];
                            return _buildInstructionCard(item);
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
  // FILTER CHIP
  // ============================================================

  Widget _buildFilterChip(String key, String label) {
    final bool isSelected = _activeFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeFilter = key;
            _filterList();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? _C.yellow.withOpacity(0.18) : _C.ink2.withOpacity(0.8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _C.yellow : _C.line,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.sora(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _C.yellow : _C.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INSTRUCTION CARD (WITH EXPANDABLE DETAILS)
  // ============================================================

  Widget _buildInstructionCard(Map<String, dynamic> item) {
    final String title = item['title'] ?? 'Safety Protocol';
    final String type = item['instruction_type'] ?? 'GENERAL_ADVISORY';
    final String severity = item['severity_level'] ?? 'MEDIUM';
    final String department = item['department_name'] ?? 'Public Safety';
    final String summary = item['summary'] ?? '';
    final String detailedSteps = item['detailed_steps'] ?? '';
    final String doList = item['do_list'] ?? '';
    final String dontList = item['dont_list'] ?? '';
    final String date = item['created_at'] ?? '';

    final Color severityColor = _getSeverityColor(severity);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: severityColor.withOpacity(0.35), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: _C.yellow,
          iconColor: _C.yellow,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: GoogleFonts.sora(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: severityColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                type.replaceAll('_', ' '),
                style: GoogleFonts.sora(fontSize: 10.5, color: _C.textMuted),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _sora(15, FontWeight.w700, _C.textWhite),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: GoogleFonts.sora(fontSize: 12, color: _C.textSub, height: 1.4),
                ),
              ],
            ),
          ),
          children: [
            const Divider(color: _C.line, height: 20),

            // DETAILED PROCEDURAL STEPS
            if (detailedSteps.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.format_list_numbered_rounded, size: 16, color: _C.yellow),
                  const SizedBox(width: 6),
                  Text(
                    "Standard Operational Procedure",
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.yellow,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.line),
                ),
                child: Text(
                  detailedSteps,
                  style: GoogleFonts.sora(fontSize: 12, color: Colors.white70, height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // DO'S LIST (GREEN HIGHLIGHT)
            if (doList.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _C.calm.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.calm.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 15, color: _C.calm),
                        const SizedBox(width: 6),
                        Text(
                          "RECOMMENDED (DO'S)",
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _C.calm,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      doList,
                      style: GoogleFonts.sora(fontSize: 11.5, color: Colors.white, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            // DONT'S LIST (RED HIGHLIGHT)
            if (dontList.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _C.hot.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.hot.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cancel_outlined, size: 15, color: _C.hot),
                        const SizedBox(width: 6),
                        Text(
                          "PROHIBITED (DON'TS)",
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _C.hot,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dontList,
                      style: GoogleFonts.sora(fontSize: 11.5, color: Colors.white, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            // Department & Date Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 13, color: _C.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      department,
                      style: GoogleFonts.sora(color: _C.textMuted, fontSize: 11),
                    ),
                  ],
                ),
                Text(
                  date,
                  style: GoogleFonts.sora(color: _C.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
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
              child: const Icon(Icons.menu_book_rounded, size: 30, color: _C.textMuted),
            ),
            const SizedBox(height: 16),
            Text("No Guidelines Found", style: _sora(16, FontWeight.w600, _C.textWhite)),
            const SizedBox(height: 6),
            Text(
              "No emergency directives match your current search query.",
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