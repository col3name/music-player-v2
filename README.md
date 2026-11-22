# Music Hero Sheet · SwiftUI iOS demo

Native iOS 17+ sample reproducing the attached music-list bottom sheet and the artwork-expansion gesture in SwiftUI. No packages or server required.

## Open and run

1. Unzip the archive and open `MusicHeroSheet.xcodeproj` in Xcode 15 or newer.
2. Select the shared **MusicHeroSheet** scheme and any iPhone simulator (the reference is close to an iPhone 17 Pro size).
3. Press **⌘R**.

On a physical iPhone, choose your personal development team in **Signing & Capabilities** and use a unique bundle identifier. Simulator builds need no paid Apple Developer account.

From a Mac terminal:

```sh
xcodebuild -project MusicHeroSheet.xcodeproj \
  -scheme MusicHeroSheet \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

## Interaction

- **Tap the cover artwork** in the compact player to expand it into the full-screen poster using `matchedGeometryEffect` and a spring.
- **Swipe the expanded poster left or right** to switch tracks. Its scale animates subtly with play/pause.
- **Swipe down on the expanded poster** to follow the drag and dismiss the full-screen player.
- **Tap the waveform button** in the full-screen controls to toggle Ambient Mode, which adds a slow, blurred artwork wash behind the player.
- **Tap the chevron or swipe down** to restore the bottom-sheet player and its small poster.
- **Tap a track** to select and play it. Play/pause, previous, next, shuffle, repeat, scrubbing, and full-player volume work.
- **Share** uses native `ShareLink`. **Add to Profile** toggles its visible state (local UI demo).
- **Drag the bottom-sheet handle down** to dismiss the sheet, then tap **Open Music Library** to re-open it.
- VoiceOver descriptions, large touch targets, reduce-motion fallback, safe-area handling, and SF Symbols are included.

## Project structure

- `MusicSheetScene.swift` – sheet, song rows, compact dock, animation state
- `ExpandedPlayerView.swift` – poster layout, soft gradient, expanded controls
- `ArtworkView.swift` – single reusable artwork rendering
- `PlayerControls.swift` – scrubber, playback actions, profile button
- `AudioPlaybackManager.swift` – native `AVAudioPlayer` implementation
- `DemoTrack.swift` – tracks loaded from the project `music` folder
- `Assets.xcassets` – artwork cropped from the user-provided screenshots
- `Audio/track-0...track-7` – audio files copied from `music`; the folder is bundled with the app

The playlist uses the eight audio files present in the repository's `music` folder. Track 3 (`track-2.mp3`) has no embedded title or artist metadata, so it is shown as “Трек из music”. Add an `audioFileName` entry in `DemoTrack.swift` when replacing or adding a bundled track. The ambient preview is no longer used as a fallback.

## Layout notes

The design uses a custom sheet instead of `.sheet` / `.fullScreenCover` because those native presentation windows prevent one shared artwork hero transition. The top sheet geometry, row dimensions, palette, rounded corners, and bottom controls approximate the provided screenshots; exact device rendering must be visually checked in the simulator on your target iPhone.
