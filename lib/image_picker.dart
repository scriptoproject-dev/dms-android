import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:qr_scanner_app/constants/colors.dart';

class ImagePickerWidget extends StatefulWidget {
  final File? initialImage;
  final String? photoUrl;
  final Function(File?) onImagePicked;

  const ImagePickerWidget({
    super.key,
    this.initialImage,
    this.photoUrl,
    required this.onImagePicked,
  });

  @override
  _ImagePickerWidgetState createState() => _ImagePickerWidgetState();
}

void logFullUrl(String? url) {
  if (url != null) {
    const chunkSize = 100; // Print 100 characters per line
    for (int i = 0; i < url.length; i += chunkSize) {
      debugPrint(
          "URL Chunk: ${url.substring(i, i + chunkSize > url.length ? url.length : i + chunkSize)}");
    }
  } else {
    debugPrint("URL is null");
  }
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _pickedImage = widget.initialImage;
    logFullUrl(widget.photoUrl);
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
      });
      widget.onImagePicked(_pickedImage!);
    }
  }

  Future<List<int>?> _downloadImageBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('image/')) {
          debugPrint("Success");
          return response.bodyBytes;
        } else {
          debugPrint("Invalid content type: $contentType");
        }
      } else {
        debugPrint("Error: Received status code ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error downloading image: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final ImageSource? source = await showModalBottomSheet<ImageSource>(
          context: context,
          builder: (BuildContext context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                if (_pickedImage != null ||
                    (widget.photoUrl != null && widget.photoUrl!.isNotEmpty))
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text("Remove Photo"),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onImagePicked(null);
                    },
                  ),
              ],
            );
          },
        );
        if (source != null) _pickImage(source);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            child: _pickedImage != null
                ? CircleAvatar(
                    radius: 50,
                    backgroundImage: FileImage(_pickedImage!),
                  )
                : widget.photoUrl != null
                    ? FutureBuilder<List<int>?>(
                        future: _downloadImageBytes(widget.photoUrl!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          } else if (snapshot.hasError ||
                              snapshot.data == null) {
                            return const Icon(Icons.person,
                                size: 50, color: Colors.grey);
                          } else {
                            // Display image using Image.memory
                            return CircleAvatar(
                              radius: 50,
                              backgroundImage: MemoryImage(
                                  Uint8List.fromList(snapshot.data!)),
                            );
                          }
                        },
                      )
                    : const Icon(Icons.person, size: 50, color: Colors.grey),
          ),
          const Positioned(
            bottom: 0,
            right: 10,
            child: CircleAvatar(
              radius: 12,
              // backgroundColor: Theme.of(context).primaryColor,
              backgroundColor: primaryColor,
              child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
