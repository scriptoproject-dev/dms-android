import 'package:video_player/video_player.dart';

class VideoPlayerManager {
  // List to keep track of all video players
  final List<VideoPlayerController> controllers = [];

  // Add a video player controller
  void addController(VideoPlayerController controller) {
    controllers.add(controller);
  }

  // Remove a video player controller
  void removeController(VideoPlayerController controller) {
    controllers.remove(controller);
  }

  // Stop all videos
  void stopAllVideos() {
    for (var controller in controllers) {
      if (controller.value.isPlaying) {
        controller.pause();
      }
    }
  }
}
