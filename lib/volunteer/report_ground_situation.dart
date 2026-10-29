import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportGroundSituationPage extends StatefulWidget {
  final int? initialTaskId;

  const ReportGroundSituationPage({super.key, this.initialTaskId});

  @override
  State<ReportGroundSituationPage> createState() =>
      _ReportGroundSituationPageState();
}

class _ReportGroundSituationPageState extends State<ReportGroundSituationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // View Submitted Reports State
  bool _isLoadingReports = true;
  List<Map<String, dynamic>> _reports = [];
  String _errorMessage = '';

  // Add Report Form State (With Task Dropdown)
  bool _isLoadingTasks = true;
  List<Map<String, dynamic>> _todayTasks = [];
  int? _selectedTaskId;
  String _selectedTaskInstruction = '';

  final TextEditingController _descCtrl = TextEditingController();
  File? _selectedImage;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();

  // CrowdSense Dark Palette Tokens
  static const Color ink = Color(0xFF0A0F24);
  static const Color ink2 = Color(0xFF111A3D);
  static const Color cardElevated = Color(0xFF162252);
  static const line = Color(0x24FFFFFF);
  static const Color textMuted = Color(0xFF9AA5C9);
  static const Color textSub = Color(0xFFB9C2E0);
  static const Color calm = Color(0xFF19C3A6);
  static const Color hot = Color(0xFFFF4D4D);
  static const Color amber = Color(0xFFFF9F1C);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    fetchSubmittedReports();
    fetchTodayTasksDropdown();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // 1. FETCH ALL SUBMITTED REPORTS
  // ============================================================
  Future<void> fetchSubmittedReports() async {
    setState(() {
      _isLoadingReports = true;
      _errorMessage = '';
    });

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final url = Uri.parse('$baseUrl/myapp/volunteer_view_ground_reports/');
      final response = await http
          .post(url, body: {'lid': lid}).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          setState(() {
            _reports = List<Map<String, dynamic>>.from(res['data'] ?? []);
            _isLoadingReports = false;
          });
        } else {
          setState(() {
            _errorMessage = res['message'] ?? 'Failed to load reports';
            _isLoadingReports = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Server error: ${response.statusCode}";
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Network error: $e";
        _isLoadingReports = false;
      });
    }
  }

  // ============================================================
  // 2. FETCH ONLY TODAY'S TASKS FOR FORM DROPDOWN
  // ============================================================
  Future<void> fetchTodayTasksDropdown() async {
    setState(() => _isLoadingTasks = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final url = Uri.parse('$baseUrl/myapp/get_volunteer_tasks_dropdown/');
      final response = await http
          .post(url, body: {'lid': lid}).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          final List<Map<String, dynamic>> tasks =
          List<Map<String, dynamic>>.from(res['tasks'] ?? []);

          setState(() {
            _todayTasks = tasks;
            _isLoadingTasks = false;

            if (_todayTasks.isNotEmpty) {
              if (widget.initialTaskId != null &&
                  _todayTasks.any((t) => t['id'] == widget.initialTaskId)) {
                _selectedTaskId = widget.initialTaskId;
              } else {
                _selectedTaskId = _todayTasks.first['id'];
              }

              final currentTask =
              _todayTasks.firstWhere((t) => t['id'] == _selectedTaskId);
              _selectedTaskInstruction = currentTask['instruction'] ?? '';
            } else {
              _selectedTaskId = null;
              _selectedTaskInstruction = '';
            }
          });
        } else {
          setState(() => _isLoadingTasks = false);
        }
      } else {
        setState(() => _isLoadingTasks = false);
      }
    } catch (e) {
      debugPrint("Dropdown task error: $e");
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  // ============================================================
  // 3. IMAGE PICKER
  // ============================================================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      debugPrint("Image picker error: $e");
    }
  }

  // ============================================================
  // 4. SUBMIT REPORT AS ANSWER TO SELECTED TASK
  // ============================================================
  Future<void> _submitReport() async {
    if (_selectedTaskId == null) {
      _showToast("Please choose an assigned task from dropdown.", isError: true);
      return;
    }
    final String text = _descCtrl.text.trim();
    if (text.isEmpty) {
      _showToast("Please provide your situation answer/update.", isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final uri = Uri.parse('$baseUrl/myapp/volunteer_add_ground_report/');
      final request = http.MultipartRequest('POST', uri);

      request.fields['lid'] = lid;
      request.fields['task_id'] = _selectedTaskId.toString();
      request.fields['situation_update'] = text;

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
              'attached_image', _selectedImage!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          _showToast("Situation report submitted.");
          _descCtrl.clear();
          setState(() => _selectedImage = null);

          // ആദ്യ ടാബിലേക്ക് തിരിച്ചുപോയി ലിസ്റ്റ് റിഫ്രഷ് ചെയ്യുന്നു
          _tabCtrl.animateTo(0);
          fetchSubmittedReports();
        } else {
          _showToast(res['message'] ?? 'Submission failed.', isError: true);
        }
      } else {
        _showToast("Server error: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showToast("Connection failed: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ============================================================
  // 5. DELETE REPORT
  // ============================================================
  Future<void> _deleteReport(int reportId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ink2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
        title: Text(
          "Delete Report",
          style: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        content: Text(
          "Are you sure you want to remove this situation report?",
          style: GoogleFonts.sora(fontSize: 12.5, color: textSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("CANCEL", style: GoogleFonts.sora(color: textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: hot),
            child: Text("DELETE",
                style: GoogleFonts.sora(
                    color: Colors.white, fontWeight: FontWeight.w700)),
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

      final url = Uri.parse('$baseUrl/myapp/volunteer_delete_ground_report/');
      final res = await http.post(
        url,
        body: {'lid': lid, 'report_id': reportId.toString()},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'ok') {
          _showToast("Report deleted.");
          fetchSubmittedReports();
        } else {
          _showToast(data['message'] ?? 'Failed to delete', isError: true);
        }
      }
    } catch (e) {
      _showToast("Network error: $e", isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.sora(fontSize: 12, color: Colors.white)),
        backgroundColor: isError ? hot : calm,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: ink,
        elevation: 0,
        title: Text(
          "Ground Situation Intel",
          style: GoogleFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: calm,
          indicatorWeight: 2.5,
          labelColor: calm,
          unselectedLabelColor: textMuted,
          labelStyle:
          GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: "SUBMITTED REPORTS"),
            Tab(text: "ADD NEW REPORT"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildReportsListTab(),
          _buildNewReportFormTab(),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 1: VIEW & DELETE SUBMITTED REPORTS
  // ============================================================
  Widget _buildReportsListTab() {
    if (_isLoadingReports) {
      return const Center(
          child: CircularProgressIndicator(color: calm, strokeWidth: 2));
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage,
                style: GoogleFonts.sora(color: hot, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: fetchSubmittedReports,
              style: ElevatedButton.styleFrom(backgroundColor: ink2),
              child:
              Text("RETRY", style: GoogleFonts.sora(color: Colors.white)),
            )
          ],
        ),
      );
    }
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_outlined,
                size: 42, color: textMuted),
            const SizedBox(height: 12),
            Text(
              "No Ground Reports Logged",
              style: GoogleFonts.sora(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              "Switch to 'ADD NEW REPORT' to answer assigned tasks.",
              style: GoogleFonts.sora(fontSize: 11.5, color: textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchSubmittedReports,
      color: calm,
      backgroundColor: ink2,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final item = _reports[index];
          final String imageUrl = item['attached_image'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: ink2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: calm.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "TASK: ${item['task_title']}",
                          style: GoogleFonts.sora(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: calm),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20, color: hot),
                        onPressed: () => _deleteReport(item['id']),
                        tooltip: "Delete Report",
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    item['situation_update'] ?? '',
                    style: GoogleFonts.sora(
                        fontSize: 13, color: Colors.white, height: 1.4),
                  ),
                ),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          color: ink,
                          alignment: Alignment.center,
                          child: Text("Image unavailable",
                              style: GoogleFonts.sora(
                                  color: textMuted, fontSize: 11)),
                        ),
                      ),
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 13, color: textMuted),
                      const SizedBox(width: 5),
                      Text(
                        item['reported_at'] ?? '',
                        style: GoogleFonts.sora(
                            fontSize: 10.5, color: textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // TAB 2: ADD NEW REPORT WITH TASK DROPDOWN
  // ============================================================
  Widget _buildNewReportFormTab() {
    if (_isLoadingTasks) {
      return const Center(
          child: CircularProgressIndicator(color: calm, strokeWidth: 2));
    }

    if (_todayTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_rounded, size: 44, color: amber),
              const SizedBox(height: 12),
              Text(
                "No Tasks Assigned for Today",
                style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                "You can only submit ground reports as an answer to today's active tasks.",
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TASK DROPDOWN
          Text(
            "Select Assigned Task",
            style: GoogleFonts.sora(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: calm.withOpacity(0.5)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedTaskId,
                isExpanded: true,
                dropdownColor: cardElevated,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: calm),
                items: _todayTasks.map((task) {
                  return DropdownMenuItem<int>(
                    value: task['id'],
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_outlined,
                            size: 16, color: calm),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "${task['title']} (${task['status']})",
                            style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newId) {
                  if (newId != null) {
                    setState(() {
                      _selectedTaskId = newId;
                      final t =
                      _todayTasks.firstWhere((item) => item['id'] == newId);
                      _selectedTaskInstruction = t['instruction'] ?? '';
                    });
                  }
                },
              ),
            ),
          ),

          // TASK INSTRUCTION DISPLAY CARD
          if (_selectedTaskInstruction.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ink2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: line),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Task Requirement: $_selectedTaskInstruction",
                      style: GoogleFonts.sora(
                          fontSize: 11.5, color: textSub, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),

          // 2. SITUATION UPDATE (ANSWER)
          Text(
            "Situation Update / Answer",
            style: GoogleFonts.sora(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            style: GoogleFonts.sora(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: cardElevated,
              hintText:
              "Enter ground answer, crowd density, bottleneck report, or field actions completed...",
              hintStyle: GoogleFonts.sora(fontSize: 12, color: textMuted),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: calm)),
            ),
          ),
          const SizedBox(height: 18),

          // 3. ATTACH PHOTO
          Text(
            "Attach Ground Photo (Optional)",
            style: GoogleFonts.sora(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
          ),
          const SizedBox(height: 8),

          if (_selectedImage != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_selectedImage!,
                      height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => setState(() => _selectedImage = null),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.black87),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text("CAMERA",
                        style: GoogleFonts.sora(
                            fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: calm,
                      side: const BorderSide(color: calm),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text("GALLERY",
                        style: GoogleFonts.sora(
                            fontSize: 11.5, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSub,
                      side: const BorderSide(color: line),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 28),

          // 4. SUBMIT BUTTON
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: calm,
                foregroundColor: ink,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: ink))
                  : Text("TRANSMIT SITUATION ANSWER",
                  style: GoogleFonts.sora(
                      fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}