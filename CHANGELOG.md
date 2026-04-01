

### 1.0.4

#### 🐛 Bug Fixes
* **HLS live detection fix**: `_isLive` was always `true` for multi-bitrate HLS streams because `EXT-X-ENDLIST` only appears in variant media playlists, not in the master playlist. Now correctly fetches the first variant media playlist and checks it for `EXT-X-ENDLIST` on startup to determine live status accurately.
* **Android 14 stability**: Fixed `ERROR_CODE_FAILED_RUNTIME_CHECK` crashes on Android 14+ devices by disabling `experimentalSetMediaCodecAsyncCryptoFlagEnabled` (now `false` by default for API 34+).
* **Behind Live Window**: Added automatic recovery and seek-to-live logic when the player falls behind the HLS live window (`ERROR_CODE_BEHIND_LIVE_WINDOW`).
* **iOS `liveStreamEnded` fix**: The previous `onReadyToPlay`-based detection was gated by `!_isInitialized` and never fired after init. Replaced with two reliable detection paths:
  - **Duration KVO** (`AVPlayerItem.duration`): When `kCMTimeIndefinite` transitions to a finite value, `EXT-X-ENDLIST` was received — fires `liveStreamEnded` immediately.
  - **`itemDidPlayToEndTime`**: If `wasLiveStream` is true when playback ends, fires `liveStreamEnded` instead of `completed`.
* **Android `liveStreamEnded` fix**: Made detection more robust with a dual-signal approach:
  - **`STATE_READY`**: Uses `isCurrentMediaItemLive` (ExoPlayer's authoritative flag) to reliably set `wasLiveStream = true`.
  - **`STATE_ENDED`**: If `wasLiveStream` is true, fires `liveStreamEnded` instead of `completed`. This guarantees detection even when `onTimelineChanged` fires too late.
* **Dart event comparison fix**: Fixed incorrect `event == BetterPlayerEventType.liveStreamEnded` comparison (comparing `BetterPlayerEvent` object to an enum value). Corrected to `event.betterPlayerEventType ==`.

#### ✨ New Features
* **Native Retry Mechanism**: Robust error recovery with exponential backoff on both Android and iOS. Automatically attempts to restore playback after transient network failures without interrupting the user experience.
* **`liveStreamEnded` event**: Full-stack detection and event propagation for when an HLS live stream ends at runtime.
  - **Android**: Dual detection via `onTimelineChanged` (early) and `STATE_ENDED` + `wasLiveStream` flag (definitive).
  - **iOS**: Dual detection via `AVPlayerItem.duration` KVO (early) and `itemDidPlayToEndTime` + `wasLiveStream` flag (definitive).
  - **Dart**: `VideoEventType.liveStreamEnded` and `BetterPlayerEventType.liveStreamEnded` propagate through `MethodChannelVideoPlayer` → `VideoPlayerController` → `BetterPlayerController`. `_isLive` is set to `false` and `isLiveStreamController` broadcasts `false`.
* **Live-ended UI** (example app): When `liveStreamEnded` fires, an animated overlay appears on the video with a "Live Has Ended" state and a "Watch as Streamed Live" button that reloads the stream as a seekable VOD recording.

#### ⚡ Performance Improvements
* **Android ExoPlayer**: Enabled `EXTENSION_RENDERER_MODE_ON` and `forceEnableMediaCodecAsynchronousQueueing` on the `DefaultRenderersFactory` to prevent video freeze while audio continues during `.m4s` HLS chunk playback (hardware decoder stall on fragmented MP4 streams).

### 1.0.3
* Interactive Viewer Update 
* WakeLock Fix and gradle update

### 1.0.2
* Updates Readme with relevant info 

## 1.0.0

* Initial release. Forked from better_player_plus


