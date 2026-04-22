import 'dart:developer';

import 'package:awesome_video_player/awesome_video_player.dart';
import 'package:awesome_video_player_example/constants.dart';
import 'package:awesome_video_player_example/pages/custom_controls/hotstar_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NormalPlayerPage extends StatefulWidget {
  @override
  _NormalPlayerPageState createState() => _NormalPlayerPageState();
}

class _NormalPlayerPageState extends State<NormalPlayerPage> {
  BetterPlayerController? _betterPlayerController;
  late BetterPlayerDataSource _betterPlayerDataSource;
  final TextEditingController _urlController = TextEditingController();

  final TextEditingController _minBufferController =
      TextEditingController(text: "15000");
  final TextEditingController _maxBufferController =
      TextEditingController(text: "50000");
  final TextEditingController _bufferForPlaybackController =
      TextEditingController(text: "2500");
  final TextEditingController _bufferForPlaybackAfterRebufferController =
      TextEditingController(text: "5000");

  final TextEditingController _targetOffsetController =
      TextEditingController(text: "10000");
  final TextEditingController _minOffsetController =
      TextEditingController(text: "5000");
  final TextEditingController _maxOffsetController =
      TextEditingController(text: "15000");
  final TextEditingController _minPlaybackSpeedController =
      TextEditingController(text: "0.95");
  final TextEditingController _maxPlaybackSpeedController =
      TextEditingController(text: "1.05");

  BetterPlayerVideoFormat _videoFormat = BetterPlayerVideoFormat.hls;

