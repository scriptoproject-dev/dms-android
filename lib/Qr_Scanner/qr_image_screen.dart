import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as ml;

import 'package:qr_scanner_app/constants/colors.dart';

class QRDetailsScreen extends StatefulWidget {
  final String title;
  const QRDetailsScreen({super.key, required this.title});
  @override
  State<QRDetailsScreen> createState() => _QRDetailsScreenState();
}

class _QRDetailsScreenState extends State<QRDetailsScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _cameraController; // from mobile_scanner
  Key _scannerKey = UniqueKey();
  String? _scannedData;
  bool _isPaused = false;
  final ImagePicker _picker = ImagePicker();

  bool _loadingDialogShown = false;

  @override
  void initState() {
    super.initState();
    _createController(); // create initial controller
  }

  void _createController() {
    // dispose older controller if any (dispose() is void; don't await)
    _cameraController?.dispose();

    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    // dispose the controller if present
    _cameraController?.dispose();
    super.dispose();
  }

  void _resumeScanning() {
    // clear scanned data and recreate camera when user wants to scan again
    setState(() {
      _scannerKey = UniqueKey();
      _scannedData = null;
      _isPaused = false;
      _createController(); // new controller instance
    });

    // small delay to allow widget tree to rebuild and attach
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        _cameraController?.start();
      } catch (_) {}
    });
  }

  void _toggleTorch() async {
    try {
      await _cameraController?.toggleTorch();
      setState(() {});
    } catch (_) {}
  }

  /// Scan QR/barcode from an image picked from gallery using ML Kit (aliased as `ml`)
  Future<void> _scanFromGallery() async {
    XFile? file;

    // Stop camera BEFORE launching the gallery to avoid CameraX errors.
    try {
      await _cameraController?.stop();
    } catch (_) {}

    try {
      file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        // user cancelled — recreate camera if we were scanning before
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_isPaused) _createController();
        });
        return;
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: ${e.message}')),
        );
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_isPaused) _createController();
      });
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_isPaused) _createController();
      });
      return;
    }

    // Show processing dialog (after pickImage returns)
    if (!mounted) return;
    _loadingDialogShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    ml.BarcodeScanner? barcodeScanner;
    try {
      barcodeScanner = ml.BarcodeScanner(formats: [ml.BarcodeFormat.qrCode]);

      final inputImage = ml.InputImage.fromFilePath(file.path);
      final List<ml.Barcode> barcodes =
          await barcodeScanner.processImage(inputImage);

      // close loading dialog if shown
      if (_loadingDialogShown && mounted) {
        Navigator.of(context).pop();
        _loadingDialogShown = false;
      }

      if (barcodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR/barcode found in the image')),
          );
        }
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_isPaused) _createController();
        });
        return;
      }

      final String? raw = barcodes
          .firstWhere(
            (b) => b.rawValue != null && b.rawValue!.isNotEmpty,
            orElse: () => barcodes.first,
          )
          .rawValue;

      if (raw == null || raw.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No readable data found in the QR')),
          );
        }
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_isPaused) _createController();
        });
        return;
      }

      // --- SUCCESS: set scanned data and release camera resources ---
      if (mounted) {
        setState(() {
          _scannedData = raw;
          _isPaused = true;
        });

        // Stop and dispose camera to release OS camera resources.
        try {
          await _cameraController?.stop();
        } catch (_) {}

        try {
          _cameraController?.dispose(); // dispose is void; don't await
        } catch (_) {}

        // Remove the controller so the camera widget is removed from the tree
        setState(() {
          _cameraController = null;
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        if (_loadingDialogShown) {
          Navigator.of(context).pop();
          _loadingDialogShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning image: ${e.message}')),
        );
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_isPaused) _createController();
      });
    } catch (e) {
      if (mounted) {
        if (_loadingDialogShown) {
          Navigator.of(context).pop();
          _loadingDialogShown = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning image: $e')),
        );
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_isPaused) _createController();
      });
    } finally {
      // Always close scanner to free resources
      try {
        await barcodeScanner?.close();
      } catch (_) {}

      // Ensure dialog is closed (safe guard)
      if (_loadingDialogShown && mounted) {
        Navigator.of(context).pop();
        _loadingDialogShown = false;
      }
    }
  }

  Widget _cameraOrPlaceholderWidget() {
    // If controller exists, show mobile scanner (live camera)
    if (_cameraController != null) {
      return MobileScanner(
        key: _scannerKey,
        controller: _cameraController!,
        allowDuplicates: true,
        onDetect: (Barcode barcode, MobileScannerArguments? args) {
          if (_isPaused) return;

          final String? raw = barcode.rawValue;
          if (raw == null || raw.isEmpty) return;

          debugPrint("Scanned QR Data: $raw");

          _cameraController?.stop();
          setState(() {
            _scannedData = raw;
            _isPaused = true;
          });

          // Dispose controller after capturing result to fully release camera
          try {
            _cameraController?.dispose();
          } catch (_) {}
          setState(() {
            _cameraController = null;
          });
        },
      );
    }

    // Controller is null: always show the same neutral placeholder (no picked-image preview)
    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(
          Icons.qr_code_scanner,
          color: Colors.white54,
          size: 64,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasScanned = _scannedData != null;
    final String? scannedValue = _scannedData;

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
              onPressed: () {
                if (!_isPaused) _cameraController?.stop();
                Navigator.pop(context);
              },
            ),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _cameraOrPlaceholderWidget(),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.9), width: 2),
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.flash_on, color: Colors.white),
                          onPressed: _toggleTorch,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Put this inside the Stack (near the other Positioned widgets)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _scanFromGallery,
                        child: const Icon(
                          Icons.image_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColors,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Scanned QR Details",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!hasScanned) ...[
                    const Text(
                      "Point the camera at a QR code to scan or pick an image from gallery.",
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ] else ...[
                    Builder(builder: (context) {
                      final String scanned = scannedValue!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            scanned,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: scanned));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Copied to clipboard')),
                                  );
                                },
                                child: const Text("Copy"),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _resumeScanning,
                                child: const Text("Scan again"),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
