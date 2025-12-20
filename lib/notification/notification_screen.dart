import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/home/bottom_nav.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/notifications.dart';
import 'package:qr_scanner_app/notification/database_helper_notification.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<List<NotificationData>> _unreadNotifications;
  late Future<List<NotificationData>> _readNotifications;
  List<NotificationData> _cachedUnreadNotifications = [];
  bool isUnreadNotification = false;

  @override
  void initState() {
    super.initState();
    _fetchAndCacheNotifications();
  }

  Future<void> _fetchAndCacheNotifications() async {
    _unreadNotifications = fetchNotifications(viewed: false);
    _readNotifications = fetchNotifications(viewed: true);

    _unreadNotifications.then((notifications) {
      setState(() {
        _cachedUnreadNotifications = notifications;
      });
    });
  }

  Future<List<NotificationData>> fetchNotifications(
      {required bool viewed}) async {
    List<Map<String, dynamic>> notificationsMap =
        await DatabaseHelperNotification().getAllNotifications();

    List<NotificationData> notifications = notificationsMap.map((map) {
      return NotificationData(
        uniqueId: map['unique_id'] ?? '',
        notificationId: map['notification_id'] ?? '',
        userId: map['user_id'] ?? '',
        title: map['title'] ?? '',
        type: map['type'] ?? '',
        scheduleTime: DateTime.fromMillisecondsSinceEpoch(
          (map['schedule_time'] * 1000).toInt(),
        ),
        viewed: map['viewed'] == 1,
        received: map['received'] == 1,
        status: map['status'] ?? '',
        content: Content(
          contentId: map['content_id'] ?? '',
          comment: map['content_comment'] ?? '',
        ),
        auditLog: AuditLog(
          createdBy: map['audit_created_by'] ?? '',
          createdId: map['audit_created_id'] ?? '',
          createdOn: map['audit_created_on'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                      (map['audit_created_on'] * 1000).toInt())
                  .millisecondsSinceEpoch
              : null,
          modifiedBy: map['audit_modified_by'] ?? '',
          modifiedId: map['audit_modified_id'] ?? '',
          modifiedOn: map['audit_modified_on'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                      (map['audit_modified_on'] * 1000).toInt())
                  .millisecondsSinceEpoch
              : null,
        ),
      );
    }).toList();

    return notifications.where((n) => n.viewed == viewed).toList()
      ..sort((a, b) =>
          (b.auditLog.createdOn ?? 0).compareTo(a.auditLog.createdOn ?? 0));
  }

  String _formatDate(int? timestamp) {
    if (timestamp == null) return 'No date available';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

    // Format the time in 12-hour format with AM/PM
    final time =
        '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';

    // Format the date as "20 January 2024"
    final formattedDate =
        '${date.day} ${_getMonthName(date.month)} ${date.year}';

    return '$time - $formattedDate';
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return '';
    }
  }

  Future<bool> markNotificationAsViewed(String notificationId) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isConnected = connectivityResult.first != ConnectivityResult.none;

    if (isConnected) {
      try {
        // Online: Update server and local DB
        final response = await ApiClient(baseUrl: Strings.baseUrl).post(
          'user/notification/viewed',
          body: {
            'notification_ids': [notificationId]
          },
        );

        if (response.statusCode == 200) {
          await DatabaseHelperNotification().markAsViewed(notificationId);
          _refreshUI(notificationId); // Pass notificationId here
          return true;
        }
        if (response.statusCode == 401) {
          debugPrint('Received 401. Response body: ${response.body}');
          Fluttertoast.showToast(
              msg: 'Account Disabled. Please contact support.');
          await unregisterDeviceFromPushNotificationServer();
          if (mounted) {
            navigateToLoginScreen(context);
          }
          return false;
        }
        return false;
      } catch (e) {
        debugPrint('Error marking notification as viewed: $e');
        return false;
      }
    } else {
      // Offline: Update local DB immediately and add to pending
      await DatabaseHelperNotification().markAsViewed(notificationId);
      await DatabaseHelperNotification()
          .addPendingViewedNotification(notificationId);
      _refreshUI(notificationId);
      return true;
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      // fetch all unread notifications
      final unread = await _unreadNotifications;

      if (unread.isEmpty) return;

      final ids = unread.map((n) => n.notificationId).toList();

      final connectivityResult = await Connectivity().checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      if (isConnected) {
        try {
          final response = await ApiClient(baseUrl: Strings.baseUrl).post(
            'user/notification/viewed',
            body: {
              'notification_ids': ids,
            },
          );

          if (response.statusCode == 200) {
            // Update local DB
            for (final id in ids) {
              await DatabaseHelperNotification().markAsViewed(id);
            }
          }
          if (response.statusCode == 401) {
            debugPrint('Received 401. Response body: ${response.body}');
            Fluttertoast.showToast(
                msg: 'Account Disabled. Please contact support.');
            await unregisterDeviceFromPushNotificationServer();
            if (mounted) {
              navigateToLoginScreen(context);
            }
            return;
          }
        } catch (e) {
          debugPrint("Error marking all as read online: $e");
        }
      } else {
        // Offline: update locally + add to pending
        for (final id in ids) {
          await DatabaseHelperNotification().markAsViewed(id);
          await DatabaseHelperNotification().addPendingViewedNotification(id);
        }
      }

      // Refresh UI
      setState(() {
        _unreadNotifications = fetchNotifications(viewed: false);
        _readNotifications = fetchNotifications(viewed: true);
        _cachedUnreadNotifications.clear();
      });
    } catch (e) {
      debugPrint("Error in markAllAsRead: $e");
    }
  }

  void _refreshUI(String notificationId) {
    // Add notificationId as a parameter
    setState(() {
      _unreadNotifications = fetchNotifications(viewed: false);
      _readNotifications = fetchNotifications(viewed: true);
      _cachedUnreadNotifications = _cachedUnreadNotifications
          .where((n) => n.notificationId != notificationId)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: primaryColor,
          automaticallyImplyLeading: false,
          title: const Text(
            "Notifications",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<String?>(
                  future: _getPhotoUrl(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey,
                        child: CircularProgressIndicator(),
                      );
                    }
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: snapshot.data?.isNotEmpty == true
                          ? NetworkImage(snapshot.data!)
                          : null,
                      child: snapshot.data?.isEmpty == true
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    );
                  },
                ),
              ),
            ),
          ],
          toolbarHeight: 66,
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              child: const PreferredSize(
                preferredSize: Size.fromHeight(20),
                child: TabBar(
                  labelPadding: EdgeInsets.symmetric(vertical: 8),
                  indicatorColor: primaryColor,
                  unselectedLabelColor: gray,
                  labelColor: primaryColor,
                  labelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: [
                    Tab(text: 'Unread'),
                    Tab(text: 'Read'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildNotificationList(_unreadNotifications),
                  _buildNotificationList(_readNotifications),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNav(
          currentIndex: 3,
          isUnreadNotification: isUnreadNotification,
        ),
      ),
    );
  }

  Widget _buildNotificationList(
      Future<List<NotificationData>> futureNotifications) {
    final isUnreadTab = futureNotifications == _unreadNotifications;

    return Column(
      children: [
        if (isUnreadTab)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: _cachedUnreadNotifications.isNotEmpty
                      ? _markAllAsRead
                      : null,
                  borderRadius: BorderRadius.circular(30),
                  splashColor: _cachedUnreadNotifications.isNotEmpty
                      ? primaryColor.withOpacity(0.2)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Icon(
                        Icons.done_all,
                        color: _cachedUnreadNotifications.isNotEmpty
                            ? primaryColor
                            : Colors.grey,
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Mark all as read",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _cachedUnreadNotifications.isNotEmpty
                              ? primaryColor
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<NotificationData>>(
            future: futureNotifications,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.data?.isEmpty ?? true) {
                return const Center(child: Text('No notifications found.'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.length,
                padding: const EdgeInsets.all(16.0),
                itemBuilder: (context, index) {
                  final notification = snapshot.data![index];
                  return GestureDetector(
                    onTap: () async {
                      if (!notification.viewed) {
                        final shouldContinue = await markNotificationAsViewed(
                            notification.notificationId);
                        debugPrint("Notification Type: ${notification.type}");
                        if (!shouldContinue) return;
                      }
                      final type = notification.type.toLowerCase();
                      switch (type) {
                        case "elearn":
                          Navigator.pushNamed(context, Routes.elearn);
                          break;
                        case "antibiotic":
                          Navigator.pushNamed(context, Routes.infectionList);
                          break;
                        case "antibiogram":
                          Navigator.pushNamed(context, Routes.antibiogram);
                          break;
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color:
                            notification.viewed ? lightColor : backgroundColors,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: lightBlack,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notification.content.comment,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: likeColour,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(notification.auditLog.createdOn),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: fontLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<String?> _getPhotoUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('photo_url');
  }
}
