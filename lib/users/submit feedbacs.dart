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

  // Status & Highlights
  static const hot = Color(0xFFFF4D4D);
  static const amber = Color(0xFFFF9F1C);
  static const yellow = Color(0xFFFFEC78);
  static const calm = Color(0xFF19C3A6);
  static const indigo = Color(0xFF4338CA);
}

class SubmitFeedbackPage extends StatefulWidget {
  const SubmitFeedbackPage({super.key});

  @override
  State<SubmitFeedbackPage> createState() => _SubmitFeedbackPageState();
}

class _SubmitFeedbackPageState extends State<SubmitFeedbackPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _subjectFocus = FocusNode();
  final _messageFocus = FocusNode();

  int _rating = 5;
  int _selectedTab = 0; // 0 = New Feedback, 1 = Submissions
  bool _isLoading = false;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _feedbackList = [];

  late final AnimationController _heatCtrl;
  late final AnimationController _shineCtrl;
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  final List<String> _ratingLabels = [
    "Critical Experience",
    "Needs Improvement",
    "Average Performance",
    "Good System Quality",
    "Exceptional Service"
  ];

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
    _messageFocus.addListener(() => setState(() {}));

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

    fetchFeedbacks();
  }

  @override
  void dispose() {
    _heatCtrl.dispose();
    _shineCtrl.dispose();
    _enterCtrl.dispose();

    _subjectController.dispose();
    _messageController.dispose();
    _subjectFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // FETCH FEEDBACKS
  // ============================================================

  Future<void> fetchFeedbacks() async {
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

      final Uri url = Uri.parse('$baseUrl/myapp/user_view_feedback/');
      final response = await http.post(
        url,
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['data'] != null) {
          setState(() {
            _feedbackList = List<Map<String, dynamic>>.from(data['data']);
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Failed to load feedbacks');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching feedback: $e');
      _showMessage('Network connection error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // SUBMIT FEEDBACK
  // ============================================================

  Future<void> submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final Uri url = Uri.parse('$baseUrl/myapp/user_submit_feedback/');
      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'subject': _subjectController.text.trim(),
          'message': _messageController.text.trim(),
          'rating': _rating.toString(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'ok') {
          Fluttertoast.showToast(msg: "Feedback submitted. Thank you!");
          _subjectController.clear();
          _messageController.clear();
          _rating = 5;

          await fetchFeedbacks();
          setState(() {
            _selectedTab = 1;
          });
        } else {
          _showMessage(data['message']?.toString() ?? 'Submission failed');
        }
      } else {
        _showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      _showMessage('Network error while submitting feedback');
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
                        Color(0x35FF9F1C),
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
                          'Submit Feedback',
                          textAlign: TextAlign.center,
                          style: _sora(18, FontWeight.w600, _C.textWhite),
                        ),
                      ),
                      Material(
                        color: _C.amber.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: _C.amber.withOpacity(0.3)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: fetchFeedbacks,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 18,
                              color: _C.amber,
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
                        _buildTabButton(0, 'Send Feedback', Icons.rate_review_rounded),
                        _buildTabButton(
                          1,
                          'Submissions (${_feedbackList.length})',
                          Icons.history_rounded,
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: _selectedTab == 0
                          ? _buildFeedbackForm()
                          : _buildFeedbackList(),
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
              color: isSelected ? _C.amber.withOpacity(0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? _C.amber : _C.textMuted,
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

  Widget _buildFeedbackForm() {
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
                        color: _C.amber.withOpacity(0.2),
                        border: Border.all(color: _C.amber.withOpacity(0.5)),
                      ),
                      child: const Icon(Icons.star_rate_rounded,
                          color: _C.yellow, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Experience & Rating",
                              style: _sora(16, FontWeight.w600, _C.textWhite)),
                          const SizedBox(height: 2),
                          Text(
                            "Help us improve crowd sensing and emergency alerts",
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
                const SizedBox(height: 22),

                // INTERACTIVE STAR RATING SELECTOR
                Center(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          final isFilled = starIndex <= _rating;
                          return GestureDetector(
                            onTap: () => setState(() => _rating = starIndex),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform: isFilled
                                    ? (Matrix4.identity()..scale(1.15))
                                    : Matrix4.identity(),
                                child: Icon(
                                  isFilled
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 38,
                                  color: isFilled ? _C.yellow : _C.textMuted.withOpacity(0.4),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _C.line),
                        ),
                        child: Text(
                          "${_rating} / 5 · ${_ratingLabels[_rating - 1]}",
                          style: GoogleFonts.sora(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _rating >= 4
                                ? _C.calm
                                : _rating == 3
                                ? _C.yellow
                                : _C.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

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
                    v == null || v.trim().isEmpty ? 'Enter feedback subject' : null,
                    decoration: _inputDecoration(
                      hint: "e.g., Quick alerts during festive rush",
                      icon: Icons.title_rounded,
                      focus: _subjectFocus,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // MESSAGE
                _fieldLabel("Your Feedback / Suggestions"),
                const SizedBox(height: 6),
                _glowField(
                  focus: _messageFocus,
                  child: TextFormField(
                    controller: _messageController,
                    focusNode: _messageFocus,
                    maxLines: 5,
                    cursorColor: _C.yellow,
                    style: GoogleFonts.sora(color: Colors.white, fontSize: 13.5),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter your feedback message' : null,
                    decoration: _inputDecoration(
                      hint: "Share your experience with crowd warnings, sensor accuracy, or suggestions...",
                      icon: Icons.chat_bubble_outline_rounded,
                      focus: _messageFocus,
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
                            onPressed: _isSubmitting ? null : submitFeedback,
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
                                  'SUBMIT FEEDBACK',
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
  // TAB 2: SUBMISSIONS LIST
  // ============================================================

  Widget _buildFeedbackList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.amber, strokeWidth: 2.2),
      );
    }

    if (_feedbackList.isEmpty) {
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
                  Icons.reviews_outlined,
                  size: 30,
                  color: _C.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "No Feedback Submitted",
                style: _sora(16, FontWeight.w600, _C.textWhite),
              ),
              const SizedBox(height: 6),
              Text(
                "Your previous ratings and suggestions will appear here.",
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(color: _C.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchFeedbacks,
      color: _C.amber,
      backgroundColor: _C.ink2,
      child: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
        itemCount: _feedbackList.length,
        itemBuilder: (context, index) {
          final item = _feedbackList[index];
          return _buildFeedbackCard(item);
        },
      ),
    );
  }

  // ============================================================
  // FEEDBACK CARD
  // ============================================================

  Widget _buildFeedbackCard(Map<String, dynamic> item) {
    final String subject = item['subject'] ?? 'Feedback';
    final String message = item['message'] ?? '';
    final int rating = int.tryParse(item['rating']?.toString() ?? '5') ?? 5;
    final String date = item['submitted_at'] ?? '';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                children: List.generate(5, (starIdx) {
                  final isFilled = starIdx < rating;
                  return Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 18,
                    color: isFilled ? _C.yellow : _C.textMuted.withOpacity(0.3),
                  );
                }),
              ),
              Text(
                date,
                style: GoogleFonts.sora(color: _C.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subject,
            style: _sora(15, FontWeight.w700, _C.textWhite),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.sora(
              color: _C.textSub,
              fontSize: 12.5,
              height: 1.45,
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
            color: _C.amber.withOpacity(0.18),
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
      prefixIcon: Icon(icon, color: focus.hasFocus ? _C.yellow : _C.textMuted, size: 20),
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
        borderSide: const BorderSide(color: _C.yellow, width: 1.5),
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