import 'package:flutter/material.dart';

class ImageRowWidget extends StatelessWidget {
  final List<String> imagePaths; // List of image paths

  const ImageRowWidget({super.key, required this.imagePaths});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14.0, right: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Equal spacing
        children: imagePaths.map((imagePath) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4.0), // Optional padding between images
              child: SizedBox(
                height: 64, // Set the height of the container
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain, // Adjust the fit as needed
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
