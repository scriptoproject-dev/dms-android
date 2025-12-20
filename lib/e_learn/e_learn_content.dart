import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/constants/strings.dart';
import 'package:qr_scanner_app/e_learn/e_Learn_pdf_viewer.dart';
import 'package:qr_scanner_app/e_learn/e_learn_api_services.dart';
import 'package:qr_scanner_app/e_learn/e_learn_database_helper.dart';
import 'package:qr_scanner_app/e_learn/video_player.dart';
import 'package:qr_scanner_app/e_learn/video_player_manager.dart';
import 'package:qr_scanner_app/home/home_screen.dart';
import 'package:qr_scanner_app/keycloak/api_client.dart';
import 'package:qr_scanner_app/utilities/utilities.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class ELearnContentScreen extends StatefulWidget {
  final String title;
  final String description;
  final String eLearnId;
  final String thumbnailId;
  final String modifiedOn;
  final int liked;
  final int disliked;

  const ELearnContentScreen({
    super.key,
    required this.title,
    required this.description,
    required this.eLearnId,
    required this.thumbnailId,
    required this.modifiedOn,
    required this.liked,
    required this.disliked,
  });

  @override
  ELearnContentScreenState createState() => ELearnContentScreenState();
}

class ELearnContentScreenState extends State<ELearnContentScreen> {
  final bool _isFullscreen = false;
  List<Map<String, dynamic>> files = [];
  bool isLoading = true;
  bool liked = false;
  bool disliked = false;

  String? currentPlayingFilePath;
  final ElearnDatabaseHelper dbHelper = ElearnDatabaseHelper();
  late Connectivity connectivity;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  List<Map<String, dynamic>> offlineMetrics = [];

  // To stop Video playing background
  final videoPlayerManager = VideoPlayerManager();

  @override
  void initState() {
    super.initState();
    connectivity = Connectivity();
    fetchFiles();
    liked = widget.liked == 1;
    disliked = widget.disliked == 1;
    _postMetric('view', isView: true);
    // initNetworkCheck();
    // _initializeOfflineMetricUpload();
  }

