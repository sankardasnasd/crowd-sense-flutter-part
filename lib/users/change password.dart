import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// CROWDSENSE PALETTE
// ============================================================

class _C {
  static const bg = Color(0xFF0A0F24);        // Command center deep navy
  static const card = Color(0xFF111A3D);      // Surface card
  static const ink = Color(0xFFF3F5FB);       // White text
  static const muted = Color(0xFF9AA5C9);     // Slate secondary text
  static const line = Color(0xFF1F2D5A);      // Border stroke
  static const indigo = Color(0xFF4338CA);    // Thermal Indigo
  static const calm = Color(0xFF19C3A6);      // Mint/Emerald
  static const hot = Color(0xFFFF4D4D);       // Alert Red
  static const amber = Color(0xFFFF9F1C);     // Warning Amber
}

// ============================================================
// CHANGE PASSWORD PAGE
// ============================================================

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _oldPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  final FocusNode _oldFocus = FocusNode();
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _oldFocus.addListener(() => setState(() {}));
    _newFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    final curve = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _fade = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _oldFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ============================================================
  // API CALL
  // ============================================================

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final oldPassword = _oldPassController.text.trim();
    final newPassword = _newPassController.text.trim();
    final confirmPassword = _confirmPassController.text.trim();

    if (newPassword != confirmPassword) {
      Fluttertoast.showToast(msg: "Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String? baseUrl = sh.getString("url");
      String? lid = sh.getString("lid");

      if (baseUrl == null || baseUrl.isEmpty || baseUrl == "null") {
        Fluttertoast.showToast(msg: "Server URL not configured");
        return;
      }

      if (lid == null || lid.isEmpty || lid == "null") {
        Fluttertoast.showToast(msg: "Authentication session expired. Please log in again.");
        return;
      }

      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');
      final Uri url = Uri.parse("$baseUrl/myapp/user_change_password/");

      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'old_password': oldPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (data['status'] == 'ok') {
        Fluttertoast.showToast(msg: "Password updated successfully");
        if (mounted) Navigator.pop(context);
      } else {
        Fluttertoast.showToast(msg: "Invalid current password or mismatched confirmation");
      }
    } on TimeoutException {
      Fluttertoast.showToast(msg: "Server connection timeout");
    } on FormatException {
      Fluttertoast.showToast(msg: "Invalid response from server");
    } catch (_) {
      Fluttertoast.showToast(msg: "Failed to connect to server");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.card,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.ink, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Change Password",
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _C.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP SECURITY BADGE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _C.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _C.calm.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _C.calm.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.security_rounded, color: _C.calm, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Security Credentials",
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _C.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "Choose a strong password to protect operator access.",
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    color: _C.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // FORM CONTAINER
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _C.card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _C.line),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CURRENT PASSWORD
                          _fieldLabel("Current Password"),
                          const SizedBox(height: 8),
                          _glowField(
                            focus: _oldFocus,
                            child: TextFormField(
                              controller: _oldPassController,
                              focusNode: _oldFocus,
                              obscureText: _obscureOld,
                              cursorColor: _C.calm,
                              style: GoogleFonts.manrope(color: _C.ink, fontSize: 14.5),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return "Enter current password";
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                hint: "Enter current password",
                                icon: Icons.lock_outline_rounded,
                                focus: _oldFocus,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscureOld = !_obscureOld),
                                  icon: Icon(
                                    _obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: _C.muted,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // NEW PASSWORD
                          _fieldLabel("New Password"),
                          const SizedBox(height: 8),
                          _glowField(
                            focus: _newFocus,
                            child: TextFormField(
                              controller: _newPassController,
                              focusNode: _newFocus,
                              obscureText: _obscureNew,
                              cursorColor: _C.calm,
                              style: GoogleFonts.manrope(color: _C.ink, fontSize: 14.5),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return "Enter new password";
                                }
                                if (val.trim().length < 6) {
                                  return "Password must be at least 6 characters";
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                hint: "Enter new password",
                                icon: Icons.vpn_key_outlined,
                                focus: _newFocus,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                                  icon: Icon(
                                    _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: _C.muted,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // CONFIRM PASSWORD
                          _fieldLabel("Confirm Password"),
                          const SizedBox(height: 8),
                          _glowField(
                            focus: _confirmFocus,
                            child: TextFormField(
                              controller: _confirmPassController,
                              focusNode: _confirmFocus,
                              obscureText: _obscureConfirm,
                              cursorColor: _C.calm,
                              style: GoogleFonts.manrope(color: _C.ink, fontSize: 14.5),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return "Confirm your new password";
                                }
                                if (val.trim() != _newPassController.text.trim()) {
                                  return "Passwords do not match";
                                }
                                return null;
                              },
                              decoration: _inputDecoration(
                                hint: "Re-enter new password",
                                icon: Icons.check_circle_outline_rounded,
                                focus: _confirmFocus,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  icon: Icon(
                                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: _C.muted,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // SUBMIT BUTTON
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [_C.indigo, _C.calm],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _C.indigo.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updatePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Update Password",
                                    style: GoogleFonts.manrope(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _C.ink,
      ),
    );
  }

  Widget _glowField({required FocusNode focus, required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: focus.hasFocus
            ? [
          BoxShadow(
            color: _C.calm.withOpacity(0.22),
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
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(color: _C.muted.withOpacity(0.7), fontSize: 13.5),
      prefixIcon: Icon(icon, color: focus.hasFocus ? _C.calm : _C.muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: focus.hasFocus ? const Color(0xFF162252) : const Color(0xFF0D1432),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.line, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.line, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.calm, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.hot, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _C.hot, width: 1.5),
      ),
    );
  }
}