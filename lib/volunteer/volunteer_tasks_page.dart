import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VolunteerTasksPage extends StatefulWidget {
  const VolunteerTasksPage({super.key});

  @override
  State<VolunteerTasksPage> createState() => _VolunteerTasksPageState();
}

class _VolunteerTasksPageState extends State<VolunteerTasksPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  int _pendingCount = 0;
  String _errorMessage = '';
  String _selectedFilter = 'ALL';

  // CrowdSense Dark Theme Tokens
  static const Color ink = Color(0xFF0A0F24);
  static const Color ink2 = Color(0xFF111A3D);
  static const Color cardElevated = Color(0xFF162252);
  static const Color line = Color(0x24FFFFFF);
  static const Color textMuted = Color(0xFF9AA5C9);
  static const Color textSub = Color(0xFFB9C2E0);
  static const Color calm = Color(0xFF19C3A6);
  static const Color hot = Color(0xFFFF4D4D);
  static const Color amber = Color(0xFFFF9F1C);
  static const Color indigo = Color(0xFF4338CA);

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  // ============================================================
  // FETCH TASKS
  // ============================================================
  Future<void> fetchTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final url = Uri.parse('$baseUrl/myapp/volunteer_view_tasks/');

      final response = await http.post(
        url,
        body: {'lid': lid, 'status': _selectedFilter},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          setState(() {
            _tasks = List<Map<String, dynamic>>.from(res['data'] ?? []);
            _pendingCount = res['pending_count'] ?? 0;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = res['message'] ?? 'Failed to retrieve tasks.';
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
        _errorMessage = "Network error: $e";
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // UPDATE TASK STATUS
  // ============================================================
  Future<void> updateTaskStatus(int taskId, String newStatus) async {
    try {
      final SharedPreferences sh = await SharedPreferences.getInstance();
      String baseUrl = sh.getString('url') ?? '';
      String lid = sh.getString('lid') ?? '';
      baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), '');

      final url = Uri.parse('$baseUrl/myapp/volunteer_update_task_status/');

      final response = await http.post(
        url,
        body: {
          'lid': lid,
          'task_id': taskId.toString(),
          'status': newStatus,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (res['status'] == 'ok') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Task marked as ${newStatus.replaceAll('_', ' ')}",
                style: GoogleFonts.sora(fontSize: 12.5, color: Colors.white),
              ),
              backgroundColor: newStatus == 'DECLINED' ? hot : calm,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          fetchTasks();
        } else {
          _showToast(res['message'] ?? 'Failed to update status');
        }
      } else {
        _showToast("Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showToast("Connection failed: $e");
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.sora(fontSize: 12, color: Colors.white)),
        backgroundColor: hot,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return amber;
      case 'ACCEPTED':
        return const Color(0xFF38BDF8);
      case 'IN_PROGRESS':
        return const Color(0xFFC026D3);
      case 'COMPLETED':
        return calm;
      case 'DECLINED':
        return hot;
      default:
        return textMuted;
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
          "Field Action Directives",
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: calm),
            onPressed: fetchTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: calm, strokeWidth: 2))
                : _errorMessage.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage, style: GoogleFonts.sora(color: hot, fontSize: 13)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: fetchTasks,
                    style: ElevatedButton.styleFrom(backgroundColor: ink2),
                    child: Text("RETRY", style: GoogleFonts.sora(color: Colors.white)),
                  )
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: fetchTasks,
              color: calm,
              backgroundColor: ink2,
              child: _tasks.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  return _buildTaskCard(_tasks[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['ALL', 'PENDING', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED', 'DECLINED'];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final isSelected = _selectedFilter == f;

          return ChoiceChip(
            label: Text(
              f == 'ALL' ? 'ALL (${_tasks.length})' : f.replaceAll('_', ' '),
              style: GoogleFonts.sora(
                fontSize: 10.5,
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
                setState(() => _selectedFilter = f);
                fetchTasks();
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final int taskId = task['id'] ?? 0;
    final String status = (task['status'] ?? 'PENDING').toString().toUpperCase();
    final Color statusColor = _getStatusColor(status);
    final String alertSev = (task['alert_severity'] ?? 'MEDIUM').toString().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: ink2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status == 'PENDING' ? amber.withOpacity(0.5) : line),
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
          // Header Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
                decoration: BoxDecoration(
                  color: (alertSev == 'CRITICAL' ? hot : amber).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$alertSev ALERT",
                  style: GoogleFonts.sora(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: alertSev == 'CRITICAL' ? hot : amber,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Alert Association
          Text(
            task['title'] ?? 'Emergency Task',
            style: GoogleFonts.sora(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: calm),
              const SizedBox(width: 4),
              Text(
                task['area_name'] ?? 'Assigned Zone',
                style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w600, color: textSub),
              ),
              const SizedBox(width: 8),
              Text("•", style: GoogleFonts.sora(color: textMuted)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task['alert_title'] ?? '',
                  style: GoogleFonts.sora(fontSize: 11, color: textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tactical Instruction
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.assignment_outlined, size: 16, color: calm),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task['instruction'] ?? 'No explicit instructions provided.',
                    style: GoogleFonts.sora(fontSize: 11.5, color: textSub, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Assigned Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Assigned: ${task['assigned_at']}",
                style: GoogleFonts.sora(fontSize: 10, color: textMuted),
              ),
              if (task['completed_at'] != null)
                Text(
                  "Done: ${task['completed_at']}",
                  style: GoogleFonts.sora(fontSize: 10, color: calm),
                ),
            ],
          ),
          const Divider(color: line, height: 22),

          // Interactive Action Buttons depending on status
          _buildActionButtons(taskId, status),
        ],
      ),
    );
  }

  Widget _buildActionButtons(int taskId, String status) {
    if (status == 'PENDING') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => updateTaskStatus(taskId, 'DECLINED'),
              style: OutlinedButton.styleFrom(
                foregroundColor: hot,
                side: const BorderSide(color: hot),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              child: Text("DECLINE", style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => updateTaskStatus(taskId, 'ACCEPTED'),
              style: ElevatedButton.styleFrom(
                backgroundColor: calm,
                foregroundColor: ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              child: Text("ACCEPT DIRECTIVE", style: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    } else if (status == 'ACCEPTED') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => updateTaskStatus(taskId, 'IN_PROGRESS'),
          icon: const Icon(Icons.play_arrow_rounded, size: 18),
          label: Text("START FIELD MISSION", style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC026D3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 9),
          ),
        ),
      );
    } else if (status == 'IN_PROGRESS') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => updateTaskStatus(taskId, 'COMPLETED'),
          icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
          label: Text("MARK MISSION AS COMPLETED", style: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: calm,
            foregroundColor: ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 9),
          ),
        ),
      );
    } else {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          status == 'COMPLETED' ? "✓ MISSION SAFELY ACCOMPLISHED" : "MISSION DECLINED",
          style: GoogleFonts.sora(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: status == 'COMPLETED' ? calm : textMuted,
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ink2, shape: BoxShape.circle, border: Border.all(color: line)),
            child: const Icon(Icons.checklist_rounded, size: 40, color: calm),
          ),
          const SizedBox(height: 14),
          Text(
            "No Active Tasks Found",
            style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            "You have no pending field directives under this category.",
            style: GoogleFonts.sora(fontSize: 11.5, color: textMuted),
          ),
        ],
      ),
    );
  }
}