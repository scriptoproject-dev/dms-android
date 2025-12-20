import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:qr_scanner_app/Qr_Scanner/qr_image_screen.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/routes.dart';

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor, // same as other screens
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Text(
              "QR Scanner",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      ),

      // BODY → same card-list design as InfectionListScreen root category list
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _buildCard(context, "Scan QR Code 1"),
          _buildCard(context, "Scan QR Code 2"),
          _buildCard(context, "Scan QR Code 3"),
        ],
      ),
    );
  }

  // NOTE: take BuildContext so we can push routes from inside this helper
  Widget _buildCard(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColors, // same card color
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: ListTile(
          title: Text(
            title,
            style: const TextStyle(color: Colors.black),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QRScannerSecondScreen(title: title),
              ),
            );
          },
        ),
      ),
    );
  }
}

class QRScannerSecondScreen extends StatelessWidget {
  final String title;

  const QRScannerSecondScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _buildCard(context, "$title - Item 1"),
          _buildCard(context, "$title - Item 2"),
          _buildCard(context, "$title - Item 3"),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColors,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: ListTile(
          title: Text(
            title,
            style: const TextStyle(color: Colors.black),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QRDetailsScreen(title: title),
              ),
            );
          },
        ),
      ),
    );
  }
}
