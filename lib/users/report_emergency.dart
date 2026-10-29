import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
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

  // Status & Danger
  static const hot = Color(0xFFFF4D4D);
  static const amber = Color(0xFFFF9F1C);
  static const yellow = Color(0xFFFFEC78);
  static const calm = Color(0xFF19C3A6);
  static const indigo = Color(0xFF4338CA);
}

class ReportEmergencyPage extends StatefulWidget {
  const ReportEmergencyPage({super.key});

  @override
  State<ReportEmergencyPage> createState() => _ReportEmergencyPageState();
}

class _ReportEmergencyPageState extends State<ReportEmergencyPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _instructionsController = TextEditingController();

  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  final _instructionsFocus = FocusNode();

  int _selectedTab = 0; // 0 = Report SOS, 1 = My Reports
  bool _isLoading = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _reports = [];

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

    _titleFocus.addListener(() => setState(() {}));
    _descFocus.addListener(() => setState(() {}));
    _instructionsFocus.addListener(() => setState(() {}));

    _heatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _beaconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    final curve = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curve);

    fetchReports();
  }

  @override
  void dispose() {
    _heatCtrl.dispose();
    _beaconCtrl.dispose();
    _enterCtrl.dispose();

    _titleController.dispose();
    _descController.dispose();
    _instructionsController.dispose();

    _titleFocus.dispose();
    _descFocus.dispose();
    _instructionsFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // API CALLS (VIEW, ADD, DELETE)
  // ============================================================

  Future<void> fetchReports() async {
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

      final Uri url = Uri.parse('$baseUrl/myapp/user_view_emergency_reports/');
      final response = await http.post(
        url,
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          setState(() {
            _reports = List<Map<String, dynamic>>.from(data['data']);
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Failed to load reports');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      _showMessage('Network connection error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> addEmergencyReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final Uri url = Uri.parse('$baseUrl/myapp/user_add_emergency_report/');
      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'public_instructions': _instructionsController.text.trim(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok') {
          Fluttertoast.showToast(msg: "Emergency situation reported!");
          _titleController.clear();
          _descController.clear();
          _instructionsController.clear();

          await fetchReports();
          setState(() => _selectedTab = 1);
        } else {
          _showMessage(data['message']?.toString() ?? 'Submission failed');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error adding report: $e');
      _showMessage('Network error while reporting emergency');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> deleteEmergencyReport(String reportId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111A3D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _C.line),
        ),
        title: Text("Delete Report", style: _sora(17, FontWeight.w700, Colors.white)),
        content: Text(
          "Are you sure you want to remove this emergency incident report?",
          style: GoogleFonts.sora(fontSize: 12.5, color: _C.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel", style: GoogleFonts.sora(color: _C.calm)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.hot,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final Uri url = Uri.parse('$baseUrl/myapp/user_delete_emergency_report/');
      final response = await http.post(
        url,
        body: {'lid': lid, 'report_id': reportId},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok') {
          Fluttertoast.showToast(msg: "Report deleted");
          setState(() {
            _reports.removeWhere((item) => item['id'] == reportId);
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Delete failed');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting report: $e');
      _showMessage('Network connection error');
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.ink,
      body: Stack(
        children: [
          // Ambient Danger Red Heat Glow
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
                      radius: 1.4,
                      colors: const [
                        Color(0x38FF4D4D),
                        Color(0x204338CA),
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
                          'Report Emergency',
                          textAlign: TextAlign.center,
                          style: _sora(18, FontWeight.w600, _C.textWhite),
                        ),
                      ),
                      Material(
                        color: _C.hot.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _C.hot.withOpacity(0.3)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: fetchReports,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: _C.hot,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation Tabs
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _C.ink2.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.line),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(0, 'Report SOS', Icons.warning_amber_rounded),
                        _buildTabButton(
                          1,
                          'My Reports (${_reports.length})',
                          Icons.format_list_bulleted_rounded,
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content View
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: _selectedTab == 0
                          ? _buildAddReportForm()
                          : _buildReportsList(),
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
  // TAB BUTTON
  // ============================================================

  Widget _buildTabButton(int index, String label, IconData icon) {
    final bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _C.cardElevated : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _C.hot.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? _C.hot : _C.textMuted,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.sora(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : _C.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAB 1: ADD REPORT FORM
  // ============================================================

  Widget _buildAddReportForm() {
    return Form(
      key: _formKey,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _C.ink2.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.hot.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: _C.hot.withOpacity(0.15),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _C.hot.withOpacity(0.2),
                        border: Border.all(color: _C.hot.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.crisis_alert_rounded, color: _C.hot, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Incident Broadcast", style: _sora(16, FontWeight.w700, _C.textWhite)),
                          const SizedBox(height: 2),
                          Text(
                            "Instantly flags public safety units & first responders",
                            style: GoogleFonts.sora(color: _C.textMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // TITLE
                _fieldLabel("Incident Title"),
                const SizedBox(height: 6),
                _glowField(
                  focus: _titleFocus,
                  child: TextFormField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    cursorColor: _C.hot,
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 14),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter emergency title' : null,
                    decoration: _inputDecoration(
                      hint: "e.g., Heavy stampede surge at Gate 2",
                      icon: Icons.emergency_rounded,
                      focus: _titleFocus,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // DESCRIPTION
                _fieldLabel("Situation Breakdown"),
                const SizedBox(height: 6),
                _glowField(
                  focus: _descFocus,
                  child: TextFormField(
                    controller: _descController,
                    focusNode: _descFocus,
                    maxLines: 4,
                    cursorColor: _C.hot,
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 13.5),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter emergency description' : null,
                    decoration: _inputDecoration(
                      hint: "Describe density buildup, crowd behavior, or physical obstacles...",
                      icon: Icons.notes_rounded,
                      focus: _descFocus,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // PUBLIC INSTRUCTIONS
                _fieldLabel("Public Safety & Evacuation Advice (Optional)"),
                const SizedBox(height: 6),
                _glowField(
                  focus: _instructionsFocus,
                  child: TextFormField(
                    controller: _instructionsController,
                    focusNode: _instructionsFocus,
                    maxLines: 3,
                    cursorColor: _C.hot,
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 13.5),
                    decoration: _inputDecoration(
                      hint: "e.g., Avoid Gate 2, divert towards open North corridor...",
                      icon: Icons.directions_run_rounded,
                      focus: _instructionsFocus,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SUBMIT SOS BUTTON
                Opacity(
                  opacity: _isSubmitting ? 0.7 : 1,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _C.hot.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : addEmergencyReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.hot,
                        disabledBackgroundColor: _C.hot.withOpacity(0.6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broadcast_on_personal_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'TRANSMIT EMERGENCY REPORT',
                            style: GoogleFonts.sora(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
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
  // TAB 2: REPORTS LIST (VIEW & DELETE)
  // ============================================================

  Widget _buildReportsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.hot, strokeWidth: 2.2),
      );
    }

    if (_reports.isEmpty) {
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
                child: const Icon(Icons.verified_outlined, size: 30, color: _C.calm),
              ),
              const SizedBox(height: 16),
              Text("No Emergency Reports", style: _sora(16, FontWeight.w600, _C.textWhite)),
              const SizedBox(height: 6),
              Text(
                "You haven't transmitted any emergency alerts from this terminal.",
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(color: _C.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchReports,
      color: _C.hot,
      backgroundColor: _C.ink2,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final item = _reports[index];
          return _buildReportCard(item);
        },
      ),
    );
  }

  // ============================================================
  // REPORT CARD
  // ============================================================

  Widget _buildReportCard(Map<String, dynamic> item) {
    final String reportId = item['id'].toString();
    final String title = item['title'] ?? 'Emergency Report';
    final String description = item['description'] ?? '';
    final String instructions = item['public_instructions'] ?? '';
    final String status = item['status'] ?? 'ACTIVE';
    final String date = item['created_at'] ?? '';

    final bool isActive = status.toUpperCase() == 'ACTIVE';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? _C.hot.withOpacity(0.4) : _C.line,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isActive)
                      AnimatedBuilder(
                        animation: _beaconCtrl,
                        builder: (context, _) {
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _C.hot,
                              boxShadow: [
                                BoxShadow(
                                  color: _C.hot.withOpacity(0.6 * _beaconCtrl.value),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.calm),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: (isActive ? _C.hot : _C.calm).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.sora(
                          color: isActive ? _C.hot : _C.calm,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(date, style: GoogleFonts.sora(color: _C.textMuted, fontSize: 11)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(title, style: _sora(15.5, FontWeight.w700, _C.textWhite)),
                    ),
                    // DELETE BUTTON
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: _C.hot, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Delete Report",
                      onPressed: () => deleteEmergencyReport(reportId),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.sora(color: _C.textSub, fontSize: 12.5, height: 1.45),
                ),

                if (instructions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _C.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 14, color: _C.yellow),
                            const SizedBox(width: 6),
                            Text(
                              "Public Guidelines:",
                              style: GoogleFonts.sora(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _C.yellow,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          instructions,
                          style: GoogleFonts.sora(fontSize: 11.5, color: Colors.white70, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORM HELPERS
  // ============================================================

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.sora(color: _C.textSub, fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  Widget _glowField({required FocusNode focus, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: focus.hasFocus
            ? [
          BoxShadow(
            color: _C.hot.withOpacity(0.18),
            spreadRadius: 2,
            blurRadius: 8,
          ),
        ]
            : const [],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required FocusNode focus,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.sora(color: _C.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: focus.hasFocus ? _C.hot : _C.textMuted, size: 20),
      filled: true,
      fillColor: const Color(0xFF0E1636),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.line, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.line, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.hot, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.hot, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.hot, width: 1.5),
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