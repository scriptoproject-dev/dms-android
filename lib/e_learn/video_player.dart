import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/e_learn/video_player_full_screen.dart';
import 'package:qr_scanner_app/e_learn/video_player_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:async';

class ELearnPlayer extends StatefulWidget {
  final String videoFilePath;
  // final Function(bool) onFullscreenChanged;
  final VideoPlayerManager videoPlayerManager;
  final bool? isPortrait;

  const ELearnPlayer({
    super.key,
    required this.videoFilePath,
    // required this.onFullscreenChanged,
    required this.videoPlayerManager,
    this.isPortrait,
  });

  @override
  ELearnPlayerState createState() => ELearnPlayerState();
}

class ELearnPlayerState extends State<ELearnPlayer>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isVideoPlayerReady = false;
  // final bool _isFullscreen = false;
  bool _isPlaying = false; // Track the play state
  Timer? _videoProgressTimer;
  Timer? _hideControlsTimer;
  bool _showControls = false; // Initially hide controls
  bool _isLoading = true;

  bool fullScreenRequired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVideoPlayer();
    // _loadFullscreenPreference();
    bool? isPortrait = widget.isPortrait;
    debugPrint("Portrait: $isPortrait");
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.file(File(widget.videoFilePath));
      debugPrint('Video file path: ${widget.videoFilePath}');

      await _controller.initialize();

      widget.videoPlayerManager.addController(_controller);

      final lastPosition = await _getLastPosition();
      if (lastPosition != null) {
        _controller.seekTo(lastPosition);
      }

      setState(() {
        _isVideoPlayerReady = true;
        _isLoading = false;
      });

      _videoProgressTimer =
          Timer.periodic(const Duration(milliseconds: 500), (timer) {
        setState(() {});
        _saveLastPosition(_controller.value.position);
      });

      _startHideControlsTimer();
    } catch (e) {
      // Handle the error by setting the state to show an error message
      setState(() {
        _isLoading = false;
        _isVideoPlayerReady = false;
      });
    }
  }

  Future<void> _saveLastPosition(Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'last_position_${widget.videoFilePath}', position.inSeconds);
  }

  Future<Duration?> _getLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('last_position_${widget.videoFilePath}');
    if (seconds != null) {
      return Duration(seconds: seconds);
    }
    return null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.videoPlayerManager.removeController(_controller);
    _controller.dispose();
    _videoProgressTimer?.cancel();
    _hideControlsTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_controller.value.isPlaying) _controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      _setOrientation();
      // re-bind the surface
      _controller.initialize().then((_) {
        final current = _controller.value.position;
        _controller.seekTo(current);
        if (_isPlaying) _controller.play();
        setState(() => _isVideoPlayerReady = true);
      });
    }
  }

  Future<void> _setOrientation() async {
    if (widget.isPortrait == true) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  void _onVideoTap() {
    setState(() {
      _showControls = true;
    });
    _restartHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _showControls = false;
      });
    });
  }

  void _restartHideControlsTimer() {
    setState(() {
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  void _seekForward() {
    if (_controller.value.isInitialized) {
      final position = _controller.value.position;
      final duration = _controller.value.duration;
      final newPosition = position + const Duration(seconds: 10);
      if (newPosition <= duration) {
        _controller.seekTo(newPosition);
      }
    }
    _restartHideControlsTimer();
  }

  void _seekBackward() {
    if (_controller.value.isInitialized) {
      final position = _controller.value.position;
      final newPosition = position - const Duration(seconds: 10);
      if (newPosition >= const Duration(seconds: 0)) {
        _controller.seekTo(newPosition);
      }
    }
    _restartHideControlsTimer();
  }

  Future<bool> _onWillPop() async {
    // if (_isFullscreen) {
    //   _toggleFullscreen();
    //   return false;
    // }
    return true;
  }

  void _playVideo() {
    setState(() {
      _isPlaying = true;
    });
    _controller.play();
    _showControlsForTwoSeconds();
  }

  void _showControlsForTwoSeconds() {
    setState(() {
      _showControls = true;
    });

    Timer(const Duration(seconds: 2), () {
      setState(() {
        _showControls = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Container(
        color: Colors.transparent, // Set the background color to black
        child: Center(
            child: _isLoading
                ? const CircularProgressIndicator()
                : _isVideoPlayerReady
                    ? GestureDetector(
                        onTap: _onVideoTap,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                color: primaryColor,
                                child: VideoPlayer(_controller),
                              ),
                            ),
                            if (!_isPlaying)
                              Center(
                                child: IconButton(
                                  icon: Image.asset(
                                    'assets/images/play_button.png',
                                    height: 100,
                                    width: 100,
                                  ),
                                  onPressed: _playVideo,
                                ),
                              ),
                            if (_showControls) _buildVideoControls(),
                          ],
                        ),
                      )
                    : _buildErrorMessage()),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      color: Colors.white, // Background color for the error message
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 16),
            Text(
              "We're sorry, but the video cannot be played at the moment. This might be due to an unsupported format or an issue with the file. Please try a different video or contact support.",
              style: TextStyle(color: Colors.black, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;

    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  value: position.inSeconds.toDouble(),
                  max: duration.inSeconds.toDouble(),
                  min: 0,
                  activeColor: Colors.red,
                  inactiveColor: Colors.white54,
                  onChanged: (value) {
                    setState(() {
                      _controller.seekTo(Duration(seconds: value.toInt()));
                    });
                    _restartHideControlsTimer();
                  },
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: _seekBackward,
              ),
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                      _isPlaying = false;
                    } else {
                      _controller.play();
                      _isPlaying = true;
                    }
                  });
                  _restartHideControlsTimer();
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: _seekForward,
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white),
                onPressed: _openFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openFullscreen() async {
    final wasPlaying = _controller.value.isPlaying;

    // pause parent so background audio stops
    if (wasPlaying) _controller.pause();

    // push full-screen, including the play state
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenPlayer(
          videoFilePath: widget.videoFilePath,
          videoPlayerManager: widget.videoPlayerManager,
          isPortrait: widget.isPortrait,
          wasPlaying: wasPlaying, // ← pass it
        ),
      ),
    );

    // apply returned state
    if (result != null) {
      final pos = result['position'] as Duration;
      final playing = result['isPlaying'] as bool;

      await _controller.seekTo(pos);
      if (playing) {
        _controller.play();
      } else {
        _controller.pause();
      }
      setState(() {
        _isPlaying = playing;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
