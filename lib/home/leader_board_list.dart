import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardList extends StatefulWidget {
  final bool isOffline;
  final Function(bool) onDataEmpty;

  const LeaderboardList(
      {super.key, required this.isOffline, required this.onDataEmpty});

  @override
  _LeaderboardListState createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<LeaderboardList> {
  List<Map<String, dynamic>> leaders = [];
  bool isLoading = false;
  bool isDataEmpty = false;
  // bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeLeaderboardScreen();
  }

  Future<void> _initializeLeaderboardScreen() async {
    final prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('user_id') ?? '';

    if (userId.isNotEmpty) {
      // Only call these methods if userId is available
      _fetchLeaderboardData();
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.login, // Use the named route for login
        (Route<dynamic> route) => false, // Remove all previous routes
      );
    }
  }

  Future<void> _fetchLeaderboardData() async {
    setState(() {
      isLoading = true;
      isDataEmpty = false;
    });
    final baseUrl = Strings.baseUrl.replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    String siteId = prefs.getString('site_id') ?? '';
    debugPrint("siteId-s-$siteId");

    try {
      final response = await ApiClient(baseUrl: baseUrl).get(
        'metrics/department_leaderboard?from_date=0&to_date=${_getTodayEpochTime().toString()}&site_id=$siteId',
      );

      debugPrint(
          'Requesting leaderbord API: $baseUrl/metrics/department_leaderboard?from_date=0&to_date=${_getTodayEpochTime().toString()}&site_id=$siteId');

      debugPrint('API Response Status Code: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          leaders = (jsonData['data'] as List<dynamic>).map((leader) {
            return {
              'name': leader['department_name'],
              'score': leader['total_score'],
            };
          }).toList();

          // Check if the data is empty
          isDataEmpty = leaders.isEmpty;
          widget.onDataEmpty(isDataEmpty);
        });
      } else if (response.statusCode == 401) {
        debugPrint('Received 401. Response body: ${response.body}');
        Fluttertoast.showToast(
            msg: 'Account Disabled. Please contact support.');
        await unregisterDeviceFromPushNotificationServer();
        if (mounted) {
          navigateToLoginScreen(context);
        }
        return;
      } else if (response.statusCode == 404) {
        debugPrint('API endpoint not found');
      } else {
        debugPrint(
            'Failed to load leaderboard data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      } else {
        isLoading = false;
      }
    }
  }

  int _getTodayEpochTime() {
    final now = DateTime.now();
    return now.millisecondsSinceEpoch ~/ 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
      child: widget.isOffline
          ? Container() // Do not show anything if offline
          : isLoading
              ? Container() // Show nothing if loading
              : isDataEmpty
                  ? Container() // Show nothing if data is empty
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  'RANK',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: gray,
                                      fontSize: 11),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'DEPARTMENT',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: gray,
                                      fontSize: 11),
                                  textAlign: TextAlign.left,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'POINTS',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: gray,
                                      fontSize: 11),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                              height: 8), // Space between header and list

                          // Leaderboard List
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: leaders.length,
                            itemBuilder: (context, index) {
                              final leader = leaders[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Rank - left aligned
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(fontSize: 12),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    // Department Name - left aligned
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        leader['name'],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                    // Points - right aligned
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${leader['score']}',
                                        style: const TextStyle(fontSize: 12),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
    );
  }
}
