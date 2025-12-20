// import 'dart:convert';
// import 'package:amsp_flutter/constants/colors.dart';
// import 'package:amsp_flutter/constants/strings.dart';
// import 'package:amsp_flutter/home/bottom_nav.dart';
// import 'package:amsp_flutter/keycloak/api_client.dart';
// import 'package:amsp_flutter/models/notifications.dart';
// import 'package:amsp_flutter/utilities/utilities.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
 
// class NotificationScreen extends StatefulWidget {
//   const NotificationScreen({super.key});
 
//   @override
//   State<NotificationScreen> createState() => _NotificationScreenState();
// }
 
// class _NotificationScreenState extends State<NotificationScreen> {
//   late Future<List<NotificationData>> _unreadNotifications;
//   late Future<List<NotificationData>> _readNotifications;
//   List<NotificationData> _cachedUnreadNotifications = [];
//   bool isConnected = true;
 
//   @override
//   void initState() {
//     super.initState();
//     _checkConnectivity();
//     _fetchAndCacheNotifications();
//     // _unreadNotifications = fetchNotifications(viewed: false);
//     // _readNotifications = fetchNotifications(viewed: true);
//   }
 
//   Future<void> _fetchAndCacheNotifications() async {
//     _unreadNotifications = fetchNotifications(viewed: false);
//     _readNotifications = fetchNotifications(viewed: true);
 
//     // Cache the unread notifications
//     _unreadNotifications.then((notifications) {
//       setState(() {
//         _cachedUnreadNotifications = notifications;
//       });
//     });
//   }
 
//   Future<void> _checkConnectivity() async {
//     var connectivityResult = await (Connectivity().checkConnectivity());
//     setState(() {
//       isConnected = connectivityResult != ConnectivityResult.none;
//     });
//   }
 
//   Future<List<NotificationData>> fetchNotifications(
//       {required bool viewed}) async {
//     if (!isConnected) {
//       return []; // Return an empty list if not connected
//     }
 
//     final baseUrl = Strings.baseUrl;
//     final prefs = await SharedPreferences.getInstance();
//     String userId = prefs.getString('user_id') ?? '';
 
//     final response = await ApiClient(baseUrl: baseUrl).get(
//         'user/notifications?user_id=$userId&viewed=$viewed&page=1&sort_order=asc');
//     debugPrint('API Response  notification: ${response.body}');
//     if (response.statusCode == 200) {
//       final jsonData = json.decode(response.body);
//       final notificationsResponse = NotificationsResponse.fromJson(jsonData);
//       return notificationsResponse.data;
//     } else if (response.statusCode == 401) {
//       navigateToLoginScreen(context);
//       return [];
//     } else {
//       throw Exception('Failed to load notifications');
//     }
//   }
 
//   Future<String?> _getPhotoUrl() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString('photo_url');
//   }
 
//   Future<void> markNotificationAsViewed(String notificationId) async {
//     final baseUrl = Strings.baseUrl;
 
//     Map<String, dynamic> requestBody = {
//       'notification_ids': [notificationId],
//     };
 
//     final response = await ApiClient(baseUrl: baseUrl)
//         .post('user/notification/viewed', body: requestBody);
//     debugPrint('API Response notification viewed: ${response.body}');
 
//     if (response.statusCode == 200) {
//       final jsonData = json.decode(response.body);
//       final notificationsResponse = NotificationsResponse.fromJson(jsonData);
 
//       // After successful API call, refetch notifications
//       setState(() {
//         _unreadNotifications = fetchNotifications(viewed: false);
//         _readNotifications = fetchNotifications(viewed: true);
//       });
 
//       // Update the badge count
//       setState(() {
//         _cachedUnreadNotifications = _cachedUnreadNotifications
//             .where(
//                 (notification) => notification.notificationId != notificationId)
//             .toList();
//       });
//     } else {
//       throw Exception('Failed to mark notification as viewed');
//     }
//   }
 
