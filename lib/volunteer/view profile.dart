import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VolunteerProfileViewPage extends StatefulWidget {
  const VolunteerProfileViewPage({super.key});

  @override
  State<VolunteerProfileViewPage> createState() => _VolunteerProfileViewPageState();
}

class _VolunteerProfileViewPageState extends State<VolunteerProfileViewPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProfileAndSyncLocation();
  }


  Future<void> _loadProfileAndSyncLocation() async {
    await fetchVolunteerProfile();
    await _detectAndSyncCurrentPlace();
  }

  Future<void> fetchVolunteerProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final profileUrl = Uri.parse('$baseUrl/myapp/volunteer_view_profile/');

      final response = await http.post(
        profileUrl,
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['status'] == 'ok') {
          if (mounted) {
            setState(() {
              _profileData = resData['data'];
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = resData['message'] ?? 'Failed to load profile';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Server error: ${response.statusCode}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Network error: $e";
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // CURRENT LOCATION എടുത്തു PLACE ബാക്കെൻഡിലേക്ക് അപ്‌ഡേറ്റ് ചെയ്യുന്നു
  // ============================================================
  Future<void> _detectAndSyncCurrentPlace() async {
    try {
      Location location = Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      LocationData locationData = await location.getLocation();
      if (locationData.latitude == null || locationData.longitude == null) return;

      final double lat = locationData.latitude!;
      final double lon = locationData.longitude!;

      // Reverse geocoding വഴി സ്ഥലത്തിന്റെ പേര് എടുക്കുന്നു
      List<geo.Placemark> placemarks = await geo.placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty) return;

      geo.Placemark place = placemarks.first;
      List<String> addressParts = [];

      if (place.subLocality != null && place.subLocality!.trim().isNotEmpty) {
        addressParts.add(place.subLocality!.trim());
      }
      if (place.locality != null && place.locality!.trim().isNotEmpty) {
        addressParts.add(place.locality!.trim());
      }
      if (place.administrativeArea != null && place.administrativeArea!.trim().isNotEmpty) {
        addressParts.add(place.administrativeArea!.trim());
      }

      String detectedPlace = addressParts.isNotEmpty
          ? addressParts.join(', ')
          : (place.name ?? "${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}");

      // UI-ൽ തത്സമയം place മാറ്റുന്നു
      if (mounted) {
        setState(() {
          if (_profileData != null) {
            _profileData!['place'] = detectedPlace;
          }
        });
      }

      // Django ബാക്കെൻഡിൽ volunteer profile place അപ്ഡേറ്റ് ചെയ്യുന്നു
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      if (baseUrl.isNotEmpty && lid.isNotEmpty) {
        final updateUrl = Uri.parse('$baseUrl/myapp/update_volunteer_profile_place/');
        await http.post(
          updateUrl,
          body: {
            'lid': lid,
            'place': detectedPlace,
            'latitude': lat.toString(),
            'longitude': lon.toString(),
          },
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint("Error detecting/updating current place: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
      case 'AVAILABLE':
        return const Color(0xFF19C3A6);
      case 'ON_DUTY':
        return const Color(0xFFFF9F1C);
      case 'REJECTED':
      case 'OFFLINE':
        return const Color(0xFFFF4D4D);
      default:
        return const Color(0xFFFFEC78);
    }
  }

  void _showImageDialog(String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111A3D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x24FFFFFF)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF9AA5C9)),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: const Color(0xFF0A0F24),
                    alignment: Alignment.center,
                    child: Text(
                      "Failed to preview document",
                      style: GoogleFonts.sora(color: const Color(0xFF9AA5C9), fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0A0F24);
    const ink2 = Color(0xFF111A3D);
    const line = Color(0x24FFFFFF);
    const calm = Color(0xFF19C3A6);

    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: ink,
        elevation: 0,
        title: Text(
          "Volunteer Profile",
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: calm, strokeWidth: 2))
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: GoogleFonts.sora(color: Colors.redAccent, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadProfileAndSyncLocation,
              style: ElevatedButton.styleFrom(backgroundColor: ink2),
              child: Text("RETRY", style: GoogleFonts.sora(color: Colors.white)),
            )
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadProfileAndSyncLocation,
        color: calm,
        backgroundColor: ink2,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: [
            // Profile Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ink2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: Colors.white10,
                    backgroundImage: (_profileData?['photo'] != null && _profileData!['photo'].isNotEmpty)
                        ? NetworkImage(_profileData!['photo'])
                        : null,
                    child: (_profileData?['photo'] == null || _profileData!['photo'].isEmpty)
                        ? const Icon(Icons.person, size: 45, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _profileData?['name'] ?? '',
                    style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _profileData?['department_name'] ?? 'General Volunteer',
                    style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF9AA5C9)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusBadge(
                        "APPROVAL: ${_profileData?['approval_status'] ?? 'PENDING'}",
                        _getStatusColor(_profileData?['approval_status'] ?? ''),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(
                        _profileData?['availability_status'] ?? 'OFFLINE',
                        _getStatusColor(_profileData?['availability_status'] ?? ''),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Contact & Location Details (Place includes live GPS indicator)
            _buildSectionTitle("PERSONAL & CONTACT DETAILS"),
            _buildInfoCard([
              _buildInfoRow(Icons.email_outlined, "Email", _profileData?['email']),
              _buildInfoRow(Icons.phone_outlined, "Phone", _profileData?['phone']),
              _buildInfoRow(
                Icons.my_location_rounded,
                "Current Place",
                _profileData?['place'],
                isHighlight: true,
              ),
              _buildInfoRow(Icons.calendar_today_outlined, "Joined Date", _profileData?['join_at']),
            ]),

            const SizedBox(height: 16),

            // Department & Field Deployments
            _buildSectionTitle("TACTICAL DEPLOYMENT"),
            _buildInfoCard([
              _buildInfoRow(Icons.apartment_rounded, "Department", _profileData?['department_name']),
              _buildInfoRow(Icons.support_agent_rounded, "Dept Contact", _profileData?['department_contact']),
              _buildInfoRow(
                Icons.radar_rounded,
                "Assigned Sectors",
                (_profileData?['assigned_areas'] as List?)?.isNotEmpty == true
                    ? (_profileData!['assigned_areas'] as List).join(', ')
                    : "No zones assigned",
              ),
            ]),

            const SizedBox(height: 16),

            // ID Proof Document Card
            _buildSectionTitle("IDENTITY PROOF DOCUMENT"),
            _buildIdProofCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildIdProofCard() {
    final String idProofUrl = _profileData?['id_proof'] ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111A3D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF19C3A6)),
                  const SizedBox(width: 8),
                  Text(
                    "Submitted Identity Proof",
                    style: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
              if (idProofUrl.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF19C3A6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "VERIFIED ATTACHMENT",
                    style: GoogleFonts.sora(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF19C3A6)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (idProofUrl.isNotEmpty)
            GestureDetector(
              onTap: () => _showImageDialog(idProofUrl, "Submitted ID Proof"),
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF162252),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x24FFFFFF)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        idProofUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            "Unable to preview document",
                            style: GoogleFonts.sora(fontSize: 11, color: const Color(0xFF9AA5C9)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0F24).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x24FFFFFF)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                "Tap to Zoom",
                                style: GoogleFonts.sora(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              alignment: Alignment.center,
              child: Text(
                "No ID Proof document attached",
                style: GoogleFonts.sora(fontSize: 11.5, color: const Color(0xFF9AA5C9)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.sora(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFB9C2E0),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111A3D),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, dynamic value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: isHighlight ? const Color(0xFFFF9F1C) : const Color(0xFF19C3A6)),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.sora(fontSize: 12, color: const Color(0xFF9AA5C9)),
            ),
          ),
          Expanded(
            child: Text(
              (value != null && value.toString().trim().isNotEmpty) ? value.toString() : 'Detecting...',
              style: GoogleFonts.sora(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isHighlight ? const Color(0xFFFF9F1C) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}