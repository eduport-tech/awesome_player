import 'dart:developer';

import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player_example/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NormalPlayerPage extends StatefulWidget {
  @override
  _NormalPlayerPageState createState() => _NormalPlayerPageState();
}

class _NormalPlayerPageState extends State<NormalPlayerPage>
    with SingleTickerProviderStateMixin {
  late BetterPlayerController _betterPlayerController;
  late BetterPlayerDataSource _betterPlayerDataSource;
  bool _isBehindLiveEdge = false;
  bool _liveStreamEnded = false;
  final TextEditingController _urlController = TextEditingController();

  // Animation controller for the pulsing live-ended overlay
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _urlController.text = Constants.live3;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      allowedScreenSleep: false,
      controlsConfiguration: BetterPlayerControlsConfiguration(
        playerTheme: BetterPlayerTheme.cupertino,
      ),
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
      deviceOrientationsAfterFullScreen: [
        DeviceOrientation.portraitDown,
        DeviceOrientation.portraitUp
      ],
    );

    _betterPlayerDataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        Constants.live3,
        videoFormat: BetterPlayerVideoFormat.hls,
        bufferingConfiguration: BetterPlayerBufferingConfiguration());

    _betterPlayerController = BetterPlayerController(
      betterPlayerConfiguration,
    );

    // Listen for behind-live-edge changes (DVR)
    _betterPlayerController.isBehindLiveEdgeController
        .listen((isBehindLiveEdge) {
      if (mounted && _isBehindLiveEdge != isBehindLiveEdge) {
        setState(() {
          _isBehindLiveEdge = isBehindLiveEdge;
        });
      }
    });

    // Listen for live stream ended event
    _betterPlayerController.addEventsListener(_onPlayerEvent);

    _betterPlayerController.setupDataSource(_betterPlayerDataSource);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.liveStreamEnded) {
      if (mounted && !_liveStreamEnded) {
        setState(() => _liveStreamEnded = true);
        _fadeController.forward();
      }
    } 
    else if(event.betterPlayerEventType == BetterPlayerEventType.exception){
     log("errro ${event.parameters}");
    }
  }

  void _watchAsStreamedLive() {
    setState(() {
      _liveStreamEnded = false;
    });
    _fadeController.reset();

    // Reload the same source — it will now be treated as VOD (ENDLIST present)
    _betterPlayerController.setupDataSource(_betterPlayerDataSource);
    _betterPlayerController.play();
  }

  void _playCustomUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() => _liveStreamEnded = false);
    _fadeController.reset();
    _betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      videoFormat: BetterPlayerVideoFormat.hls,
      bufferingConfiguration: BetterPlayerBufferingConfiguration(),
    );
    _betterPlayerController.setupDataSource(_betterPlayerDataSource);
    _betterPlayerController.play();
  }

  @override
  void dispose() {
    _betterPlayerController.removeEventsListener(_onPlayerEvent);
    _fadeController.dispose();
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
        actions: [
          if (_isBehindLiveEdge && !_liveStreamEnded)
            TextButton.icon(
              icon: const Icon(Icons.fiber_manual_record,
                  color: Colors.red, size: 14),
              label: const Text('Go to Live',
                  style: TextStyle(color: Colors.white)),
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
            child: Stack(
              children: [
                BetterPlayer(controller: _betterPlayerController),

                // Live Ended overlay
                if (_liveStreamEnded)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.85),
                            Colors.black.withOpacity(0.95),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white24, width: 1.5),
                                color: Colors.white10,
                              ),
                              child: const Icon(
                                Icons.videocam_off_rounded,
                                color: Colors.white70,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Title
                            const Text(
                              'Live Has Ended',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subtitle
                            const Text(
                              'The live stream has concluded',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Watch as streamed live button
                            ElevatedButton.icon(
                              onPressed: _watchAsStreamedLive,
                              icon: const Icon(Icons.replay_rounded, size: 18),
                              label: const Text(
                                'Watch as Streamed Live',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                      prefixIcon: const Icon(Icons.link, color: Colors.white38, size: 18),
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