//   Widget _buildNotificationList(
//       Future<List<NotificationData>> futureNotifications) {
//     return FutureBuilder<List<NotificationData>>(
//       future: futureNotifications,
//       builder: (context, snapshot) {
//         if (!isConnected) {
//           return const Center(child: Text('Internet is not available.'));
//         }
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         } else if (snapshot.hasError) {
//           return Center(child: Text('Error: ${snapshot.error}'));
//         } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return const Center(child: Text('No notifications found.'));
//         }
 
//         final notifications = snapshot.data!;
//         return ListView.builder(
//           itemCount: notifications.length,
//           padding: const EdgeInsets.all(16.0),
//           itemBuilder: (context, index) {
//             final notification = notifications[index];
//             final backgroundColor =
//                 notification.viewed ? lightColor : backgroundColors;
 
//             return GestureDetector(
//               onTap: () async {
//                 if (!notification.viewed) {
//                   await markNotificationAsViewed(notification.notificationId);
//                 }
//               },
//               child: Container(
//                 margin: const EdgeInsets.symmetric(vertical: 8.0),
//                 padding: const EdgeInsets.all(10.0),
//                 decoration: BoxDecoration(
//                   color: backgroundColor,
//                   border: Border.all(color: Colors.grey.shade300),
//                   borderRadius: BorderRadius.circular(8.0),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       notification.title, // Safely access title
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: lightBlack,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       notification.content.comment, // Safely access comment
//                       style: const TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w400,
//                         color: likeColour,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
 
//   @override
//   Widget build(BuildContext context) {
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         appBar: AppBar(
//           backgroundColor: primaryColor,
//           automaticallyImplyLeading: false,
//           title: const Text(
//             "Notifications",
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           actions: [
//             GestureDetector(
//               onTap: () {
//                 Navigator.pushNamed(context, '/profile');
//               },
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: FutureBuilder<String?>(
//                   future: _getPhotoUrl(),
//                   builder: (context, snapshot) {
//                     if (snapshot.connectionState == ConnectionState.waiting) {
//                       return const CircleAvatar(
//                         radius: 20,
//                         backgroundColor: Colors.grey,
//                         child: CircularProgressIndicator(),
//                       );
//                     } else if (snapshot.data != null &&
//                         snapshot.data!.isNotEmpty) {
//                       return CircleAvatar(
//                         radius: 20,
//                         backgroundImage: NetworkImage(snapshot.data!),
//                       );
//                     } else {
//                       return const CircleAvatar(
//                         radius: 20,
//                         backgroundColor: Colors.grey,
//                         child: Icon(Icons.person, color: Colors.white),
//                       );
//                     }
//                   },
//                 ),
//               ),
//             ),
//           ],
//           toolbarHeight: 66,
//         ),
//         body: Column(
//           children: [
//             Container(
//               color: Colors.white,
//               child: const PreferredSize(
//                 preferredSize: Size.fromHeight(20), // Set the desired height
//                 child: TabBar(
//                   labelPadding: EdgeInsets.symmetric(vertical: 8),
//                   indicatorColor: primaryColor,
//                   unselectedLabelColor: gray,
//                   labelColor: primaryColor,
//                   labelStyle: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                   unselectedLabelStyle: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                   ),
//                   tabs: [
//                     Tab(text: 'Unread'),
//                     Tab(text: 'Read'),
//                   ],
//                 ),
//               ),
//             ),
//             Expanded(
//               child: TabBarView(
//                 children: [
//                   _buildNotificationList(_unreadNotifications),
//                   _buildNotificationList(_readNotifications),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         // bottomNavigationBar: KeyedSubtree(
//         //   key: UniqueKey(),
//         //   child: BottomNav(
//         //     currentIndex: 3,
//         //     badgeCount: _cachedUnreadNotifications.length,
//         //   ),
//         // ),
//         bottomNavigationBar: BottomNav(
//           currentIndex: 3,
//           badgeCount: _cachedUnreadNotifications.length,
//         ),
 
//         // bottomNavigationBar: FutureBuilder<List<NotificationData>>(
//         //   future: _unreadNotifications,
//         //   builder: (context, snapshot) {
//         //     if (snapshot.connectionState == ConnectionState.waiting) {
//         //       return const CircularProgressIndicator();
//         //     } else if (snapshot.hasError) {
//         //       return Text('Error: ${snapshot.error}');
//         //     } else {
//         //       return BottomNav(
//         //         currentIndex: 3,
//         //         badgeCount: snapshot.data?.length ?? 0,
//         //       );
//         //     }
//         //   },
//         // ),
//       ),
//     );
//   }
// }