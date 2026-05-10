// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player/src/video_player/video_player.dart';
import 'package:awesome_video_player/src/video_player/video_player_platform_interface.dart'
    show DurationRange;
import 'package:flutter/material.dart';

class AwsomePlayerControls extends StatefulWidget {
  /// Callback for visibility changes
  final Function(bool visibility) onControlsVisibilityChanged;
  final Function(Object)? onRetry;
  final bool enableBackButton;

  /// Player controller
  final BetterPlayerController betterPlayerController;

  const AwsomePlayerControls({
    Key? key,
    required this.onControlsVisibilityChanged,
    required this.onRetry,
    required this.betterPlayerController,
    this.enableBackButton = false,
  }) : super(key: key);

  @override
  State<AwsomePlayerControls> createState() => _CustomPlayerControlsState();
}

class _CustomPlayerControlsState extends State<AwsomePlayerControls>
    with WidgetsBindingObserver {
  VideoPlayerValue? _latestValue;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  Timer? _initTimer;
  bool is2xSkipping = false;
  double previousSpeed = 1;
  bool wasInactive = false;
  bool _isBehindLiveEdge = false;
  bool _liveStreamEnded = false;
  StreamSubscription? _behindLiveEdgeSubscription;

  // Get the controls configuration
  BetterPlayerControlsConfiguration get _controlsConfiguration => widget
      .betterPlayerController.betterPlayerConfiguration.controlsConfiguration;

  // Get the current video controller
  VideoPlayerController? get _videoPlayerController =>
      widget.betterPlayerController.videoPlayerController;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (wasInactive) {
        widget.betterPlayerController.play();
        wasInactive = false;
      }
    } else if (state == AppLifecycleState.inactive) {
      wasInactive = _videoPlayerController?.value.isPlaying == true;
      widget.betterPlayerController.pause();
    }
  }

  void _initialize() {
    _videoPlayerController?.addListener(_updateState);
    _updateState();

    if (_videoPlayerController?.value.isPlaying == true ||
        widget.betterPlayerController.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    _behindLiveEdgeSubscription = widget
        .betterPlayerController.isBehindLiveEdgeController
        .listen((isBehindLiveEdge) {
      if (mounted && _isBehindLiveEdge != isBehindLiveEdge) {
        setState(() {
          _isBehindLiveEdge = isBehindLiveEdge;
        });
      }
    });

    widget.betterPlayerController.addEventsListener(_onPlayerEvent);

    _initTimer = Timer(const Duration(milliseconds: 200), () {
      setState(() {
        _controlsVisible = true;
      });
      widget.onControlsVisibilityChanged(_controlsVisible);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoPlayerController?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _behindLiveEdgeSubscription?.cancel();
    widget.betterPlayerController.removeEventsListener(_onPlayerEvent);
    super.dispose();
  }

  @override
  void didUpdateWidget(AwsomePlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.betterPlayerController != widget.betterPlayerController) {
      _videoPlayerController?.removeListener(_updateState);
      _videoPlayerController?.addListener(_updateState);
      _updateState();
    }
  }

  void _updateState() {
    if (!mounted) return;
    final newValue = _videoPlayerController?.value;
    final old = _latestValue;

    // Only rebuild when something meaningful changes
    final bool structuralChange = newValue?.isPlaying != old?.isPlaying ||
        newValue?.isBuffering != old?.isBuffering ||
        newValue?.hasError != old?.hasError ||
        newValue?.initialized != old?.initialized ||
        newValue?.duration != old?.duration;

    // Throttle position updates: only rebuild if controls are visible and
    // position changed by at least 1 second (to drive the time label).
    final bool positionChange = _controlsVisible &&
        (newValue?.position.inSeconds ?? 0) != (old?.position.inSeconds ?? 0);

    if (structuralChange || positionChange) {
      setState(() {
        _latestValue = newValue;
      });
    } else {
      // Keep _latestValue in sync without triggering a rebuild
      _latestValue = newValue;
    }
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.liveStreamEnded) {
      if (mounted && !_liveStreamEnded) {
        setState(() => _liveStreamEnded = true);
      }
    }
  }

  void _watchAsStreamedLive() async {
    setState(() {
      _liveStreamEnded = false;
    });
    final dataSource = widget.betterPlayerController.betterPlayerDataSource;
    if (dataSource != null) {
      widget.betterPlayerController.setupDataSource(dataSource);
      await widget.betterPlayerController.seekTo(Duration.zero);
      widget.betterPlayerController.play();
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      widget.onControlsVisibilityChanged(_controlsVisible);
    });

    if (_controlsVisible) {
      _startHideTimer();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
          widget.onControlsVisibilityChanged(false);
        });
      }
    });
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    if (mounted) {
      setState(() {
        _controlsVisible = true;
        widget.onControlsVisibilityChanged(true);
      });
      _startHideTimer();
    }
  }

  void _onPlayPause() async {
    final controller = _videoPlayerController;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      if (Platform.isIOS) {
        // For iOS: if there is any seek operation in flight give it time to land
        await Future.delayed(const Duration(milliseconds: 500));
        await widget.betterPlayerController.pause();
      } else {
        await widget.betterPlayerController.pause();
      }
      _cancelAndRestartTimer();
    } else {
      if (controller.value.initialized) {
        if (_isVideoFinished()) {
          await widget.betterPlayerController.seekTo(Duration.zero);
        }
        await widget.betterPlayerController.play();
        _startHideTimer();
      }
    }
  }

  bool _isVideoFinished() {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.initialized) return false;

    final Duration? position = controller.value.position;
    final Duration? duration = controller.value.duration;

    if (position == null || duration == null) return false;
    return position >= duration;
  }

  void _onForward({int multiplier = 1}) {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.initialized) return;

    _cancelAndRestartTimer();
    final position = controller.value.position;
    final seekTo = position + Duration(seconds: 10 * multiplier);
    widget.betterPlayerController.seekTo(seekTo);
  }

  void _onRewind({int multiplier = 1}) {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.initialized) return;

    _cancelAndRestartTimer();
    final position = controller.value.position;
    final seekTo = position - Duration(seconds: 10 * multiplier);
    widget.betterPlayerController
        .seekTo(seekTo.isNegative ? Duration.zero : seekTo);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  /// Min. time of buffered video to hide loading indicator (in milliseconds)
  static const int _bufferingInterval = 20000;

  bool loadingStatus(VideoPlayerValue? latestValue) {
    if (latestValue != null) {
      if (!latestValue.isPlaying && latestValue.duration == null) {
        return true;
      }

      final Duration position = latestValue.position;
      Duration? bufferedEndPosition;
      if (latestValue.buffered.isNotEmpty == true) {
        bufferedEndPosition = latestValue.buffered.last.end;
      }

      if (bufferedEndPosition != null) {
        final difference = bufferedEndPosition - position;
        if (latestValue.isPlaying &&
            latestValue.isBuffering &&
            difference.inMilliseconds < _bufferingInterval) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoPlayerController;
    final isPlaying = controller?.value.isPlaying == true;
    final isInitialized = controller?.value.initialized == true;
    final bool isLoading = loadingStatus(controller?.value) && !isPlaying;
    final isFinished = _isVideoFinished();
    final size = MediaQuery.of(context).size;
    final bool hasError = _latestValue?.hasError == true;
    final String errorMessage = _latestValue?.errorDescription ?? 'Error';
    final bool isFullscreen = widget.betterPlayerController.isFullScreen;

    if (hasError) {
      return CustomBetterPlayerErrorWidget(
        onRetry: widget.onRetry,
        controller: widget.betterPlayerController,
        errorMessage: errorMessage,
      );
    }

    return SafeArea(
      top: false,
      bottom: false,
      child: GestureDetector(
        onLongPress: () {
          setState(() {
            is2xSkipping = true;
            _controlsVisible = false;
            previousSpeed = widget.betterPlayerController.videoPlayerController
                    ?.value.speed ??
                1;
          });
          widget.betterPlayerController.setSpeed(2.0);
        },
        onLongPressEnd: (s) {
          setState(() {
            is2xSkipping = false;
          });
          widget.betterPlayerController.setSpeed(previousSpeed);
        },
        onTap: _toggleControlsVisibility,
        child: AbsorbPointer(
          absorbing: !_controlsVisible,
          child: Stack(
            children: [
              // Controls layer
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _controlsVisible ? 1.0 : 0.0,
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Visibility(
                              visible: widget.enableBackButton,
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: _BackButton(),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                if (widget
                                    .betterPlayerController.isFullScreen) {
                                  widget.betterPlayerController.pause();
                                }
                                final res = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  constraints:
                                      BoxConstraints(maxWidth: size.width),
                                  useSafeArea: true,
                                  builder: (context) =>
                                      VideoSettingsBottomSheet(
                                    betterPlayerController:
                                        widget.betterPlayerController,
                                  ),
                                );
                                if (res == true) {
                                  if (widget
                                      .betterPlayerController.isFullScreen) {
                                    widget.betterPlayerController.play();
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                widget.betterPlayerController.isFullScreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen,
                                color: Colors.white,
                              ),
                              onPressed: () => widget.betterPlayerController
                                  .toggleFullScreen(),
                            ),
                          ],
                        ),
                      ),

                      // Middle section with play/pause and seek buttons
                      Expanded(
                        child: SizedBox(
                          width: isFullscreen ? size.width * .9 : null,
                          child: Row(
                            mainAxisAlignment: isFullscreen
                                ? MainAxisAlignment.spaceBetween
                                : MainAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 2,
                                child: AnimatedSkipButton(
                                  showControls: (status) =>
                                      _cancelAndRestartTimer(),
                                  isBackward: true,
                                  iconData:
                                      Icons.keyboard_double_arrow_left_rounded,
                                  iconColor: _controlsConfiguration.iconsColor,
                                  skipDurationInSeconds: 10,
                                  onSkip: (count) {
                                    _onRewind(multiplier: count);
                                  },
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  width: 70,
                                  height: 70,
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 15,
                                          height: 15,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : isFinished &&
                                              !widget.betterPlayerController
                                                  .isLiveStream()
                                          ? GestureDetector(
                                              onTap: () async {
                                                await widget
                                                    .betterPlayerController
                                                    .seekTo(const Duration());
                                                widget.betterPlayerController
                                                    .play();
                                              },
                                              child: const Icon(
                                                Icons.replay,
                                                size: 50,
                                                color: Colors.white,
                                              ),
                                            )
                                          : AnimatedPlayPauseIcon(
                                              color: Colors.white,
                                              size: 50,
                                              isPlaying: isPlaying,
                                              onPressed: _onPlayPause,
                                            ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: AnimatedSkipButton(
                                  showControls: (status) =>
                                      _cancelAndRestartTimer(),
                                  isBackward: false,
                                  iconData:
                                      Icons.keyboard_double_arrow_right_rounded,
                                  iconColor: _controlsConfiguration.iconsColor,
                                  skipDurationInSeconds: 10,
                                  onSkip: (count) {
                                    _onForward(multiplier: count);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom bar with progress
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Row(
                                    children: [
                                      if (widget.betterPlayerController
                                              .isLiveStream() &&
                                          !_liveStreamEnded)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 12.0, right: 16),
                                          child: InkWell(
                                            onTap: _isBehindLiveEdge
                                                ? () async {
                                                    await widget
                                                        .betterPlayerController
                                                        .seekToLive();
                                                  }
                                                : null,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.fiber_manual_record,
                                                    color: _isBehindLiveEdge
                                                        ? Colors.white70
                                                        : Colors.redAccent,
                                                    size: 10,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'LIVE',
                                                    style: TextStyle(
                                                      color: _isBehindLiveEdge
                                                          ? Colors.white70
                                                          : Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            // Current time
                                            if (!widget.betterPlayerController
                                                .isLiveStream())
                                              Flexible(
                                                child: Text(
                                                  isInitialized
                                                      ? _formatDuration(
                                                          controller!
                                                              .value.position)
                                                      : '00:00',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white),
                                                ),
                                              ),
                                            // Duration
                                            if (!widget.betterPlayerController
                                                .isLiveStream())
                                              Flexible(
                                                child: Text(
                                                  ' / ${isInitialized ? _formatDuration(controller!.value.duration ?? Duration.zero) : '00:00'}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white70),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Progress bar
                              Flexible(
                                child: Container(
                                  height: 25,
                                  margin: EdgeInsets.only(
                                      bottom: widget.betterPlayerController
                                              .isFullScreen
                                          ? 30
                                          : 0),
                                  alignment: Alignment.bottomCenter,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: HotStarProgressBar(
                                    widget.betterPlayerController
                                        .videoPlayerController,
                                    widget.betterPlayerController,
                                    onDragStart: () {
                                      _hideTimer?.cancel();
                                    },
                                    onDragEnd: () {
                                      _startHideTimer();
                                    },
                                    onTapDown: () {
                                      _cancelAndRestartTimer();
                                    },
                                    colors: BetterPlayerProgressColors(
                                        playedColor: Colors.red,
                                        handleColor: _controlsConfiguration
                                            .progressBarHandleColor,
                                        bufferedColor: Colors.white,
                                        backgroundColor: Colors.grey),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2x speed indicator
              Positioned(
                left: 5,
                top: 5,
                child: Visibility(
                  visible: is2xSkipping,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.5),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "2x",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        Icon(
                          Icons.fast_forward_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Live ended overlay
              if (_liveStreamEnded)
                Positioned.fill(
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
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white24, width: 1.5),
                              color: Colors.white10,
                            ),
                            child: const Icon(
                              Icons.videocam_off_rounded,
                              color: Colors.white70,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 16),
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
                          const Text(
                            'The live stream has concluded',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 28),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simple back button (replaces the Eduport-specific ArrowBackButtonDark)
// ---------------------------------------------------------------------------
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress bar
// ---------------------------------------------------------------------------

class HotStarProgressBar extends StatefulWidget {
  HotStarProgressBar(
    this.controller,
    this.betterPlayerController, {
    BetterPlayerProgressColors? colors,
    this.onDragEnd,
    this.onDragStart,
    this.onDragUpdate,
    this.onTapDown,
    Key? key,
  })  : colors = colors ?? BetterPlayerProgressColors(),
        super(key: key);

  final VideoPlayerController? controller;
  final BetterPlayerController? betterPlayerController;
  final BetterPlayerProgressColors colors;
  final Function()? onDragStart;
  final Function()? onDragEnd;
  final Function()? onDragUpdate;
  final Function()? onTapDown;

  @override
  _VideoProgressBarState createState() {
    return _VideoProgressBarState();
  }
}

class _VideoProgressBarState extends State<HotStarProgressBar> {
  _VideoProgressBarState() {
    listener = () {
      if (mounted && shouldUpdateState()) {
        setState(() {});
      }
    };
  }

  late VoidCallback listener;
  bool _controllerWasPlaying = false;

  VideoPlayerController? get controller => widget.controller;
  BetterPlayerController? get betterPlayerController =>
      widget.betterPlayerController;

  bool shouldPlayAfterDragEnd = false;
  Duration? lastSeek;
  Timer? _updateBlockTimer;
  Timer? _seekDebounceTimer;

  // For selective state updates
  Duration _lastPosition = Duration.zero;
  bool _lastBufferingState = false;
  List<DurationRange> _lastBufferedRanges = [];

  bool shouldUpdateState() {
    if (!controller!.value.initialized) return false;

    final newPosition = controller!.value.position;
    final positionDifference =
        (newPosition - _lastPosition).abs().inMilliseconds;

    bool positionChanged = positionDifference > 250;
    bool bufferingChanged =
        _lastBufferingState != controller!.value.isBuffering;
    bool bufferedRangesChanged =
        _bufferedRangesChanged(controller!.value.buffered);

    if (positionChanged || bufferingChanged || bufferedRangesChanged) {
      _lastPosition = newPosition;
      _lastBufferingState = controller!.value.isBuffering;
      _lastBufferedRanges = List.from(controller!.value.buffered);
      return true;
    }

    return false;
  }

  bool _bufferedRangesChanged(List<DurationRange> newRanges) {
    if (_lastBufferedRanges.length != newRanges.length) return true;

    for (int i = 0; i < newRanges.length; i++) {
      final oldRange = _lastBufferedRanges[i];
      final newRange = newRanges[i];
      if ((oldRange.start - newRange.start).abs().inSeconds > 1 ||
          (oldRange.end - newRange.end).abs().inSeconds > 1) {
        return true;
      }
    }

    return false;
  }

  final Debouncer debouncer = Debouncer(delay: 200);
  @override
  void initState() {
    super.initState();
    if (controller != null && controller!.value.initialized) {
      _lastPosition = controller!.value.position;
      _lastBufferingState = controller!.value.isBuffering;
      _lastBufferedRanges = List.from(controller!.value.buffered);
    }
    controller!.addListener(listener);
  }

  @override
  void deactivate() {
    controller!.removeListener(listener);
    _cancelUpdateBlockTimer();
    _cancelSeekDebounceTimer();
    super.deactivate();
  }

  @override
  void dispose() {
    _cancelUpdateBlockTimer();
    _cancelSeekDebounceTimer();
    super.dispose();
  }

  void _cancelSeekDebounceTimer() {
    _seekDebounceTimer?.cancel();
    _seekDebounceTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final bool enableProgressBarDrag = betterPlayerController!
        .betterPlayerConfiguration.controlsConfiguration.enableProgressBarDrag;

    return RepaintBoundary(
      child: GestureDetector(
        onHorizontalDragStart: (DragStartDetails details) {
          if (!controller!.value.initialized || !enableProgressBarDrag) {
            return;
          }

          _controllerWasPlaying = controller!.value.isPlaying;
          _cancelSeekDebounceTimer();

          if (widget.onDragStart != null) {
            widget.onDragStart!();
          }
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) async {
          if (!controller!.value.initialized || !enableProgressBarDrag) {
            return;
          }

          await seekToRelativePosition(details.globalPosition);

          if (widget.onDragUpdate != null) {
            widget.onDragUpdate!();
          }
        },
        onHorizontalDragEnd: (DragEndDetails details) async {
          if (!enableProgressBarDrag) {
            return;
          }

          if (lastSeek != null) {
            log("Seeking2");
            debouncer.run(() async {
              await betterPlayerController!.seekTo(lastSeek!);
            });
          }

          if (_controllerWasPlaying) {
            shouldPlayAfterDragEnd = true;
          }
          _setupUpdateBlockTimer();

          if (widget.onDragEnd != null) {
            widget.onDragEnd!();
          }
        },
        onTapDown: (TapDownDetails details) async {
          if (!controller!.value.initialized || !enableProgressBarDrag) {
            return;
          }

          final position = calculatePosition(details.globalPosition);
          if (position != null) {
            lastSeek = position;
            log("Seeking3");
            debouncer.run(() async {
              await betterPlayerController!.seekTo(position);
            });
          }

          _setupUpdateBlockTimer();

          if (widget.onTapDown != null) {
            widget.onTapDown!();
          }
        },
        child: Center(
          child: SizedBox(
            height: MediaQuery.of(context).size.height / 2,
            width: MediaQuery.of(context).size.width,
            child: CustomPaint(
              painter: _ProgressBarPainter(
                _getValue(),
                widget.colors,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setupUpdateBlockTimer() {
    _cancelUpdateBlockTimer();
    _updateBlockTimer = Timer(const Duration(milliseconds: 1000), () {
      lastSeek = null;
    });
  }

  void _cancelUpdateBlockTimer() {
    _updateBlockTimer?.cancel();
    _updateBlockTimer = null;
  }

  VideoPlayerValue _getValue() {
    if (lastSeek != null) {
      return controller!.value.copyWith(position: lastSeek);
    } else {
      return controller!.value;
    }
  }

  Duration? calculatePosition(Offset globalPosition) {
    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject != null && controller!.value.duration != null) {
      final box = renderObject as RenderBox;
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      if (relative > 0) {
        final Duration position = controller!.value.duration! * relative;
        if (relative >= 1) {
          return controller!.value.duration;
        }
        return position;
      }
    }
    return null;
  }

  Future<void> seekToRelativePosition(Offset globalPosition) async {
    final position = calculatePosition(globalPosition);
    if (position == null) return;

    setState(() {
      lastSeek = position;
    });

    _cancelSeekDebounceTimer();
    debouncer.run(()async {
      if (mounted) {
        log("Seeking");
        await betterPlayerController!.seekTo(position);
      }
    });

  }

  void onFinishedLastSeek() {
    if (shouldPlayAfterDragEnd) {
      shouldPlayAfterDragEnd = false;
      betterPlayerController?.play();
    }
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter(this.value, this.colors);

  final VideoPlayerValue value;
  final BetterPlayerProgressColors colors;

  @override
  bool shouldRepaint(_ProgressBarPainter oldPainter) {
    if (!value.initialized) return oldPainter.value.initialized;
    if (!oldPainter.value.initialized) return true;

    final positionDiff = (value.position.inMilliseconds -
            oldPainter.value.position.inMilliseconds)
        .abs();
    if (positionDiff > 100) return true;

    if (value.buffered.length != oldPainter.value.buffered.length) return true;

    for (int i = 0; i < value.buffered.length; i++) {
      if (i >= oldPainter.value.buffered.length) return true;
      final newRange = value.buffered[i];
      final oldRange = oldPainter.value.buffered[i];
      if ((newRange.end.inMilliseconds - oldRange.end.inMilliseconds).abs() >
          500) {
        return true;
      }
    }

    return false;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const height = 1.8;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, size.height / 2),
          Offset(size.width, size.height / 2 + height),
        ),
        const Radius.circular(8.0),
      ),
      colors.backgroundPaint,
    );

    if (!value.initialized) {
      return;
    }

    double playedPartPercent =
        value.position.inMilliseconds / value.duration!.inMilliseconds;
    if (playedPartPercent.isNaN) {
      playedPartPercent = 0;
    }

    final double playedPart =
        playedPartPercent > 1 ? size.width : playedPartPercent * size.width;

    // Draw buffered ranges
    for (final range in value.buffered) {
      double start = range.startFraction(value.duration!) * size.width;
      if (start.isNaN) start = 0;
      double end = range.endFraction(value.duration!) * size.width;
      if (end.isNaN) end = 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(
            Offset(start, size.height / 2),
            Offset(end, size.height / 2 + height),
          ),
          const Radius.circular(4.0),
        ),
        colors.bufferedPaint,
      );
    }

    // Draw played part
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(
          Offset(0.0, size.height / 2),
          Offset(playedPart, size.height / 2 + height),
        ),
        const Radius.circular(4.0),
      ),
      colors.playedPaint,
    );

    // Draw handle
    canvas.drawCircle(
      Offset(playedPart, size.height / 2 + height / 2),
      height * 5,
      colors.handlePaint,
    );
  }
}

// ---------------------------------------------------------------------------
// Animated skip button
// ---------------------------------------------------------------------------

class AnimatedSkipButton extends StatefulWidget {
  final IconData iconData;
  final Color iconColor;
  final double iconSize;
  final int skipDurationInSeconds;
  final Function(int tapCount) onSkip;
  final Function(bool controlsActive) showControls;
  final bool isBackward;

  const AnimatedSkipButton({
    Key? key,
    required this.iconData,
    required this.iconColor,
    this.iconSize = 44.0,
    required this.skipDurationInSeconds,
    required this.onSkip,
    this.isBackward = true,
    required this.showControls,
  }) : super(key: key);

  @override
  _AnimatedSkipButtonState createState() => _AnimatedSkipButtonState();
}

class _AnimatedSkipButtonState extends State<AnimatedSkipButton> {
  bool _isSkipTapped = false;
  int _tapCount = 0;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Widget _buildDurationIndicator() {
    return AnimatedSwitcher(
      switchInCurve: Curves.decelerate,
      switchOutCurve: Curves.bounceOut,
      duration: const Duration(milliseconds: 600),
      child: _isSkipTapped
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                "${widget.skipDurationInSeconds * (_tapCount > 0 ? _tapCount : 1)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          : const SizedBox(),
    );
  }

  void _handleTap() {
    setState(() {
      _isSkipTapped = true;
      _tapCount++;
      widget.showControls(false);
    });

    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        widget.onSkip(_tapCount);
        setState(() {
          _tapCount = 0;
          _isSkipTapped = false;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _tapCount == 0) {
        setState(() {
          _isSkipTapped = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(widget.iconSize),
      onTap: _handleTap,
      child: SizedBox(
        width: 90,
        height: 120,
        child: Row(
          mainAxisAlignment: widget.isBackward
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Visibility(
              visible: !widget.isBackward,
              child: _buildDurationIndicator(),
            ),
            // The main skip icon
            Flexible(
              child: Icon(
                widget.iconData,
                size: widget.iconSize,
                color: widget.iconColor,
              ),
            ),
            Visibility(
              visible: widget.isBackward,
              child: _buildDurationIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings bottom sheet
// ---------------------------------------------------------------------------

class VideoSettingsBottomSheet extends StatefulWidget {
  final BetterPlayerController betterPlayerController;

  const VideoSettingsBottomSheet({
    Key? key,
    required this.betterPlayerController,
  }) : super(key: key);

  @override
  _VideoSettingsBottomSheetState createState() =>
      _VideoSettingsBottomSheetState();
}

class _VideoSettingsBottomSheetState extends State<VideoSettingsBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<double> _speedOptions = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTrackRow(BetterPlayerAsmsTrack track, String? preferredName) {
    final int width = track.width ?? 0;
    final int height = track.height ?? 0;

    final resolution = width > height ? height : width;
    final resolutionName = resolution == 0 ? "Auto" : '${resolution}p';
    final String trackName = preferredName ?? resolutionName;

    final BetterPlayerAsmsTrack? selectedTrack =
        widget.betterPlayerController.betterPlayerAsmsTrack;
    final bool isSelected = selectedTrack != null && selectedTrack == track;
    return SizedBox(
      height: 45,
      child: ListTile(
        minLeadingWidth: 22,
        title: Text(
          trackName,
          style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14),
        ),
        leading: isSelected
            ? const Icon(
                Icons.check,
                size: 22,
                color: Color(0xffFF6600),
              )
            : const SizedBox(
                width: 22,
                height: 22,
              ),
        onTap: () {
          widget.betterPlayerController.setTrack(track);
          Navigator.pop(context, true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFullScreen = widget.betterPlayerController.isFullScreen;
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding + 6),
      height: isFullScreen ? size.height : 430,
      width: isFullScreen ? size.width : null,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F38).withOpacity(isFullScreen ? 0.8 : 1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          // Drag handle (non-fullscreen only)
          Visibility(
            visible: !isFullScreen,
            child: Container(
              padding: const EdgeInsets.only(top: 8),
              margin: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),

          // Tab bar
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: SizedBox(
                    width: isFullScreen ? 200 : null,
                    child: TabBar(
                      indicatorWeight: .5,
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white,
                      dividerHeight: 0,
                      tabs: const [
                        Tab(text: "Quality"),
                        Tab(text: "Speed"),
                      ],
                    ),
                  ),
                ),
                Visibility(
                  visible: isFullScreen,
                  child: IconButton(
                    onPressed: () {
                      if (isFullScreen) {
                        widget.betterPlayerController.play();
                      }
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: StretchingScrollWidget(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(child: _buildQualityTab()),
                  _buildSpeedTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityTab() {
    final List<String> asmsTrackNames =
        widget.betterPlayerController.betterPlayerDataSource?.asmsTrackNames ??
            [];
    final List<BetterPlayerAsmsTrack> asmsTracks =
        widget.betterPlayerController.betterPlayerAsmsTracks;
    final List<Widget> children = [];
    for (var index = 0; index < asmsTracks.length; index++) {
      final track = asmsTracks[index];
      String? preferredName;
      if (track.height == 0 && track.width == 0 && track.bitrate == 0) {
        preferredName = widget.betterPlayerController.translations.qualityAuto;
      } else {
        preferredName =
            asmsTrackNames.length > index ? asmsTrackNames[index] : null;
      }
      children.add(_buildTrackRow(asmsTracks[index], preferredName));
    }
    return Column(
      children: List.generate(children.length, (index) => children[index]),
    );
  }

  Widget _buildSpeedTab() {
    return ListView.builder(
      itemCount: _speedOptions.length,
      padding: const EdgeInsets.only(bottom: 16),
      itemBuilder: (context, index) {
        final speed = _speedOptions[index];
        final bool isSelected =
            widget.betterPlayerController.videoPlayerController!.value.speed ==
                speed;
        final displayText = speed == 1.0 ? "Normal" : "${speed}x";

        return SizedBox(
          height: 45,
          child: ListTile(
            minLeadingWidth: 22,
            title: Text(
              displayText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            leading: isSelected
                ? const Icon(
                    Icons.check,
                    size: 22,
                    color: Color(0xffFF6600),
                  )
                : const SizedBox(
                    width: 22,
                    height: 22,
                  ),
            onTap: () {
              widget.betterPlayerController.setSpeed(speed);
              Navigator.pop(context, true);
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Animated play/pause icon
// ---------------------------------------------------------------------------

class AnimatedPlayPauseIcon extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final VoidCallback? onPressed;
  final Color? color;
  final Duration duration;

  const AnimatedPlayPauseIcon({
    super.key,
    required this.isPlaying,
    this.size = 48.0,
    this.onPressed,
    this.color,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedPlayPauseIcon> createState() => _AnimatedPlayPauseIconState();
}

class _AnimatedPlayPauseIconState extends State<AnimatedPlayPauseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> animation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    animation = Tween<double>(begin: 0.0, end: 1.0).animate(controller);
    _updateControllerValue(true);
  }

  @override
  void didUpdateWidget(AnimatedPlayPauseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _updateControllerValue(false);
    }
    if (widget.duration != oldWidget.duration) {
      controller.duration = widget.duration;
    }
  }

  void _updateControllerValue(bool isInit) {
    if (widget.isPlaying) {
      if (isInit) {
        controller.forward(from: 1);
      } else {
        controller.forward();
      }
    } else {
      controller.reverse();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: widget.size,
      onPressed: widget.onPressed,
      icon: AnimatedIcon(
        icon: AnimatedIcons.play_pause,
        progress: animation,
        size: widget.size,
        color: widget.color,
        semanticLabel: widget.isPlaying ? 'Pause' : 'Play',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error widget
// ---------------------------------------------------------------------------

class CustomBetterPlayerErrorWidget extends StatelessWidget {
  final BetterPlayerController? controller;
  final String errorMessage;
  final Function(Object error)? onRetry;
  final Color backgroundColor;
  final Color textColor;
  final Color buttonColor;

  const CustomBetterPlayerErrorWidget({
    Key? key,
    this.controller,
    this.errorMessage = "Video playback error occurred",
    this.onRetry,
    this.backgroundColor = Colors.black87,
    this.textColor = Colors.white,
    this.buttonColor = Colors.red,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: textColor,
              size: 42,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                errorMessage,
                style: TextStyle(color: textColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildRetryButton(context),
                _buildCloseButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryButton(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(.3),
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      onPressed: () {
        if (onRetry != null) {
          onRetry!(errorMessage);
        }
        if (controller != null) {
          controller!.retryDataSource();
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('Retry'),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    if (controller?.isFullScreen != true) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        onPressed: () {
          if (controller?.isFullScreen == true) {
            controller?.exitFullScreen();
          }
        },
        icon: const Icon(Icons.close_fullscreen),
        label: const Text('Close'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stretching scroll wrapper
// ---------------------------------------------------------------------------

class StretchingScrollWidget extends StatelessWidget {
  const StretchingScrollWidget({
    super.key,
    required this.child,
    this.axisDirection = AxisDirection.down,
  });
  final AxisDirection axisDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StretchingOverscrollIndicator(
      axisDirection: axisDirection,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(
            physics: const ClampingScrollPhysics(), overscroll: false),
        child: child,
      ),
    );
  }
}

class Debouncer {
  Timer? _timer;
  final int delay;
  Debouncer({
    required this.delay,
  });

  run(Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: delay), action);
  }
}
