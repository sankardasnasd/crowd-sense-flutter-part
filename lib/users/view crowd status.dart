import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _C {
  static const ink = Color(0xFF0A0F24);
  static const ink2 = Color(0xFF111A3D);
  static const cardElevated = Color(0xFF162252);
  static const line = Color(0x24FFFFFF);

  static const textWhite = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF9AA5C9);
  static const textSub = Color(0xFFB9C2E0);

  static const hot = Color(0xFFFF4D4D);    // Critical / High
  static const amber = Color(0xFFFF9F1C);  // Moderate
  static const calm = Color(0xFF19C3A6);   // Normal / Low
  static const indigo = Color(0xFF4338CA);
}

class ViewAllCrowdStatusPage extends StatefulWidget {
  const ViewAllCrowdStatusPage({super.key});

  @override
  State<ViewAllCrowdStatusPage> createState() => _ViewAllCrowdStatusPageState();
}

class _ViewAllCrowdStatusPageState extends State<ViewAllCrowdStatusPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAreas = [];
  List<Map<String, dynamic>> _filteredAreas = [];
  String _searchQuery = '';
  String _selectedRiskFilter = 'ALL';

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    fetchAllAreasCrowdStatus();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchAllAreasCrowdStatus() async {
    setState(() => _isLoading = true);
    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final response = await http.post(
        Uri.parse('$baseUrl/myapp/user_view_all_crowd_status/'),
        body: {'lid': lid},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            _allAreas = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _applyFilters();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching area statuses: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAreas = _allAreas.where((area) {
        final String name = (area['name'] ?? '').toLowerCase();
        final String city = (area['city'] ?? '').toLowerCase();
        final String district = (area['district'] ?? '').toLowerCase();
        final String risk = (area['risk_level'] ?? '').toUpperCase();

        final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
            city.contains(_searchQuery.toLowerCase()) ||
            district.contains(_searchQuery.toLowerCase());

        final matchesRisk = (_selectedRiskFilter == 'ALL') || (risk == _selectedRiskFilter);

        return matchesSearch && matchesRisk;
      }).toList();
    });
  }

  Color _getRiskColor(String level) {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        return _C.hot;
      case 'MODERATE':
        return _C.amber;
      default:
        return _C.calm;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.ink,
      appBar: AppBar(
        backgroundColor: _C.ink,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Citywide Crowd Monitor',
          style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _C.calm),
            onPressed: fetchAllAreasCrowdStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              style: GoogleFonts.sora(color: Colors.white, fontSize: 13.5),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search by sector, city, or district...',
                hintStyle: GoogleFonts.sora(color: _C.textMuted, fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, color: _C.textMuted, size: 20),
                filled: true,
                fillColor: _C.ink2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _C.calm, width: 1.2),
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Sectors (${_allAreas.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('CRITICAL', 'Critical Alert'),
                const SizedBox(width: 8),
                _buildFilterChip('HIGH', 'High Risk'),
                const SizedBox(width: 8),
                _buildFilterChip('MODERATE', 'Moderate'),
                const SizedBox(width: 8),
                _buildFilterChip('LOW', 'Low Risk'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Area List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _C.calm, strokeWidth: 2))
                : _filteredAreas.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: fetchAllAreasCrowdStatus,
              color: _C.calm,
              backgroundColor: _C.ink2,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                itemCount: _filteredAreas.length,
                itemBuilder: (context, index) => _buildAreaCard(_filteredAreas[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String riskKey, String label) {
    final bool isSelected = _selectedRiskFilter == riskKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRiskFilter = riskKey;
          _applyFilters();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _C.calm.withOpacity(0.2) : _C.ink2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _C.calm : _C.line,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? _C.calm : _C.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildAreaCard(Map<String, dynamic> area) {
    final String name = area['name'] ?? 'Area';
    final String location = "${area['city'] ?? ''}, ${area['district'] ?? ''}";
    final String risk = area['risk_level'] ?? 'LOW';
    final int currentCrowd = area['current_total_crowd'] ?? 0;
    final int maxCapacity = area['max_capacity'] ?? 1000;
    final double load = (area['load_percentage'] as num?)?.toDouble() ?? 0.0;
    final bool isMyArea = area['is_my_area'] == true;
    final List cameras = area['cameras'] ?? [];
    final Color riskColor = _getRiskColor(risk);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _C.ink2.withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMyArea ? _C.calm.withOpacity(0.6) : _C.line,
          width: isMyArea ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: GoogleFonts.sora(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (isMyArea) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _C.calm.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                "MY SECTOR",
                                style: GoogleFonts.sora(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _C.calm,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(location, style: GoogleFonts.sora(fontSize: 11.5, color: _C.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: riskColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      FadeTransition(
                        opacity: _pulseCtrl,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: riskColor),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "$risk RISK",
                        style: GoogleFonts.sora(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: riskColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Capacity Metric Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "$currentCrowd ",
                            style: GoogleFonts.sora(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          TextSpan(
                            text: "/ $maxCapacity people",
                            style: GoogleFonts.sora(fontSize: 11.5, color: _C.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "${load.toStringAsFixed(1)}% Capacity",
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (load / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(color: _C.line, height: 1),

          // Expandable Camera List
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              dense: true,
              iconColor: _C.calm,
              collapsedIconColor: _C.textMuted,
              title: Text(
                "CCTV Monitored Points (${cameras.length})",
                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textSub),
              ),
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  itemCount: cameras.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, cIdx) {
                    final cam = cameras[cIdx];
                    final String camStatus = cam['status'] ?? 'NORMAL';
                    final Color camColor = _getRiskColor(camStatus);

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _C.ink,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _C.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cam['identifier'] ?? 'Camera',
                                style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              Text(
                                "$camStatus (${cam['crowd_count']} ppl)",
                                style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700, color: camColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            cam['location'] ?? '',
                            style: GoogleFonts.sora(fontSize: 10.5, color: _C.textMuted),
                          ),
                          if ((cam['heatmap_url'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                cam['heatmap_url'],
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off_rounded, size: 45, color: _C.textMuted),
          const SizedBox(height: 10),
          Text(
            "No Matching Sectors Found",
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "Try adjusting your search query or risk filter.",
            style: GoogleFonts.sora(fontSize: 11.5, color: _C.textMuted),
          ),
        ],
      ),
    );
  }
}