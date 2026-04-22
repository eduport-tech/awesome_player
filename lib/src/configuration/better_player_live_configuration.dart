/// Configuration class used to setup live streaming experience.
/// Currently used only in Android.
class BetterPlayerLiveConfiguration {
  /// The target live offset. The player will attempt to get close to this live offset during playback if possible.
  final int? targetOffsetMs;

  /// The minimum allowed live offset. Even when adjusting the offset to current network conditions, the player will not attempt to get below this offset during playback.
  final int? minOffsetMs;

  /// The maximum allowed live offset. Even when adjusting the offset to current network conditions, the player will not attempt to get above this offset during playback.
  final int? maxOffsetMs;

  /// The minimum playback speed the player can use to fall back when trying to reach the target live offset.
  final double? minPlaybackSpeed;

  /// The maximum playback speed the player can use to catch up when trying to reach the target live offset.
  final double? maxPlaybackSpeed;

  const BetterPlayerLiveConfiguration({
    this.targetOffsetMs,
    this.minOffsetMs,
    this.maxOffsetMs,
    this.minPlaybackSpeed,
    this.maxPlaybackSpeed,
  });
}
