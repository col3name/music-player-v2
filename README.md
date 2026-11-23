# Music Player V2

## 1. How apply to telegram-ios source code
```
# clone telegram-ios https://github.com/TelegramMessenger/Telegram-iOS

git checkout 24638bc69b

# apply changes http://github.com/col3name/timequoute-voice-message/blob/feature/stream-dynamic-island/changes.patch
git apply changes.patch
```

## 2.  Run ios demo app with player mechanics (fast way without build heavy entire telegram-ios app)

Song playlist and an animated full-screen music player.

Visual prototype, not a Telegram client or API integration. It plays demo audio bundled with the app (MP3 and M4A files); playlists and profile actions are local UI examples.

## Before & After

| Before | After                          |
| --- |--------------------------------|
| ![Before](docs/media/before.jpg) | ![After](docs/media/after.png) |

[Video Demo](docs/media/music-v2.1-demo.mp4)

## Features

- Expand and dismiss the player with gestures and animated artwork transitions.
- Swipe across the artwork to change tracks.
- Ambient Mode adds a soft, blurred artwork background.
- Playback controls include play/pause, scrubbing, volume, shuffle, and repeat.
- Flying poster animation

## Run

1. Open `MusicHeroSheet.xcodeproj` in Xcode.
2. Select the **MusicHeroSheet** scheme and an iOS 17+ iPhone simulator.
3. Press **⌘R**. For a physical device, configure your development team under **Signing & Capabilities**.

Or build from Terminal on macOS:

```sh
xcodebuild -project MusicHeroSheet.xcodeproj \
  -scheme MusicHeroSheet \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

No external packages or server are required. The player uses local audio files in `MusicHeroSheet/Audio/`; track metadata is defined in `MusicHeroSheet/DemoTrack.swift`.

Русская версия: [README-ru.md](README-ru.md).
