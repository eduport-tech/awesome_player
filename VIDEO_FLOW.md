# Awesome Player: Video Playback Data Flow

When a user opens a screen containing a video, a complex series of handshakes occurs between the Flutter UI, the Dart Controller, and the Native Operating System. 

Use the sequence diagram below to visualize the exact methods called across the architectural layers:

```
sequenceDiagram
    participant UI
    participant Dart
    participant Platform
    participant Native

    UI->>Dart: Create Controller
    Dart->>Platform: init()
    Platform->>Native: init engine

    Dart->>Platform: create(DataSource)
    Platform->>Native: load video

    Native-->>Platform: textureId
    Platform-->>Dart: textureId

    Dart-->>UI: notifyListeners()
    UI->>UI: build UI

    Native-->>Dart: metadata
    Dart-->>UI: update UI

    UI->>Dart: play()
    Dart->>Platform: play()
    Platform->>Native: play

    loop playback
        Native-->>Dart: state update
        Dart-->>UI: refresh UI
    end
```

---

## Detailed Phase Breakdown

Here is exactly what happens during those phases:

### Phase 1: Initialization
1. **Dart UI:** Your app creates an instance of the video controller (e.g., `VideoPlayerController` or `AwesomePlayerController`).
2. **Platform Call:** The controller immediately asks the `VideoPlayerPlatform` to call its `init()` method. This fires a MethodChannel request down to the native Kotlin/Objective-C code, waking up the respective video engines on the device and clearing memory for a new session.

### Phase 2: Setting the Data Source
3. **`setDataSource` (`create` method):** Dart passes the configuration dict (containing the video URL, format hint, DRM licenses, and headers) across the MethodChannel to the native code.
4. **Native Allocation:** 
   * On **Android**, `BetterPlayer.kt` uses `ExoPlayer.Builder()` and attaches the data source (like `HlsMediaSource`).
   * On **iOS**, `BetterPlayer.m` sets up an `AVPlayerItem`.
5. **The `textureId` returns:** The native system reserves a place in the GPU to dump the video frames and reports that ID (`textureId`) back to Dart.

### Phase 3: Building the UI
6. **State Update:** The Dart controller now has a `textureId` and calls `notifyListeners()`. 
7. **Widget Build:** The Flutter UI rebuilds. It asks the platform interface how it should draw the video.
   * On Android, it returns `Texture(textureId: id)`. Flutter links its canvas directly to the Android GPU buffer.
   * On iOS, it forces a Platform View (`UiKitView`), carving out a hole in the Flutter canvas to mount the physical Apple `UIView`.

### Phase 4: Event Streaming & Playback
8. **EventChannel Handshake:** The native layer uses an ongoing `EventChannel` stream to send back asynchronous data (it tells Dart: *"I finished downloading the metadata, the video is 1920x1080 and 12 minutes long."*)
9. **UI Adapts:** Flutter wraps the `Texture` or `UiKitView` in an `AspectRatio` widget so it isn't squeezed. 
10. **`play()` method:** When the user taps play, a MethodChannel fires `.play(textureId)`. The native player begins pushing 60 frames per second to the GPU.
11. **Buffering Updates:** As it plays, the native event stream constantly fires `bufferingUpdate` and `playing` signals, causing your Flutter progress bars and buffering spinners to accurately update on screen.
