import AVFoundation
import Combine
import Foundation

enum ArtworkSlideDirection: Equatable {
    case next
    case previous

    var sign: CGFloat { self == .next ? 1 : -1 }
}

/// Plays the local audio files bundled from the project's `music` folder.
@MainActor
final class AudioPlaybackManager: ObservableObject {
    @Published private(set) var track: DemoTrack = DemoTrack.examples[0]
    @Published private(set) var isPlaying = false
    @Published private(set) var isPreparingPlayback = false
    @Published private(set) var artworkSlideDirection: ArtworkSlideDirection?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var shuffleEnabled = false
    @Published var repeatEnabled = false
    @Published var addedToProfile = false

    private var audio: AVAudioPlayer?
    private var playbackRequestID = 0

    var duration: TimeInterval {
        audio?.duration ?? 202
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    init() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        #endif
        loadAudio(startingAt: 0, for: track)
    }

    private func loadAudio(startingAt seconds: TimeInterval, for track: DemoTrack) {
        let fileName = URL(fileURLWithPath: track.audioFileName)
        guard let url = Bundle.main.url(forResource: fileName.deletingPathExtension().lastPathComponent,
                                        withExtension: fileName.pathExtension,
                                        subdirectory: "Audio") else {
            audio = nil
            elapsed = seconds
            print("Missing bundled audio file: \(track.audioFileName)")
            return
        }
        do {
            audio = try AVAudioPlayer(contentsOf: url)
            audio?.currentTime = min(seconds, audio?.duration ?? seconds)
            elapsed = audio?.currentTime ?? seconds
        } catch {
            print("Could not open bundled demo audio: \(error)")
        }
    }

    func tick() {
        guard let audio else { return }
        elapsed = audio.currentTime
        if isPlaying && !audio.isPlaying {
            if repeatEnabled {
                audio.currentTime = 0
                audio.play()
            } else {
                isPlaying = false
                elapsed = duration
            }
        }
    }

    func setVolume(_ value: Float) {
        audio?.volume = min(max(value, 0), 1)
    }

    func togglePlayback() {
        if isPlaying {
            playbackRequestID += 1
            audio?.pause()
            isPlaying = false
            isPreparingPlayback = false
        } else {
            if elapsed >= duration - 0.1 { seek(to: 0) }
            guard let audio else { return }
            // Reflect the tap immediately. Audio-session activation can complete
            // asynchronously, so don't make the controls wait for it.
            playbackRequestID += 1
            let requestID = playbackRequestID
            isPlaying = true
            isPreparingPlayback = true

            Task { @MainActor in
                let activated = await activateAudioSession()
                guard requestID == playbackRequestID, isPlaying else { return }
                isPreparingPlayback = false
                guard activated, audio.play() else {
                    isPlaying = false
                    return
                }
            }
        }
    }

    private func activateAudioSession() async -> Bool {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 27.0, *) {
            return await withCheckedContinuation { continuation in
                session.activate(options: []) { activated, error in
                    if let error {
                        print("Could not activate audio session: \(error)")
                    }
                    continuation.resume(returning: activated)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try session.setActive(true)
                        continuation.resume(returning: true)
                    } catch {
                        print("Could not activate audio session: \(error)")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
        #else
        return true
        #endif
    }

    func seek(to fraction: Double) {
        let time = min(max(fraction, 0), 1) * duration
        audio?.currentTime = time
        elapsed = time
    }

    func select(_ selected: DemoTrack, autoPlay: Bool = true, slideDirection: ArtworkSlideDirection? = nil) {
        playbackRequestID += 1
        audio?.stop()
        artworkSlideDirection = slideDirection
        track = selected
        isPlaying = false
        loadAudio(startingAt: 0, for: selected)
        if autoPlay { togglePlayback() }
    }

    func next() {
        guard !DemoTrack.examples.isEmpty else { return }
        let current = DemoTrack.examples.firstIndex(of: track) ?? 0
        guard current < DemoTrack.examples.count - 1 else { return }
        let index: Int
        if shuffleEnabled {
            let others = DemoTrack.examples.indices.filter { DemoTrack.examples[$0].id != track.id }
            guard let randomIndex = others.randomElement() else { return }
            index = randomIndex
        } else {
            index = current + 1
        }
        select(DemoTrack.examples[index], autoPlay: isPlaying, slideDirection: .next)
    }

    func previous() {
        selectPreviousTrack()
    }

    /// Swipe navigation always changes tracks; the previous button keeps its restart behavior.
    func selectPreviousTrack() {
        guard !DemoTrack.examples.isEmpty else { return }
        let current = DemoTrack.examples.firstIndex(of: track) ?? 0
        guard current > 0 else { return }
        let index = current - 1
        select(DemoTrack.examples[index], autoPlay: isPlaying, slideDirection: .previous)
    }

    static func timeString(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.isFinite ? seconds : 0))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}
