import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:video_player/video_player.dart';

class PickedLocalVideo {
  final String path;
  const PickedLocalVideo(this.path);
}

class MediaService {
  Future<PickedLocalVideo?> pickLocalVideo() async {
    final file = await FilePicker.pickFile(type: FileType.video);
    if (file == null) return null;

    // file_picker v12 exposes a Uri instead of the old FilePicker.platform API.
    // Keep a "path" property for existing CreateRoomScreen code.
    return PickedLocalVideo(file.uri.toString());
  }

  Future<VideoPlayerController> openLocalSource(String source) async {
    final uri = Uri.tryParse(source);
    final VideoPlayerController controller;

    if (uri != null && uri.scheme == 'content') {
      controller = VideoPlayerController.contentUri(uri);
    } else if (uri != null && uri.scheme == 'file') {
      controller = VideoPlayerController.file(File.fromUri(uri));
    } else {
      controller = VideoPlayerController.file(File(source));
    }

    await controller.initialize();
    return controller;
  }

  Future<void> stopScreenShare() async {
    if (Platform.isAndroid && FlutterBackground.isBackgroundExecutionEnabled) {
      try {
        await FlutterBackground.disableBackgroundExecution();
      } catch (_) {}
    }
  }

  Future<MediaStream> startScreenShare() async {
    if (Platform.isAndroid) {
      final androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: 'SyncRoom screen sharing',
        notificationText: 'Your room is currently sharing the screen.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      );

      final initialized = await FlutterBackground.initialize(
        androidConfig: androidConfig,
      );

      if (initialized && !FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.enableBackgroundExecution();
      }
    }

    return navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': true,
    });
  }
}
