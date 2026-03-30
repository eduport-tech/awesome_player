import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player_example/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NormalPlayerPage extends StatefulWidget {
  @override
  _NormalPlayerPageState createState() => _NormalPlayerPageState();
}

class _NormalPlayerPageState extends State<NormalPlayerPage> {
  late BetterPlayerController _betterPlayerController;
  late BetterPlayerDataSource _betterPlayerDataSource;
  bool _isBehindLiveEdge = false;

  @override
  void initState() {
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      allowedScreenSleep: false,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        playerTheme: BetterPlayerTheme.cupertino,
      ),
      fit: BoxFit.contain,
      autoPlay: true,
      looping: true,
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitDown,
        DeviceOrientation.portraitUp
      ],
    );
    _betterPlayerDataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        // liveStream: true,
        Constants.live3,
        videoFormat: BetterPlayerVideoFormat.hls,
        bufferingConfiguration: BetterPlayerBufferingConfiguration());
    _betterPlayerController = BetterPlayerController(
      betterPlayerConfiguration,
    );

    _betterPlayerController.isBehindLiveEdgeController
        .listen((isBehindLiveEdge) {
      if (mounted && _isBehindLiveEdge != isBehindLiveEdge) {
        setState(() {
          _isBehindLiveEdge = isBehindLiveEdge;
        });
      }
    });

    _betterPlayerController.setupDataSource(_betterPlayerDataSource);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Normal player"),
        actions: [
          if (_isBehindLiveEdge)
            TextButton.icon(
              icon: Icon(Icons.fast_forward, color: Colors.black),
              label: Text("Go to Live", style: TextStyle(color: Colors.black)),
              onPressed: () async {
                await _betterPlayerController.seekToLive();
                _betterPlayerController.play();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: BetterPlayer(controller: _betterPlayerController),
          ),
        ],
      ),
    );
  }
}
