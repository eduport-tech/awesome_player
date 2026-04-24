# HLS Live Documentation

This document explains how HLS Live streaming works and how it is implemented and optimized in the `awesome_player` package for both Android and iOS.

## 1. How HLS Live Works

HTTP Live Streaming (HLS) works by breaking a live video stream into small media segments (usually `.ts` or `.m4s` files).

### Core Components:
*   **Master Playlist (`.m3u8`)**: A top-level manifest that lists available bitrates and resolutions (variants).
*   **Media Playlist (`.m3u8`)**: Specific to a bitrate. In a live stream, this playlist is updated frequently (every few segments).
*   **Segments**: The actual video/audio data.
*   **Sliding Window**: For live streams, the media playlist only contains the most recent segments. As new segments are added, old ones are removed.

### Live Dynamics:
*   **Live Edge**: The point in time where the most recent segment is being produced.
*   **Latency**: The delay between the real-life event and the player’s playback. Lower latency requires smaller segments and smaller buffers, but increases the risk of stalling.
*   **EXT-X-ENDLIST**: A tag added to the media playlist when the live stream ends, signaling the player to stop updating the playlist.

---

## 2. Implementation Architecture

The `awesome_player` package uses a **Method Channel** architecture to communicate between Flutter and native platforms.

*   **Flutter Layer**: `VideoPlayerController` manages the state and provides a high-level API.
*   **Native Layer (Android)**: Uses **androidx.media3 (ExoPlayer)**.
*   **Native Layer (iOS)**: Uses **AVPlayer**.

---

## 3. Android Optimization (Media3)

Android implementation leverages ExoPlayer's advanced live streaming capabilities.

### Live Configuration
We use `MediaItem.LiveConfiguration` to fine-tune the playback experience.
*   **Target Offset**: How far back from the live edge the player should aim to be. Smaller values = lower latency.
*   **Playback Speed Adjustment**: ExoPlayer can slightly speed up or slow down playback to catch up or wait for the live edge without stuttering.

### Buffering (LoadControl)
Custom buffering is handled via `CustomDefaultLoadControl.kt`.
```kotlin
val loadBuilder = DefaultLoadControl.Builder()
loadBuilder.setBufferDurationsMs(
    minBufferMs, // Default: 50,000ms
    maxBufferMs, // Default: 50,000ms
    bufferForPlaybackMs, // Default: 2,500ms
    bufferForPlaybackAfterRebufferMs // Default: 5,000ms
)
```
**Optimization**: For low-latency live streams, reducing `minBufferMs` and `bufferForPlaybackMs` helps start playback faster and closer to the live edge.

### Behind Live Window Recovery
If the player falls too far behind the sliding window (e.g., due to network issues), ExoPlayer throws an error. We recover by seeking back to the live edge:
```kotlin
if (error.errorCode == PlaybackException.ERROR_CODE_BEHIND_LIVE_WINDOW) {
    exoPlayer?.seekToDefaultPosition()
    exoPlayer?.prepare()
}
```

### End of Live Stream detection
We monitor the HLS manifest for the `#EXT-X-ENDLIST` tag to notify Flutter when the live event has finished.

---

## 4. iOS Optimization (AVPlayer)

iOS uses the native `AVFoundation` framework.

### Low Latency Tip
We set `automaticallyWaitsToMinimizeStalling` to `false` to reduce initial startup time.
```objectivec
if (@available(iOS 10.0, *)) {
    _player.automaticallyWaitsToMinimizeStalling = false;
}
```
*Note: While this reduces latency, it requires a manual check to resume playback if it stalls.*

### Quality and Bandwidth Control
Use `preferredPeakBitRate` to limit bandwidth usage or `preferredMaximumResolution` for HLS.
```objectivec
_player.currentItem.preferredPeakBitRate = bitrate;
_player.currentItem.preferredMaximumResolution = CGSizeMake(width, height);
```

### Main Optimization: Seeking to Live Edge
One of the most important optimizations for a live stream is the ability to jump back to the "real-time" edge after a pause or network delay.

#### Android (Media3) Implementation
In ExoPlayer, `seekToDefaultPosition()` on a live stream effectively jumps to the target live offset defined in the manifest or `LiveConfiguration`.
```kotlin
fun seekToLive() {
    if (exoPlayer?.isCurrentMediaItemLive == true) {
        exoPlayer?.seekToDefaultPosition()
    }
}
```

#### iOS (AVPlayer) Implementation
On iOS, live streams are identified by having an "indefinite" duration (`CMTIME_IS_INDEFINITE(item.duration)`). To seek to the live edge, we calculate it by adding the duration of the last seekable time range to its start time.
```objectivec
- (void)seekToLive {
    AVPlayerItem *currentItem = _player.currentItem;
    if (currentItem && currentItem.seekableTimeRanges.count > 0) {
        CMTimeRange seekableRange = [currentItem.seekableTimeRanges.lastObject CMTimeRangeValue];
        CMTime liveEdge = CMTimeAdd(seekableRange.start, seekableRange.duration);
        
        bool wasPlaying = _isPlaying;
        [_player seekToTime:liveEdge
            toleranceBefore:kCMTimeZero
             toleranceAfter:kCMTimeZero
          completionHandler:^(BOOL finished){
            if (finished && wasPlaying){
                 [_player play];
            }
        }];
    }
}
```

---

## 5. Flutter Implementation Example

You can configure these optimizations directly from your Dart code:

```dart
_controller = VideoPlayerController()
  ..setNetworkDataSource(
    "https://example.com/live.m3u8",
    targetOffsetMs: 3000,   // Aim for 3 seconds latency (Android)
    minOffsetMs: 2000,      // Minimum latency (Android)
    maxOffsetMs: 10000,     // Maximum latency (Android)
    bufferingConfiguration: BetterPlayerBufferingConfiguration(
      minBufferMs: 10000,   // 10s minimum buffer
      bufferForPlaybackMs: 1500, // Start playback after 1.5s
    ),
  );

// Seek to live edge manually
_controller.seekToLive();
```
