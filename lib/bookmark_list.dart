import 'package:flutter/material.dart';
import 'package:qr_scanner_app/antibiotic_policy/compliance_popup.dart';
import 'package:qr_scanner_app/antibiotic_policy/html_content_page.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';

class BookmarkList extends StatefulWidget {
  final List<AntibioticWithStatus> bookmarkedAntibiotics;
  final Future<void> Function(List<Map<String, dynamic>>)
      submitForm; // Add this line  // Function to fetch bookmarks
  final Function? onRefreshBookmarks;
  final Future<void> Function()? fetchBookmarks;

  const BookmarkList({
    super.key,
    required this.bookmarkedAntibiotics,
    required this.submitForm,
    this.onRefreshBookmarks,
    this.fetchBookmarks,
  });

  @override
  BookmarkListState createState() => BookmarkListState();
}

class BookmarkListState extends State<BookmarkList> {
  @override
  Widget build(BuildContext context) {
    debugPrint("gBookmarked Antibiotics: ${widget.bookmarkedAntibiotics}");

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: widget.bookmarkedAntibiotics.length,
      itemBuilder: (context, index) {
        final bookmark = widget.bookmarkedAntibiotics[index];
        debugPrint(
            "Bookmark: ${bookmark.antibiotic.name}, Bookmarked: ${bookmark.bookmarked}");
        return GestureDetector(
          onTap: () {
            debugPrint('Clicked on: ${bookmark.antibiotic.name}');

            // Redirect to HtmlContentPage and pass the selected bookmark
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HtmlContentPage(
                  condition: bookmark,
                  onRefreshBookmarks: widget.onRefreshBookmarks,
                  onBookmarkToggle: widget.fetchBookmarks,
                ),
              ),
            ).then((result) {
              if (result is Map) {
                final antibioticId = result['antibioticId'] as String;
                final compliance = result['compliance'] as bool? ?? false;
                final refresh =
                    result['refresh'] as bool? ?? false; // Get refresh flag
                debugPrint("compliance--$compliance");
                debugPrint("mounted--$mounted");
                debugPrint("lenght -- ${widget.bookmarkedAntibiotics.length}");
                // Future.delayed(Duration(milliseconds: 100), () {
                if (compliance) {
                  // if (mounted && widget.bookmarkedAntibiotics.length != 1) {
                  if (compliance && mounted) {
                    CompliancePopup.show(
                        context, antibioticId, widget.submitForm);
                  }
                  // Show compliance popup if needed
                }
                // });

                if (refresh) {
                  // Call the refresh function if refresh is true
                  if (widget.fetchBookmarks != null) {
                    widget.fetchBookmarks!(); // Call the fetch function
                  }
                }
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColors,
              borderRadius: BorderRadius.circular(8),
              // boxShadow: [
              //   BoxShadow(
              //     color: Colors.grey.withOpacity(0.3),
              //     spreadRadius: 2,
              //     blurRadius: 5,
              //     offset: const Offset(0, 3),
              //   ),
              // ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bookmark name with Flexible
                Flexible(
                  child: Text(
                    bookmark.antibiotic.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis, // Ensures text doesn't overflow
                  ),
                ),
                // Bookmark icon
                const Icon(
                  Icons.bookmark,
                  color: primaryColor, // Use your primary color here
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
