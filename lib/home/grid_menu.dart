import 'package:flutter/material.dart';
import 'package:qr_scanner_app/routes.dart';
import 'package:qr_scanner_app/utilities/notification_service.dart';

class GridMenu extends StatelessWidget {
  // final List<Antibiotic> infections;
  // final List<AntibioticWithStatus> antibiotics;
  final Function? onRefreshBookmarks;

  const GridMenu({
    super.key,
    // required this.infections,
    // required this.antibiotics,
    this.onRefreshBookmarks,
  });

  @override
  Widget build(BuildContext context) {
    // debugPrint(
    //     "Antibiotics List: ${antibiotics.map((e) => e.antibiotic.name).toList()}");
    return GridView.builder(
      padding: EdgeInsets.zero, // Remove all padding around the grid
      shrinkWrap: true, // Ensure GridView only takes up necessary height
      physics: const NeverScrollableScrollPhysics(), // Disable scrolling
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.28, // Set the aspect ratio as needed
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
      ),
      itemCount: 3, // 4 grid items
      itemBuilder: (context, index) {
        final titles = [
          'Project',
          'Project 2',
          'Project 3',
        ];
        final images = [
          'assets/images/antibiotic-policy.png',
          'assets/images/antibiogram.png',
          'assets/images/treatment-guidelines.png',
          'assets/images/e-Learn-module.png'
        ];
        return _buildGridItem(context, titles[index], images[index], index);
      },
    );
  }

  Widget _buildGridItem(
      BuildContext context, String title, String imagePath, int index) {
    return GestureDetector(
      onTap: () => _handleGridItemTap(context, index),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF6DFF7), // Background color
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(imagePath),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    // Allow flexible space usage for text
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _handleGridItemTap(context, index),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleGridItemTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(context, Routes.qrScannerFirstScreen).then((_) {
          NotificationService().checkForUnreadNotifications();
        });
        break;

      // case 0:
      //   Navigator.pushNamed(
      //     context,
      //     Routes.infectionList,
      //     arguments: {
      //       'onRefreshBookmarks': onRefreshBookmarks,
      //     },
      //   ).then((_) {
      //     // refresh badge when coming back
      //     NotificationService().checkForUnreadNotifications();
      //   });
      //   break;
      case 1:
        Navigator.pushNamed(context, Routes.antibiogram).then((_) {
          NotificationService().checkForUnreadNotifications();
        });
        break;
      case 2:
        Navigator.pushNamed(context, Routes.treatmentGuidelines).then((_) {
          NotificationService().checkForUnreadNotifications();
        });
        break;
      case 3:
        Navigator.pushNamed(context, Routes.elearn).then((_) {
          NotificationService().checkForUnreadNotifications();
        });
        break;
      default:
        break;
    }
  }
}
