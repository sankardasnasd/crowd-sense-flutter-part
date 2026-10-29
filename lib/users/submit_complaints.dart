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

  // Status & Accents
  static const hot = Color(0xFFFF4D4D);    // Pending / Urgent
  static const amber = Color(0xFFFF9F1C);  // In Review
  static const yellow = Color(0xFFFFEC78); // Highlights
  static const calm = Color(0xFF19C3A6);   // Resolved / Replied
  static const indigo = Color(0xFF4338CA);
}

class SubmitComplaintsPage extends StatefulWidget {
  const SubmitComplaintsPage({super.key});

  @override
  State<SubmitComplaintsPage> createState() => _SubmitComplaintsPageState();
}

class _SubmitComplaintsPageState extends State<SubmitComplaintsPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _subjectController = TextEditingController();
  final _descController = TextEditingController();
  final _subjectFocus = FocusNode();
  final _descFocus = FocusNode();

  List<Map<String, dynamic>> _complaintList = [];

  int _selectedTab = 0; // 0 = New Complaint, 1 = History & Replies
  bool _isLoading = false;
  bool _isSubmitting = false;

  late final AnimationController _heatCtrl;
  late final AnimationController _shineCtrl;
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

    _subjectFocus.addListener(() => setState(() {}));
    _descFocus.addListener(() => setState(() {}));

    _heatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

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

    fetchComplaints();
  }

  @override
  void dispose() {
    _heatCtrl.dispose();
    _shineCtrl.dispose();
    _enterCtrl.dispose();

    _subjectController.dispose();
    _descController.dispose();
    _subjectFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // FETCH COMPLAINTS
  // ============================================================

  Future<void> fetchComplaints() async {
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

      final Uri url = Uri.parse('$baseUrl/myapp/user_view_complaints/');
      final response = await http.post(
        url,
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          setState(() {
            _complaintList = List<Map<String, dynamic>>.from(data['data']);
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Failed to load complaints');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching complaints: $e');
      _showMessage('Network connection error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // SUBMIT COMPLAINT
  // ============================================================

  Future<void> submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final Uri url = Uri.parse('$baseUrl/myapp/user_submit_complaint/');
      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'subject': _subjectController.text.trim(),
          'description': _descController.text.trim(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok') {
          Fluttertoast.showToast(msg: "Complaint submitted successfully");
          _subjectController.clear();
          _descController.clear();

          await fetchComplaints();
          setState(() {
            _selectedTab = 1; // Auto-switch to history tab to view new submission
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Failed to submit complaint');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error submitting complaint: $e');
      _showMessage('Network error while submitting complaint');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      case 'RESOLVED':
        return _C.calm;
      case 'IN REVIEW':
      case 'IN_REVIEW':
        return _C.amber;
      default:
        return _C.hot;
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
                        0.5 - 0.9 * math.sin(t * math.pi),
                        -0.6 + 0.5 * math.cos(t * math.pi),
                      ),
                      radius: 1.3,
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
                          'Complaints & Feedback',
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
                          onTap: fetchComplaints,
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
                        _buildTabButton(0, 'Submit New', Icons.edit_note_rounded),
                        _buildTabButton(
                          1,
                          'History & Replies (${_complaintList.length})',
                          Icons.forum_outlined,
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
                          ? _buildSubmissionForm()
                          : _buildHistoryList(),
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
              color: isSelected ? _C.calm.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? _C.calm : _C.textMuted,
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
  // TAB 1: SUBMISSION FORM
  // ============================================================

  Widget _buildSubmissionForm() {
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
              border: Border.all(color: _C.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: _C.indigo.withOpacity(0.35),
                        border: Border.all(color: _C.indigo.withOpacity(0.6)),
                      ),
                      child: const Icon(Icons.report_problem_outlined,
                          color: _C.yellow, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("File an Issue",
                              style: _sora(16, FontWeight.w600, _C.textWhite)),
                          const SizedBox(height: 2),
                          Text(
                            "Report bottlenecks, hazards, or system glitches",
                            style: GoogleFonts.sora(
                              color: _C.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SUBJECT
                _fieldLabel("Subject"),
                const SizedBox(height: 6),
                _glowField(
                  focus: _subjectFocus,
                  child: TextFormField(
                    controller: _subjectController,
                    focusNode: _subjectFocus,
                    cursorColor: _C.yellow,
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 14),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter complaint subject' : null,
                    decoration: _inputDecoration(
                      hint: "e.g., Blocked exit near Gate 4",
                      icon: Icons.title_rounded,
                      focus: _subjectFocus,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // DESCRIPTION
                _fieldLabel("Detailed Description"),
                const SizedBox(height: 6),
                _glowField(
                  focus: _descFocus,
                  child: TextFormField(
                    controller: _descController,
                    focusNode: _descFocus,
                    maxLines: 5,
                    cursorColor: _C.yellow,
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 13.5),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter full issue description' : null,
                    decoration: _inputDecoration(
                      hint: "Describe what happened, exact location, or any urgent risk...",
                      icon: Icons.description_outlined,
                      focus: _descFocus,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SUBMIT BUTTON WITH SHINE
                Opacity(
                  opacity: _isSubmitting ? 0.7 : 1,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : submitComplaint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white70,
                              foregroundColor: _C.ink,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _C.ink,
                              ),
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded,
                                    size: 18, color: _C.ink),
                                const SizedBox(width: 8),
                                Text(
                                  'SUBMIT COMPLAINT',
                                  style: GoogleFonts.sora(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _C.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Sweep Shine Animation
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedBuilder(
                                animation: _shineCtrl,
                                builder: (context, _) {
                                  final val = _shineCtrl.value;
                                  return Align(
                                    alignment: Alignment(-2.0 + (val * 4.0), 0),
                                    child: FractionallySizedBox(
                                      widthFactor: 0.28,
                                      heightFactor: 1.0,
                                      child: Transform(
                                        transform: Matrix4.skewX(-0.35),
                                        child: Container(
                                          color: Colors.white.withOpacity(0.4),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
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
  // TAB 2: COMPLAINT HISTORY & ADMIN REPLIES
  // ============================================================

  Widget _buildHistoryList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.calm, strokeWidth: 2.2),
      );
    }

    if (_complaintList.isEmpty) {
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
                  Icons.mark_chat_read_outlined,
                  size: 30,
                  color: _C.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "No Complaints Submitted",
                style: _sora(16, FontWeight.w600, _C.textWhite),
              ),
              const SizedBox(height: 6),
              Text(
                "You haven't filed any complaints or issues yet.",
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(color: _C.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchComplaints,
      color: _C.calm,
      backgroundColor: _C.ink2,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        itemCount: _complaintList.length,
        itemBuilder: (context, index) {
          final item = _complaintList[index];
          return _buildComplaintCard(item);
        },
      ),
    );
  }

  // ============================================================
  // COMPLAINT CARD WITH ADMIN REPLY BUBBLE
  // ============================================================

  Widget _buildComplaintCard(Map<String, dynamic> item) {
    final String subject = item['subject'] ?? 'No Subject';
    final String description = item['description'] ?? '';
    final String status = item['status'] ?? 'Pending';
    final String adminReply = item['admin_response'] ?? '';
    final String date = item['submitted_at'] ?? '';
    final String resolvedDate = item['resolved_at'] ?? '';

    final Color statusColor = _getStatusColor(status);
    final bool hasReply = adminReply.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasReply ? _C.calm.withOpacity(0.4) : _C.line,
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.sora(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  date,
                  style: GoogleFonts.sora(color: _C.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: _sora(15, FontWeight.w700, _C.textWhite),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: GoogleFonts.sora(
                    color: _C.textSub,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),

                // ADMIN REPLY BUBBLE
                if (hasReply) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1C34),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _C.calm.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.admin_panel_settings_rounded,
                                size: 16, color: _C.calm),
                            const SizedBox(width: 6),
                            Text(
                              "Official Admin Response",
                              style: GoogleFonts.sora(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _C.calm,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          adminReply,
                          style: GoogleFonts.sora(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                        if (resolvedDate.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Resolved: $resolvedDate",
                            style: GoogleFonts.sora(
                              fontSize: 10,
                              color: _C.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 14, color: _C.amber),
                      const SizedBox(width: 6),
                      Text(
                        "Pending official review by sector administrator",
                        style: GoogleFonts.sora(
                          color: _C.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
      style: GoogleFonts.sora(
        color: _C.textSub,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
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
            color: _C.calm.withOpacity(0.18),
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
      prefixIcon: Icon(icon, color: focus.hasFocus ? _C.calm : _C.textMuted, size: 20),
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
        borderSide: const BorderSide(color: _C.calm, width: 1.5),
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