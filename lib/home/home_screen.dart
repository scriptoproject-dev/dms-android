import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/project.dart';
import 'package:qr_scanner_app/profile.dart';
import 'package:qr_scanner_app/boxes_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _error;

  String userName = '';
  String? photoUrl;

  @override
  @override
  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchProjects(); // 👈 actually call it
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? '';
      photoUrl = prefs.getString('photo_url');
    });
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient(baseUrl: Strings.baseUrl)
          .get('projects?status_filter=ACTIVE');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['data']['items'] as List;

        setState(() {
          _projects = items.map((e) => Project.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load projects';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /* ================= APP BAR ================= */
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primaryColor,
        elevation: 0,
        toolbarHeight: 100,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hello,',
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  Text(
                    '$userName',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => _loadUser());
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey,
                backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                    ? NetworkImage(photoUrl!)
                    : null,
                child: photoUrl == null || photoUrl!.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),

      /* ================= BODY ================= */
      body: RefreshIndicator(
        onRefresh: _fetchProjects, // ✅ best form
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROJECTS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  )
                else if (_projects.isEmpty)
                  const Text('No projects found.')
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) =>
                        _buildProjectCard(_projects[index]),
                  ),
              ],
            ),
          ),
        ),
      ),

      /* ================= FAB ================= */
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () {
          _fetchProjects(); // ✅ call it
        },
        child: const Icon(Icons.refresh, color: Colors.white),
      ),

      /* ================= BOTTOM BAR ================= */
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // ✅ REQUIRED
        currentIndex: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(Project project) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BoxesListScreen(project: project),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.fromARGB(255, 214, 238, 215), // soft green
                Color.fromARGB(255, 183, 236, 187), // very light green
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ]),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project name
              Text(
                (project.name ?? ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 10),

              // Created date row
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    // formatEpoch(1765634451),
                    formatEpoch(project.created_at),

                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // CTA
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'Open',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: primaryColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String formatEpoch(int? epochSeconds) {
    if (epochSeconds == null) return '—';
    final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return '${date.day.toString().padLeft(2, '0')} '
        '${_month(date.month)} ${date.year}';
  }

  String _month(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[m - 1];
  }
}

// github check
