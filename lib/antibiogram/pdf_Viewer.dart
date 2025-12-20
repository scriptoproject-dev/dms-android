import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PDFViewerScreen extends StatelessWidget {
  final String pdfFilePath; // Local file path

  const PDFViewerScreen({super.key, required this.pdfFilePath});

  @override
  Widget build(BuildContext context) {
    // Check if the file exists
    final File pdfFile = File(pdfFilePath);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 10.0,
        title: const Text(
          'Growth Culture Data',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
      body: pdfFile.existsSync()
          ? SfPdfViewer.file(pdfFile) // Open the local PDF file
          : const Center(
              child: Text(
                'Error: PDF file not found!',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
            ),
    );
  }
}
