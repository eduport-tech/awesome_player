import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player_example/constants.dart';
import 'package:awesome_video_player_example/pages/custom_controls/hotstar_control.dart';
import 'package:flutter/material.dart';

class HlsTracksPage extends StatefulWidget {
  @override
  _HlsTracksPageState createState() => _HlsTracksPageState();
}

class _HlsTracksPageState extends State<HlsTracksPage> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
          autoPlay: true,
      aspectRatio: 16 / 9,
      expandToFill: true,
      controlsConfiguration:  BetterPlayerControlsConfiguration(
        enableAudioTracks: false,
        interactiveViewerConfiguration:InteractiveViewerConfiguration(
          enabledOnPortrait: true,
        ),
        playerTheme: BetterPlayerTheme.custom,
        customControlsBuilder: (BetterPlayerController playerController,
                dynamic Function(bool) onControlsVisibilityChanged) =>
            AwsomePlayerControls(
          betterPlayerController: playerController,
          onControlsVisibilityChanged: onControlsVisibilityChanged,
          onRetry: null,
        ),
      ),
      fit: BoxFit.contain,
    );
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        // 'https://cdn.radiantmediatechs.com/rmp/media/samples-for-rmp-site/04052024-lac-de-bimont/hls/playlist.m3u8',
        Constants.hlsTestStreamUrl,
        useAsmsSubtitles: true,
        videoFormat: BetterPlayerVideoFormat.hls);
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("HLS tracks"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Player with HLS stream which loads tracks from HLS."
                " You can choose tracks by using overflow menu (3 dots in right corner).",
                style: TextStyle(fontSize: 16),
              ),
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(controller: _betterPlayerController),
            ),
          ],
        ),
      ),
    );
  }
}