  Future<bool> checkPermissions() async {
    // For Android 13 (API level 33+) and above, request media-specific permissions
    if (await Permission.storage.isGranted) {
      // Check if the app already has access to storage on older versions
      return true;
    }

    if (await Permission.photos.isGranted ||
        await Permission.photos.request().isGranted) {
      // If accessing photos (images) on Android 13+ is required
      return true;
    } else if (await Permission.videos.isGranted ||
        await Permission.videos.request().isGranted) {
      // If accessing videos is required
      return true;
    } else if (await Permission.audio.isGranted ||
        await Permission.audio.request().isGranted) {
      // If accessing audio files is required
      return true;
    }

    // If none of the above permissions are granted
    return false;
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> fetchFiles() async {
    try {
      if (!(await checkPermissions())) {
        debugPrint('Permission denied. Cannot fetch files.');
        return;
      }

      final fetchedFiles = await dbHelper.getFilesByElearnId(widget.eLearnId);

      if (fetchedFiles.isNotEmpty) {
        List<Map<String, dynamic>> filesWithPaths = [];
        Set<String> filePathsSet = {};

        for (var file in fetchedFiles) {
          debugPrint(
            'File Details -> File ID: ${file['file_id']}, '
            'File Name: ${file['file_name']}, '
            'Download URL: ${file['download_url']}, '
            'Content Type: ${file['content_type']}',
          );

          Directory baseDir = await getApplicationDocumentsDirectory();
          // Construct the file path using file_id instead of file_name
          String format = file['content_type'].split('/').last;
          if (format == 'jpeg') format = 'jpg';
          final String filePath = '${baseDir.path}/${file['file_id']}.$format';
          final String fileName = '${file['file_id']}';
          final fileInStorage = File(filePath);

//---take file name for the pdf file to display----
          final String rawFileName =
              file['file_name'] as String? ?? file['file_id']!;
          final String displayName =
              file['file_name'] as String? ?? 'Unknown.pdf';

          // debugPrint('File path in elearn_content: $filePath');
          // debugPrint('File name in elearn_content: $fileName');

          try {
            // Handle link content type
            if (file['content_type'].toLowerCase().contains('link')) {
              debugPrint('Link found: ${file['file_name']}');
              filesWithPaths.add({
                ...file,
                'filePath': file['download_url'],
                'fileName': file['file_name'],
                'type': 'link',
              });
              continue;
            }
            if (await fileInStorage.exists()) {
              if (filePathsSet.contains(filePath)) {
                debugPrint('Duplicate file detected: $filePath');
                continue;
              }
              debugPrint('File found: $filePath');
              filePathsSet.add(filePath);
              var modifiableFile = {
                ...file,
                'filePath': filePath,
                'fileName': rawFileName,
                'displayName': displayName,
              };

              final contentType = file['content_type'].toLowerCase();
              if (contentType.contains('video')) {
                modifiableFile['type'] = 'video';

                // —— NEW: get actual aspect ratio ——
                final tempController =
                    VideoPlayerController.file(File(filePath));
                try {
                  await tempController.initialize();
                  final ar = tempController.value.aspectRatio;

                  final isPortrait = ar < 1.0;
                  modifiableFile['aspectRatio'] = ar;
                  modifiableFile['isPortrait'] = isPortrait;

                  final humanPortraitRatio = (1 / ar).toStringAsFixed(3);
                  debugPrint('Portrait ratio H:W → $humanPortraitRatio : 1');
                  modifiableFile['aspectRatio'] = ar;
                  final size = tempController.value.size;
                  debugPrint('Video dimensions: ${size.width}×${size.height}');
                  debugPrint('Aspect ratio: ${size.width / size.height}');
                } catch (e) {
                  debugPrint('Failed to get aspect ratio: $e');
                  modifiableFile['aspectRatio'] = 16 / 9;
                  modifiableFile['isPortrait'] = false;
                } finally {
                  await tempController.dispose();
                }
              } else if (contentType.contains('image')) {
                modifiableFile['type'] = 'image';
              } else if (contentType.contains('pdf')) {
                modifiableFile['type'] = 'pdf';
              } else {
                debugPrint('Unsupported content type: $contentType');
                continue;
              }

              filesWithPaths.add(modifiableFile);
              debugPrint('Modifiable File path: ${modifiableFile['filePath']}');
            } else {
              debugPrint('File not found: $filePath');
            }
          } catch (e) {
            debugPrint('Error accessing file: $e');
          }
        }

        setState(() {
          files = filesWithPaths;
          currentPlayingFilePath =
              filesWithPaths.isNotEmpty ? filesWithPaths[0]['filePath'] : null;
          isLoading = false;
        });
      } else {
        debugPrint('No files found for eLearnId: ${widget.eLearnId}');
      }
    } catch (e) {
      debugPrint('Error fetching files: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Popping the same values when back button is pressed
        debugPrint('Popping with Liked: $liked, Disliked: $disliked');
        Navigator.of(context).pop({
          'liked': liked,
          'disliked': disliked,
          'backPressed': true,
        });
        return Future.value(true);
      },
      child: PopScope(
        child: Scaffold(
          appBar: _isFullscreen
              ? null
              : AppBar(
                  backgroundColor: primaryColor,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        videoPlayerManager.stopAllVideos();
                        debugPrint(
                            'Popping with Liked: $liked, Disliked: $disliked');
                        Navigator.of(context).pop({
                          'liked': liked,
                          'disliked': disliked,
                          'backPressed': true,
                        });
                      },
                    ),
                  ),
                  title: Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 18.5),
                      child: IconButton(
                        icon: const Icon(Icons.home_outlined,
                            color: Colors.white, size: 30),
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                videoPlayerManager.stopAllVideos();
                                // Now return the HomeScreen widget
                                return const HomeScreen();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isFullscreen
                  ? Center(
                      child: ELearnPlayer(
                        videoFilePath: currentPlayingFilePath!,
                        // onFullscreenChanged: _onFullscreenChanged,
                        videoPlayerManager: videoPlayerManager,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_isFullscreen) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 16.0),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      widget.modifiedOn,
                                      style: const TextStyle(
                                          color: likeColour,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.title,
                                style: const TextStyle(
                                    color: lightBlack,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Divider(color: Colors.grey, thickness: 1),
                            ],
                            if (!_isFullscreen) ...[
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: files.length,
                                itemBuilder: (context, index) {
                                  var file = files[index];
                                  String filePath = file['filePath'];
                                  String fileType = file['type'];
                                  final isPortrait = fileType == 'video'
                                      ? (file['isPortrait'] ?? false)
                                      : false;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Center(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (fileType == 'video') {
                                            setState(() {
                                              currentPlayingFilePath =
                                                  currentPlayingFilePath ==
                                                          filePath
                                                      ? null
                                                      : filePath;
                                            });
                                          } else if (fileType == 'pdf') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) {
                                                videoPlayerManager
                                                    .stopAllVideos();
                                                return ELearnPdfViewer(
                                                  pdfFilePath: file['filePath'],
                                                  fileName: file['displayName'],
                                                );
                                              }),
                                            );
                                          } else if (fileType == 'link') {
                                            launchURL(file['file_name']);
                                          }
                                        },
                                        child: Container(
                                          color: Colors.white,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if (fileType == 'video') ...[
                                                SizedBox(
                                                  height: 200,
                                                  child: AspectRatio(
                                                    aspectRatio: 16 / 9,
                                                    child: ELearnPlayer(
                                                      videoFilePath: filePath,
                                                      // onFullscreenChanged:
                                                      //     _onFullscreenChanged,
                                                      videoPlayerManager:
                                                          videoPlayerManager,
                                                      isPortrait: isPortrait,
                                                    ),
                                                  ),
                                                ),
                                              ] else if (fileType ==
                                                  'image') ...[
                                                Container(
                                                  color: Colors.transparent,
                                                  child: Image.file(
                                                    File(filePath),
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ] else if (fileType == 'pdf') ...[
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                      12.0),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade300),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.grey
                                                            .withOpacity(0.2),
                                                        spreadRadius: 2,
                                                        blurRadius: 5,
                                                        offset:
                                                            const Offset(0, 3),
                                                      ),
                                                    ],
                                                  ),
                                                  child: InkWell(
                                                    onTap: () {
                                                      videoPlayerManager
                                                          .stopAllVideos();
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              ELearnPdfViewer(
                                                            pdfFilePath: file[
                                                                'filePath'],
                                                            fileName: file[
                                                                'fileName'],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: SizedBox(
                                                      height: 60,
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                              Icons
                                                                  .picture_as_pdf_sharp,
                                                              color:
                                                                  primaryColor,
                                                              size: 30),
                                                          const SizedBox(
                                                              width: 12),
                                                          Expanded(
                                                            child: Text(
                                                              file['displayName'] ??
                                                                  'PDF Document',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ] else if (fileType ==
                                                  'link') ...[
                                                Container(
                                                  color: Colors.transparent,
                                                  padding: const EdgeInsets.all(
                                                      12.0),
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      launchURL(
                                                          file['file_name']);
                                                    },
                                                    child: Text(
                                                      file['file_name'],
                                                      style: const TextStyle(
                                                          color: primaryColor,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                          decorationColor:
                                                              likeColour),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            ],
                            if (!_isFullscreen) ...[
                              const SizedBox(
                                height: 4,
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    widget.description,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                        color: likeColour, fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  void launchURL(String url) async {
    final Uri uri = Uri.parse(url); // Convert the URL string to a Uri object
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch the URL: $url');
    }
  }

  Future<void> _postMetric(String type,
      {bool isAdding = true, bool isView = false}) async {
    Map<String, dynamic> metrics = {
      'elearn_id': widget.eLearnId,
      'date': DateTime.now().millisecondsSinceEpoch / 1000,
    };

    if (isView) {
      metrics['view'] = true;
    } else if (type == 'like') {
      metrics['like'] = liked;
      metrics['dislike'] = false;
    } else if (type == 'dislike') {
      metrics['dislike'] = disliked;
      metrics['like'] = false;
    }

    List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();

    if (connectivityResult.first != ConnectivityResult.none) {
      debugPrint("Posting metrics to API: $metrics");
      final apiClient = ApiClient(baseUrl: Strings.baseUrl);
      final eLearnApiService = ELearnApiService(apiClient: apiClient);

      try {
        final response = await eLearnApiService.postElearnMetric([metrics]);
        if (response['status'] == 201) {
          debugPrint("Successfully posted metrics");
        } else if (response['status'] == 401) {
          Fluttertoast.showToast(
              msg: 'Account Disabled. Please contact support.');
          await unregisterDeviceFromPushNotificationServer();
          if (mounted) navigateToLoginScreen(context);
        } else {
          throw Exception(response['message'] ?? 'Failed to post data');
        }
      } catch (e) {
        debugPrint("Error posting metric: $e");
      }
    } else {
      debugPrint("No network. Storing metrics in database: $metrics");
      await dbHelper.storeOfflineMetric(metrics);
    }
  }
}
