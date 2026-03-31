import 'dart:developer';

import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player_example/constants.dart';
import 'package:awesome_video_player_example/pages/custom_controls/hotstar_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NormalPlayerPage extends StatefulWidget {
  @override
  _NormalPlayerPageState createState() => _NormalPlayerPageState();
}

class _NormalPlayerPageState extends State<NormalPlayerPage> {
  late BetterPlayerController _betterPlayerController;
  late BetterPlayerDataSource _betterPlayerDataSource;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = Constants.live3;
    _initPlayer(Constants.live3);
  }

  void _initPlayer(String url) {
    final betterPlayerConfiguration = BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      allowedScreenSleep: false,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitDown,
        DeviceOrientation.portraitUp,
      ],
      controlsConfiguration: BetterPlayerControlsConfiguration(
        playerTheme: BetterPlayerTheme.custom,
        customControlsBuilder:
            (BetterPlayerController playerController,
                dynamic Function(bool) onControlsVisibilityChanged) =>
                AwsomePlayerControls(
                  betterPlayerController: playerController,
                  onControlsVisibilityChanged: onControlsVisibilityChanged,
                  onRetry: (error) {
                    log('Player retry requested: $error');
                  },
                ),
      ),
    );

    _betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      videoFormat: BetterPlayerVideoFormat.hls,
      bufferingConfiguration: BetterPlayerBufferingConfiguration(),
    );

    _betterPlayerController = BetterPlayerController(
      betterPlayerConfiguration,
    );

    _betterPlayerController.setupDataSource(_betterPlayerDataSource);
  }

  void _playCustomUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Dispose the old controller and create a fresh one with the new URL.
    _betterPlayerController.dispose();
    setState(() {
      _initPlayer(url);
    });
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Live Player'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),

          // Player
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),

          // HLS URL input
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter HLS stream URL (.m3u8)',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.link,
                          color: Colors.white38, size: 18),
                      filled: true,
                      fillColor: Colors.white10,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _playCustomUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _playCustomUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
