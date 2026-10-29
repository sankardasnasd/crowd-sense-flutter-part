import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
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

  static const indigo = Color(0xFF4338CA);
  static const magenta = Color(0xFFC026D3);
  static const hot = Color(0xFFFF4D4D);
  static const amber = Color(0xFFFF9F1C);
  static const yellow = Color(0xFFFFEC78);
  static const calm = Color(0xFF19C3A6);
}

class ManageProfilePage extends StatefulWidget {
  const ManageProfilePage({super.key});

  @override
  State<ManageProfilePage> createState() => _ManageProfilePageState();
}

class _ManageProfilePageState extends State<ManageProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final placeController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  final Location location = Location();

  List<Map<String, dynamic>> areaList = [];
  String? selectedAreaId;
  String assignedAreaName = "Not Assigned";

  bool isEditing = false;
  bool isLoading = true;
  bool isSaving = false;
  bool isFetchingLocation = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await fetchInitialData();
    });
  }

  @override
  void dispose() {
    _heatCtrl.dispose();
    _shineCtrl.dispose();
    _enterCtrl.dispose();

    nameController.dispose();
    placeController.dispose();
    phoneController.dispose();
    emailController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    super.dispose();
  }

  // ============================================================
  // DISTANCE & AREA MATCHING
  // ============================================================

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  void _autoSelectNearestArea(double userLat, double userLon) {
    if (areaList.isEmpty) return;

    Map<String, dynamic>? closestArea;
    double minDistance = double.infinity;

    for (final area in areaList) {
      final double? areaLat = double.tryParse(area['latitude']?.toString() ?? '');
      final double? areaLon = double.tryParse(area['longitude']?.toString() ?? '');

      if (areaLat != null && areaLon != null) {
        final double distance = _calculateDistance(userLat, userLon, areaLat, areaLon);
        if (distance < minDistance) {
          minDistance = distance;
          closestArea = area;
        }
      }
    }

    if (closestArea != null && mounted) {
      setState(() {
        selectedAreaId = closestArea!['id'].toString();
        assignedAreaName = closestArea['name'] ?? 'Area';
      });
      debugPrint("Auto-detected Area: $assignedAreaName (${minDistance.toStringAsFixed(2)} km)");
    }
  }

  // ============================================================
  // GPS & GEOCODING AUTOMATION
  // ============================================================

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  Future<void> getCurrentLocation() async {
    if (!mounted || !isEditing) return;

    setState(() => isFetchingLocation = true);

    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
      }
      if (!serviceEnabled) {
        showMessage('Please enable GPS service');
        return;
      }

      PermissionStatus permission = await location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await location.requestPermission();
      }
      if (permission != PermissionStatus.granted) {
        showMessage('Location permission denied');
        return;
      }

      final LocationData gps = await location.getLocation();
      if (gps.latitude == null || gps.longitude == null) {
        showMessage('Unable to acquire GPS coordinates');
        return;
      }

      final double lat = gps.latitude!;
      final double lon = gps.longitude!;

      if (!mounted) return;

      setState(() {
        latitudeController.text = lat.toStringAsFixed(6);
        longitudeController.text = lon.toStringAsFixed(6);
      });

      try {
        final List<geo.Placemark> addresses =
        await geo.placemarkFromCoordinates(lat, lon);
        if (addresses.isNotEmpty) {
          final first = addresses.first;
          final String detectedPlace = _firstNonEmpty([
            first.subLocality,
            first.locality,
            first.thoroughfare,
            first.name,
          ]);

          if (detectedPlace.isNotEmpty) {
            setState(() {
              placeController.text = detectedPlace;
            });
          }
        }
      } catch (e) {
        debugPrint('Geocoding error: $e');
      }

      if (areaList.isNotEmpty) {
        _autoSelectNearestArea(lat, lon);
      }

      showMessage('Coordinates and closest area updated');
    } catch (e) {
      debugPrint('Location error: $e');
      showMessage('Error detecting location');
    } finally {
      if (mounted) {
        setState(() => isFetchingLocation = false);
      }
    }
  }

  // ============================================================
  // FETCH PROFILE & AREAS CONCURRENTLY
  // ============================================================

  Future<void> fetchInitialData() async {
    setState(() => isLoading = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isEmpty || baseUrl == 'null') {
        showMessage('Server URL is not configured');
        return;
      }

      final profileUrl = Uri.parse('$baseUrl/myapp/user_view_profile/');
      final areaUrl = Uri.parse('$baseUrl/myapp/user_view_area/');

      final results = await Future.wait([
        http.post(profileUrl, body: {'lid': lid}).timeout(const Duration(seconds: 15)),
        http.get(areaUrl).timeout(const Duration(seconds: 15)),
      ]);

      final profileRes = results[0];
      final areaRes = results[1];

      // Handle Area Data (uses your existing user_view_area output)
      if (areaRes.statusCode == 200) {
        final areaData = jsonDecode(areaRes.body);
        if (areaData['status'] == 'ok' && areaData['data'] != null) {
          areaList = List<Map<String, dynamic>>.from(areaData['data']);
        }
      }

      // Handle Profile Data
      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        if (profileData['status'] == 'ok') {
          setState(() {
            nameController.text = profileData['name']?.toString() ?? '';
            phoneController.text = profileData['phone']?.toString() ?? '';
            emailController.text = profileData['email']?.toString() ?? '';
            placeController.text = profileData['place']?.toString() ?? '';
            latitudeController.text = profileData['latitude']?.toString() ?? '';
            longitudeController.text = profileData['longitude']?.toString() ?? '';

            assignedAreaName = profileData['area_name']?.toString() ?? 'Not Assigned';
            selectedAreaId = profileData['area_id']?.toString();

            // Validate selected ID against available areas
            if (selectedAreaId != null &&
                !areaList.any((a) => a['id'].toString() == selectedAreaId)) {
              selectedAreaId = areaList.isNotEmpty ? areaList.first['id'].toString() : null;
            }
          });
        } else {
          showMessage(profileData['message']?.toString() ?? 'Failed to load profile');
        }
      } else {
        showMessage('Server error: ${profileRes.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      showMessage('Failed to connect to backend server');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ============================================================
  // UPDATE PROFILE (Django: user_edit_profile)
  // ============================================================

  Future<void> updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedAreaId == null || selectedAreaId!.isEmpty) {
      showMessage('Please select your monitoring area');
      return;
    }

    setState(() => isSaving = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final Uri url = Uri.parse('$baseUrl/myapp/user_edit_profile/');

      // Matches registration POST keys ('area' = Name, 'region' = Area ID)
      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'area': nameController.text.trim(),
          'region': selectedAreaId!,
          'place': placeController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': emailController.text.trim(),
          'latitude': latitudeController.text.trim(),
          'longitude': longitudeController.text.trim(),
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);

        if (result['status'] == 'ok') {
          Fluttertoast.showToast(msg: 'Profile updated successfully');
          setState(() => isEditing = false);
          fetchInitialData();
        } else {
          showMessage(result['message']?.toString() ?? 'Failed to save changes');
        }
      } else {
        showMessage('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      showMessage('Network error while saving profile');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void showMessage(String message) {
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
  // UI HELPERS
  // ============================================================

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final effectiveReadOnly = !isEditing || readOnly;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        readOnly: effectiveReadOnly,
        keyboardType: keyboardType,
        cursorColor: _C.yellow,
        style: GoogleFonts.sora(
          color: effectiveReadOnly ? Colors.white70 : Colors.white,
          fontSize: 14,
        ),
        validator: validator ??
                (value) =>
            value == null || value.trim().isEmpty ? 'Enter $label' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.sora(
            color: _C.textMuted,
            fontSize: 13,
          ),
          floatingLabelStyle: GoogleFonts.sora(
            color: _C.calm,
            fontWeight: FontWeight.w600,
          ),
          errorStyle: GoogleFonts.sora(
            color: _C.hot,
            fontSize: 11.5,
          ),
          prefixIcon:
          icon == null ? null : Icon(icon, color: _C.calm, size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: effectiveReadOnly
              ? const Color(0xFF090D20)
              : const Color(0xFF0E1636),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _C.line, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isEditing ? _C.line : Colors.white10,
              width: 1,
            ),
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
        ),
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
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
                child: Icon(icon, color: _C.yellow, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _sora(16, FontWeight.w600, _C.textWhite)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.sora(
                        color: _C.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
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
          // Background Thermal Glow
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
                      radius: 1.2,
                      colors: const [
                        Color(0x38C026D3),
                        Color(0x284338CA),
                        _C.ink,
                      ],
                      stops: const [0.0, 0.55, 1.0],
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
                          isEditing ? 'Edit Profile' : 'Operator Profile',
                          textAlign: TextAlign.center,
                          style: _sora(18, FontWeight.w600, _C.textWhite),
                        ),
                      ),
                      // Edit / Cancel Button
                      Material(
                        color: isEditing
                            ? _C.hot.withOpacity(0.18)
                            : _C.calm.withOpacity(0.18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isEditing
                                ? _C.hot.withOpacity(0.4)
                                : _C.calm.withOpacity(0.4),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              isEditing = !isEditing;
                              if (!isEditing) {
                                fetchInitialData();
                              }
                            });
                          },
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              isEditing
                                  ? Icons.close_rounded
                                  : Icons.edit_note_rounded,
                              size: 20,
                              color: isEditing ? _C.hot : _C.calm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: isLoading
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: _C.calm,
                      strokeWidth: 2.2,
                    ),
                  )
                      : FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Form(
                        key: _formKey,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                              children: [
                                // Top Header Badge
                                Center(
                                  child: Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const RadialGradient(
                                        colors: [
                                          _C.yellow,
                                          _C.hot,
                                          _C.magenta,
                                          _C.indigo,
                                        ],
                                        stops: [0.0, 0.35, 0.70, 1.0],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _C.hot.withOpacity(0.3),
                                          blurRadius: 24,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.security_rounded,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    nameController.text.isEmpty
                                        ? 'CrowdSense User'
                                        : nameController.text,
                                    style: _sora(19, FontWeight.w700, _C.textWhite),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    emailController.text.isEmpty
                                        ? 'Connected Citizen Access'
                                        : emailController.text,
                                    style: GoogleFonts.sora(
                                      color: _C.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // ---------------- PERSONAL DETAILS ----------------
                                _sectionCard(
                                  icon: Icons.badge_outlined,
                                  title: 'Personal Information',
                                  subtitle: 'Identity and communication lines',
                                  children: [
                                    _inputField(
                                      label: 'Full Name',
                                      controller: nameController,
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    _inputField(
                                      label: 'Phone Number',
                                      controller: phoneController,
                                      icon: Icons.phone_outlined,
                                      keyboardType: TextInputType.phone,
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Enter contact phone';
                                        }
                                        if (v.trim().length < 10) {
                                          return 'Enter valid 10-digit number';
                                        }
                                        return null;
                                      },
                                    ),
                                    _inputField(
                                      label: 'Email Address',
                                      controller: emailController,
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Enter email address';
                                        }
                                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                            .hasMatch(value.trim())) {
                                          return 'Enter a valid email';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),

                                // ---------------- AREA & LOCATION ----------------
                                _sectionCard(
                                  icon: Icons.map_outlined,
                                  title: 'Assigned Surveillance Area',
                                  subtitle: isEditing
                                      ? 'Auto-detects closest monitoring station'
                                      : 'Registered monitoring sector',
                                  trailing: isEditing
                                      ? Material(
                                    color: _C.calm.withOpacity(0.15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      onPressed: isFetchingLocation
                                          ? null
                                          : getCurrentLocation,
                                      icon: const Icon(
                                        Icons.my_location_rounded,
                                        color: _C.calm,
                                        size: 20,
                                      ),
                                      tooltip: 'Re-fetch GPS Location',
                                    ),
                                  )
                                      : null,
                                  children: [
                                    Text(
                                      'Surveillance Zone',
                                      style: GoogleFonts.sora(
                                        color: _C.textSub,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Dropdown while editing
                                    if (isEditing)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 14),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0E1636),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: _C.line),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: selectedAreaId,
                                            isExpanded: true,
                                            dropdownColor: _C.ink2,
                                            icon: const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: _C.calm,
                                            ),
                                            items: areaList.map((area) {
                                              final String id = area['id'].toString();
                                              final String name = area['name'] ?? 'Area';
                                              final String city = area['city'] ?? '';
                                              final String risk =
                                                  area['current_risk_level'] ?? 'Normal';

                                              return DropdownMenuItem<String>(
                                                value: id,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '$name ${city.isNotEmpty ? "($city)" : ""}',
                                                        style: GoogleFonts.sora(
                                                          color: Colors.white,
                                                          fontSize: 13.5,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: risk == 'High' ||
                                                            risk == 'Critical'
                                                            ? _C.hot.withOpacity(0.2)
                                                            : _C.calm.withOpacity(0.2),
                                                        borderRadius:
                                                        BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        risk,
                                                        style: GoogleFonts.sora(
                                                          color: risk == 'High' ||
                                                              risk == 'Critical'
                                                              ? _C.hot
                                                              : _C.calm,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  selectedAreaId = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 14),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF090D20),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white10),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.hub_outlined,
                                              color: _C.calm,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              assignedAreaName,
                                              style: GoogleFonts.sora(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    _inputField(
                                      label: 'Place / Locality',
                                      controller: placeController,
                                      icon: Icons.place_outlined,
                                    ),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: _inputField(
                                            label: 'Latitude',
                                            controller: latitudeController,
                                            icon: Icons.explore_outlined,
                                            readOnly: true,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _inputField(
                                            label: 'Longitude',
                                            controller: longitudeController,
                                            icon: Icons.explore_outlined,
                                            readOnly: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                // ---------------- SAVE BUTTON (When Editing) ----------------
                                if (isEditing) ...[
                                  const SizedBox(height: 6),
                                  Opacity(
                                    opacity: isSaving ? 0.7 : 1,
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
                                              onPressed: isSaving ? null : updateProfile,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                disabledBackgroundColor: Colors.white70,
                                                foregroundColor: _C.ink,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: isSaving
                                                  ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: _C.ink,
                                                ),
                                              )
                                                  : Row(
                                                mainAxisAlignment:
                                                MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle_outline_rounded,
                                                    size: 20,
                                                    color: _C.ink,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'SAVE CHANGES',
                                                    style: GoogleFonts.sora(
                                                      fontSize: 14.5,
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
                                                      alignment: Alignment(
                                                          -2.0 + (val * 4.0), 0),
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
                                  const SizedBox(height: 18),
                                ],

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      size: 14,
                                      color: _C.calm,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'User identity bound to CrowdSense surveillance engine',
                                      style: GoogleFonts.sora(
                                        color: _C.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
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
        ],
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