import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/models/box.dart';
import 'package:qr_scanner_app/routes.dart';

class BoxDetailsScreen extends StatefulWidget {
  final BoxModel box;

  const BoxDetailsScreen({super.key, required this.box});

  @override
  State<BoxDetailsScreen> createState() => _BoxDetailsScreenState();
}

class _BoxDetailsScreenState extends State<BoxDetailsScreen> {
  late MobileScannerController _cameraController;

  bool _isScanningEnabled = true;
  bool _isCallingApi = false;

  String? _lastStickerId;
  String? _apiMessage;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _toggleTorch() async {
    try {
      await _cameraController.toggleTorch();
      setState(() {});
    } catch (_) {}
  }

  Future<void> _handleScannedValue(String raw) async {
    final String stickerId = raw.trim();

    setState(() {
      _lastStickerId = stickerId; // drives "Scan Status" UI
      _isScanningEnabled = false; // stop scanning until user taps Scan again
      _isCallingApi = true;
      _apiMessage = null;
    });

    try {
      final response = await ApiClient(baseUrl: Strings.baseUrl).post(
        'stickers/mark-dispatched',
        body: {
          'box_id': widget.box.box_id,
          'sticker_id': stickerId,
        },
      );

      if (!mounted) return;

      debugPrint('DISPATCH STATUS: ${response.statusCode}');
      debugPrint('DISPATCH BODY: ${response.body}');

      // 🔍 Try to read meaningful message from backend
      String backendMessage;
      try {
        final Map<String, dynamic> jsonResponse = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : <String, dynamic>{};

        backendMessage =
            (jsonResponse['detail'] ?? jsonResponse['message'] ?? '')
                .toString();

        // Fallback if detail/message are empty
        if (backendMessage.trim().isEmpty) {
          backendMessage = response.body;
        }
      } catch (_) {
        // In case body is not valid JSON
        backendMessage = response.body;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // ✅ Success: show whatever backend says (or generic if empty)
        _apiMessage = backendMessage.isNotEmpty
            ? backendMessage
            : 'Marked as dispatched successfully.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_apiMessage!),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // ❌ Error: still show backend message (like "Sticker is already marked as dispatched")
        _apiMessage = backendMessage.isNotEmpty
            ? backendMessage
            : 'Failed to mark dispatched (${response.statusCode})';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_apiMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _apiMessage = 'Error calling API: $e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiMessage!)),
      );
    } finally {
      if (mounted) {
        setState(() {
          // ❗ We only stop "loading" here.
          // Scanner stays disabled until user taps "Scan again".
          _isCallingApi = false;
          // _isScanningEnabled remains false
        });
      }
    }
  }

  void _onDetect(Barcode barcode, MobileScannerArguments? args) async {
    if (!_isScanningEnabled || _isCallingApi) return;

    final String? raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    debugPrint('Scanned QR data: $raw');

    // stop further scans until API is done & user taps Scan again
    setState(() {
      _isScanningEnabled = false;
    });

    await _handleScannedValue(raw);
  }

  void _scanAgain() {
    setState(() {
      _isScanningEnabled = true; // allow scanning again
      _isCallingApi = false;
      _apiMessage = null;
      _lastStickerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final boxName = widget.box.name;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'Box: $boxName',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Camera area
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    allowDuplicates: true,
                    onDetect: _onDetect,
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.9),
                          width: 2,
                        ),
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      onPressed: _toggleTorch,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Box info + scan result
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 227, 247, 223),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Box Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    'Box: $boxName',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  // Text(
                  //   'ID: $boxId',
                  //   style: const TextStyle(
                  //     fontSize: 12,
                  //     color: Colors.black54,
                  //   ),
                  // ),
                  const Divider(height: 24),
                  const Text(
                    'Scan Status',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_lastStickerId == null) ...[
                    const Text(
                      'Point the camera at a QR code on a sticker.\n'
                      'Each scan will mark that sticker as dispatched for this box.',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ] else ...[
                    if (_isCallingApi) ...[
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Marking as dispatched...'),
                        ],
                      ),
                    ] else if (_apiMessage != null) ...[
                      Text(
                        _apiMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isCallingApi ? null : _scanAgain,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                Colors.green.shade700, // ✅ text color
                          ),
                          child: const Text('Scan again'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // ✅ Home active
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, Routes.home);
          }
        },
      ),
    );
  }
}
