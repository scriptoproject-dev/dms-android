import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/routes.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final bool? isUnreadNotification;
  final Function? onRefreshBookmarks;
  final Function? onItemTapped;

  const BottomNav({
    super.key,
    required this.currentIndex,
    this.isUnreadNotification,
    this.onRefreshBookmarks,
    this.onItemTapped,
  });

  @override
  BottomNavState createState() => BottomNavState();
}

class BottomNavState extends State<BottomNav> {
  void _onItemTapped(int index) {
    debugPrint('badgeCount: ${widget.isUnreadNotification}');
    // If the index is the same as the current index, do nothing to avoid redundant navigation
    if (widget.currentIndex == index) return;
    widget.onItemTapped?.call(index);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return Routes.getScreenByIndex(index);
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400,
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left side items
          Flexible(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  0,
                  'Home',
                  'assets/images/homebt.png',
                  selectedAssetPath: 'assets/images/home.png',
                ),
                _buildNavItem(
                  1,
                  'Bookmarks',
                  'assets/images/Intersect.png',
                  selectedAssetPath: 'assets/images/bookmarkpr.png',
                ),
              ],
            ),
          ),

          // Center chat icon
          Flexible(
            flex: 1,
            child: _buildNavItem(
              2,
              '',
              'assets/images/chat.png',
              selectedAssetPath: 'assets/images/chat.png',
              isCenterIcon: true,
            ),
          ),

          // Right side items
          Flexible(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  3,
                  'Notifications',
                  'assets/images/bellbt.png',
                  selectedAssetPath: 'assets/images/bellpr.png',
                  // badgeCount: widget.badgeCount,
                ),
                _buildNavItem(
                  4,
                  'Feedback',
                  'assets/images/feedback.png',
                  selectedAssetPath: 'assets/images/feedbackpr.png',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    String label,
    String assetPath, {
    required String selectedAssetPath,
    bool isCenterIcon = false,
  }) {
    bool isSelected = widget.currentIndex == index;
    double iconSize = isCenterIcon ? 48 : 24;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _onItemTapped(index),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensures content aligns properly
            mainAxisAlignment: MainAxisAlignment.center,
            // children: [
            //   Image.asset(
            //     isSelected ? selectedAssetPath : assetPath,
            //     height: isCenterIcon ? 48 : 24,
            //     width: isCenterIcon ? 48 : 24,
            //   ),
            //   if (label.isNotEmpty)
            //     Padding(
            //       padding: const EdgeInsets.only(
            //           top: 4.0), // Adds spacing between icon and text
            //       child: Text(
            //         label,
            //         style: TextStyle(
            //           fontSize: 12,
            //           color: isSelected ? primaryColor : Colors.black,
            //         ),
            //       ),
            //     ),
            // ],
            children: [
              // Container to give consistent sizing for the icon
              Container(
                height: iconSize,
                width: iconSize,
                alignment: Alignment.center,
                child: Image.asset(
                  isSelected ? selectedAssetPath : assetPath,
                  height: iconSize,
                  width: iconSize,
                ),
              ),
              if (label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? primaryColor : Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (index == 3 && (widget.isUnreadNotification == true))
          Positioned(
            top: 4, // Adjust this value to move the badge up/down
            right: 27,
            child: Container(
              // padding: const EdgeInsets.all(4),
              width: 9, // Fixed size for the dot
              height: 9,
              decoration: BoxDecoration(
                color: notificationColor,
                // borderRadius: BorderRadius.circular(50),
                borderRadius: BorderRadius.circular(6),
                // border: Border.all(color: Colors.white),
              ),
              // child: Text(
              //   badgeCount.toString(),
              //   style: const TextStyle(
              //     fontSize: 10,
              //     color: Colors.white,
              //   ),
              // ),
            ),
          ),
      ],
    );
  }
}
