import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';
import 'package:qr_scanner_app/e_learn/video_player_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:async';

class FullScreenPlayer extends StatefulWidget {
  final String videoFilePath;
  final VideoPlayerManager videoPlayerManager;
  final bool? isPortrait;

  final bool wasPlaying;

  const FullScreenPlayer({
    super.key,
    required this.videoFilePath,
    required this.videoPlayerManager,
    this.isPortrait,
    required this.wasPlaying,
  });

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer>
    with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isVideoPlayerReady = false;
  bool _isPlaying = false;
  Timer? _videoProgressTimer;
  Timer? _hideControlsTimer;
  bool _showControls = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOrientation().then((_) => _initializeVideoPlayer());
    debugPrint("Portrait: ${widget.isPortrait}");
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

      if (widget.wasPlaying) {
        _controller.play();
        _isPlaying = true;
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
    _saveLastPosition(_controller.value.position);
    widget.videoPlayerManager.removeController(_controller);
    _controller.dispose();
    _videoProgressTimer?.cancel();
    _hideControlsTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app goes background, pause and let Android release the surface
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
    }
    // When app comes back to foreground, re-initialize the surface
    else if (state == AppLifecycleState.resumed) {
      // Re-apply orientation in case Android reset it
      _setOrientation();
      // **Re‐bind** the texture by initializing again
      _controller.initialize().then((_) {
        // Seek back to where we were
        final lastPos = _controller.value.position;
        _controller.seekTo(lastPos);
        // If it was playing before background, restart
        if (widget.wasPlaying || _isPlaying) {
          _controller.play();
          setState(() => _isPlaying = true);
        }
        // Rebuild so the VideoPlayer widget re-attaches its Texture
        setState(() => _isVideoPlayerReady = true);
      });
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
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Container(
          color: Colors.transparent,
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
                    : _buildErrorMessage(),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      color: Colors.white,
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
                  value: position.inSeconds
                      .toDouble()
                      .clamp(0.0, duration.inSeconds.toDouble()),
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
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: () {
                  final currentPos = _controller.value.position;
                  final currentPlay = _controller.value.isPlaying;
                  _saveLastPosition(currentPos);
                  Navigator.pop(context, {
                    'position': currentPos,
                    'isPlaying': currentPlay,
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
