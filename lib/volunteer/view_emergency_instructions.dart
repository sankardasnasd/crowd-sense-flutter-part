import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ViewEmergencyInstructionsPage extends StatefulWidget {
  const ViewEmergencyInstructionsPage({super.key});

  @override
  State<ViewEmergencyInstructionsPage> createState() =>
      _ViewEmergencyInstructionsPageState();
}

class _ViewEmergencyInstructionsPageState
    extends State<ViewEmergencyInstructionsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _instructions = [];
  String _errorMessage = '';
  String _selectedSeverity = 'ALL';
  final TextEditingController _searchCtrl = TextEditingController();

  // CrowdSense Dark Tokens
  static const Color ink = Color(0xFF0A0F24);
  static const Color ink2 = Color(0xFF111A3D);
  static const Color cardElevated = Color(0xFF162252);
  static const Color line = Color(0x24FFFFFF);
  static const Color textMuted = Color(0xFF9AA5C9);
  static const Color textSub = Color(0xFFB9C2E0);
  static const Color calm = Color(0xFF19C3A6);
  static const Color hot = Color(0xFFFF4D4D);
  static const Color amber = Color(0xFFFF9F1C);
  static const Color yellow = Color(0xFFFFEC78);
  static const Color indigo = Color(0xFF4338CA);

  @override
  void initState() {
    super.initState();
    fetchInstructions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> fetchInstructions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final url =
      Uri.parse('$baseUrl/myapp/volunteer_view_emergency_instructions/');

      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'severity': _selectedSeverity,
          'search': _searchCtrl.text.trim(),
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          setState(() {
            _instructions =
            List<Map<String, dynamic>>.from(res['data'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage =
                res['message'] ?? 'Failed to retrieve instructions.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Server error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error: $e";
        _isLoading = false;
      });
    }
  }

  Color _getSeverityColor(String sev) {
    switch (sev.toUpperCase()) {
      case 'CRITICAL':
        return hot;
      case 'HIGH':
        return amber;
      case 'MEDIUM':
        return yellow;
      default:
        return calm;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: ink,
        elevation: 0,
        title: Text(
          "Emergency Instructions & SOP",
          style: GoogleFonts.sora(
              fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => fetchInstructions(),
              style: GoogleFonts.sora(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: ink2,
                hintText: "Search instructions, SOP title...",
                hintStyle:
                GoogleFonts.sora(fontSize: 12.5, color: textMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: textMuted),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      size: 18, color: textMuted),
                  onPressed: () {
                    _searchCtrl.clear();
                    fetchInstructions();
                  },
                )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: calm),
                ),
              ),
            ),
          ),
          _buildFilterTabs(),

          // Main List
          Expanded(
            child: _isLoading
                ? const Center(
                child:
                CircularProgressIndicator(color: calm, strokeWidth: 2))
                : _errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage,
                      style: GoogleFonts.sora(
                          color: hot, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: fetchInstructions,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ink2),
                    child: Text("RETRY",
                        style: GoogleFonts.sora(
                            color: Colors.white)),
                  )
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchInstructions,
              color: calm,
              backgroundColor: ink2,
              child: _instructions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                itemCount: _instructions.length,
                itemBuilder: (context, index) {
                  return _buildInstructionCard(
                      _instructions[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['ALL', 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _selectedSeverity == f;

          return ChoiceChip(
            label: Text(
              f == 'ALL' ? 'ALL SOPs' : f,
              style: GoogleFonts.sora(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : textMuted,
              ),
            ),
            selected: isSelected,
            selectedColor: cardElevated,
            backgroundColor: ink2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isSelected ? calm : line),
            ),
            onSelected: (val) {
              if (val) {
                setState(() => _selectedSeverity = f);
                fetchInstructions();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildInstructionCard(Map<String, dynamic> item) {
    final severity = (item['severity_level'] ?? 'MEDIUM').toString().toUpperCase();
    final Color sevColor = _getSeverityColor(severity);
    final String type = (item['instruction_type'] ?? 'GENERAL_ADVISORY')
        .toString()
        .replaceAll('_', ' ');

    final String doList = item['do_list'] ?? '';
    final String dontList = item['dont_list'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ink2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: severity == 'CRITICAL' ? hot.withOpacity(0.55) : line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding:
          const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: calm,
          collapsedIconColor: textMuted,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7.5, vertical: 3),
                    decoration: BoxDecoration(
                      color: sevColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sevColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      "$severity LEVEL",
                      style: GoogleFonts.sora(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: sevColor,
                      ),
                    ),
                  ),
                  Text(
                    type,
                    style: GoogleFonts.sora(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item['title'] ?? 'Safety Instruction',
                style: GoogleFonts.sora(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['summary'] ?? '',
                style: GoogleFonts.sora(
                  fontSize: 11.5,
                  color: textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
          children: [
            const Divider(color: line, height: 18),

            // Detailed Tactical Steps
            _buildSectionHeader("DETAILED PROTOCOL STEPS", Icons.format_list_numbered_rounded),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: line),
              ),
              child: Text(
                item['detailed_steps'] ?? 'Follow general field safety.',
                style: GoogleFonts.sora(
                    fontSize: 12, color: textSub, height: 1.45),
              ),
            ),
            const SizedBox(height: 12),

            // DO'S & DON'TS BOXES
            if (doList.trim().isNotEmpty) ...[
              _buildGuidelineBox("DO'S (RECOMMENDED ACTIONS)", doList, calm, Icons.check_circle_rounded),
              const SizedBox(height: 10),
            ],
            if (dontList.trim().isNotEmpty) ...[
              _buildGuidelineBox("DON'TS (HAZARDS TO AVOID)", dontList, hot, Icons.cancel_rounded),
              const SizedBox(height: 10),
            ],

            // Department & Timestamp Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Source: ${item['department_name']}",
                    style: GoogleFonts.sora(fontSize: 10, color: textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  item['created_at'] ?? '',
                  style: GoogleFonts.sora(fontSize: 10, color: textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineBox(
      String title, String content, Color accent, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.sora(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: GoogleFonts.sora(
                fontSize: 11.5, color: Colors.white, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: calm),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.sora(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textSub,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 42, color: textMuted),
          const SizedBox(height: 12),
          Text(
            "No Emergency SOPs Found",
            style: GoogleFonts.sora(
                fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "No active standard operating procedures match your query.",
            style: GoogleFonts.sora(fontSize: 11.5, color: textMuted),
          ),
        ],
      ),
    );
  }
}