  // ── SharedPreferences keys ──────────────────────────────────────────────
  static const _kUrl = 'np_url';
  static const _kFormat = 'np_video_format';
  static const _kMinBuffer = 'np_min_buffer';
  static const _kMaxBuffer = 'np_max_buffer';
  static const _kBufForPlay = 'np_buf_for_play';
  static const _kBufAfterRebuf = 'np_buf_after_rebuf';
  static const _kTargetOffset = 'np_target_offset';
  static const _kMinOffset = 'np_min_offset';
  static const _kMaxOffset = 'np_max_offset';
  static const _kMinSpeed = 'np_min_speed';
  static const _kMaxSpeed = 'np_max_speed';

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUrl, _urlController.text.trim());
    await prefs.setInt(_kFormat, _videoFormat.index);
    await prefs.setString(_kMinBuffer, _minBufferController.text);
    await prefs.setString(_kMaxBuffer, _maxBufferController.text);
    await prefs.setString(_kBufForPlay, _bufferForPlaybackController.text);
    await prefs.setString(_kBufAfterRebuf, _bufferForPlaybackAfterRebufferController.text);
    await prefs.setString(_kTargetOffset, _targetOffsetController.text);
    await prefs.setString(_kMinOffset, _minOffsetController.text);
    await prefs.setString(_kMaxOffset, _maxOffsetController.text);
    await prefs.setString(_kMinSpeed, _minPlaybackSpeedController.text);
    await prefs.setString(_kMaxSpeed, _maxPlaybackSpeedController.text);
    log('Player settings saved.');
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_kUrl) ?? 'https://assets-dev.eduport.app/live/2e60edde-235a-470f-896b-ed3c27fe9a0c/index.m3u8';
    final formatIndex = prefs.getInt(_kFormat) ?? BetterPlayerVideoFormat.hls.index;

    setState(() {
      _urlController.text = url;
      _videoFormat = BetterPlayerVideoFormat.values[formatIndex];
      _minBufferController.text = prefs.getString(_kMinBuffer) ?? '15000';
      _maxBufferController.text = prefs.getString(_kMaxBuffer) ?? '50000';
      _bufferForPlaybackController.text = prefs.getString(_kBufForPlay) ?? '2500';
      _bufferForPlaybackAfterRebufferController.text = prefs.getString(_kBufAfterRebuf) ?? '5000';
      _targetOffsetController.text = prefs.getString(_kTargetOffset) ?? '10000';
      _minOffsetController.text = prefs.getString(_kMinOffset) ?? '5000';
      _maxOffsetController.text = prefs.getString(_kMaxOffset) ?? '15000';
      _minPlaybackSpeedController.text = prefs.getString(_kMinSpeed) ?? '0.95';
      _maxPlaybackSpeedController.text = prefs.getString(_kMaxSpeed) ?? '1.05';
    });
    log('Player settings loaded. URL: $url');
  }

  @override
  void initState() {
    super.initState();
    _loadSettings().then((_) => _initPlayer(_urlController.text));
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
      videoFormat: _videoFormat,
      bufferingConfiguration: BetterPlayerBufferingConfiguration(
        minBufferMs: int.tryParse(_minBufferController.text) ?? 15000,
        maxBufferMs: int.tryParse(_maxBufferController.text) ?? 50000,
        bufferForPlaybackMs:
            int.tryParse(_bufferForPlaybackController.text) ?? 2500,
        bufferForPlaybackAfterRebufferMs:
            int.tryParse(_bufferForPlaybackAfterRebufferController.text) ??
                5000,
      ),
      liveConfiguration: BetterPlayerLiveConfiguration(
        targetOffsetMs: int.tryParse(_targetOffsetController.text) ?? 10000,
        minOffsetMs: int.tryParse(_minOffsetController.text) ?? 5000,
        maxOffsetMs: int.tryParse(_maxOffsetController.text) ?? 15000,
        minPlaybackSpeed:
            double.tryParse(_minPlaybackSpeedController.text) ?? 0.95,
        maxPlaybackSpeed:
            double.tryParse(_maxPlaybackSpeedController.text) ?? 1.05,
      ),
    );

    _betterPlayerController = BetterPlayerController(
      betterPlayerConfiguration,
    );

    _betterPlayerController?.setupDataSource(_betterPlayerDataSource);
  }

  void _playCustomUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    _saveSettings(); // persist before applying
    // Dispose the old controller and create a fresh one with the new URL.
    _betterPlayerController?.dispose();
    setState(() {
      _initPlayer(url);
    });
  }

  @override
  void dispose() {
    _betterPlayerController?.dispose();
    _urlController.dispose();
    _minBufferController.dispose();
    _maxBufferController.dispose();
    _bufferForPlaybackController.dispose();
    _bufferForPlaybackAfterRebufferController.dispose();
    _targetOffsetController.dispose();
    _minOffsetController.dispose();
    _maxOffsetController.dispose();
    _minPlaybackSpeedController.dispose();
    _maxPlaybackSpeedController.dispose();
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
            child: _betterPlayerController == null
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  )
                : BetterPlayer(controller: _betterPlayerController!),
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
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildSectionHeader('Video Format'),
                  const SizedBox(height: 8),
                  _buildVideoFormatDropdown(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Buffering Configuration (Android)'),
                  const SizedBox(height: 12),
                  _buildTextField(_minBufferController, 'Min Buffer (ms)'),
                  _buildTextField(_maxBufferController, 'Max Buffer (ms)'),
                  _buildTextField(
                      _bufferForPlaybackController, 'Buffer for Playback (ms)'),
                  _buildTextField(_bufferForPlaybackAfterRebufferController,
                      'Buffer after Rebuffer (ms)'),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Live Configuration (Android)'),
                  const SizedBox(height: 12),
                  _buildTextField(_targetOffsetController, 'Target Offset (ms)'),
                  _buildTextField(_minOffsetController, 'Min Offset (ms)'),
                  _buildTextField(_maxOffsetController, 'Max Offset (ms)'),
                  _buildTextField(
                      _minPlaybackSpeedController, 'Min Playback Speed'),
                  _buildTextField(
                      _maxPlaybackSpeedController, 'Max Playback Speed'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _playCustomUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Apply Configuration & Play',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _saveSettings();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings saved ✓'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Settings',
                          style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildVideoFormatDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BetterPlayerVideoFormat>(
          isExpanded: true,
          dropdownColor: Colors.grey[900],
          value: _videoFormat,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: BetterPlayerVideoFormat.values.map((format) {
            return DropdownMenuItem(
              value: format,
              child: Text(format.toString().split('.').last.toUpperCase()),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _videoFormat = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          filled: true,
          fillColor: Colors.white10,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
