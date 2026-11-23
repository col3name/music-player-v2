import AVFoundation
import Accelerate
import Combine
import Foundation
import MediaPlayer
import UIKit

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
    @Published private(set) var frequencyBands: [CGFloat] = [0, 0, 0]
    @Published var shuffleEnabled = false
    @Published var repeatEnabled = false
    @Published var addedToProfile = false

    private var audio: AVAudioPlayer?
    private var analysisFile: AVAudioFile?
    private let fftSetup = vDSP_create_fftsetup(11, FFTRadix(kFFTRadix2))
    private var playbackRequestID = 0
    private var remoteCommandsConfigured = false

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
        configureRemoteCommands()
        loadAudio(startingAt: 0, for: track)
        updateNowPlaying()
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
            analysisFile = try AVAudioFile(forReading: url)
            audio?.currentTime = min(seconds, audio?.duration ?? seconds)
            elapsed = audio?.currentTime ?? seconds
        } catch {
            analysisFile = nil
            print("Could not open bundled demo audio: \(error)")
        }
    }

    func tick() {
        guard let audio else { return }
        elapsed = audio.currentTime
        updateFrequencyBands()
        updateNowPlaying()
        if isPlaying && !audio.isPlaying {
            if repeatEnabled {
                audio.currentTime = 0
                audio.play()
            } else if canAdvanceToNextTrack {
                next()
            } else {
                isPlaying = false
                elapsed = duration
                updateNowPlaying()
            }
        }
    }

    private func updateFrequencyBands() {
        let fftSize = 2048
        guard isPlaying,
              let file = analysisFile,
              let fftSetup,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(fftSize)),
              let channels = buffer.floatChannelData else {
            frequencyBands = [0, 0, 0]
            return
        }

        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return }
        file.framePosition = AVAudioFramePosition(max(0, audio?.currentTime ?? 0) * sampleRate)
        do {
            try file.read(into: buffer, frameCount: AVAudioFrameCount(fftSize))
        } catch {
            frequencyBands = [0, 0, 0]
            return
        }

        let count = Int(buffer.frameLength)
        guard count == fftSize else { return }
        let channelCount = Int(file.processingFormat.channelCount)
        var samples = [Float](repeating: 0, count: fftSize)
        for channel in 0..<channelCount {
            for index in 0..<fftSize {
                samples[index] += channels[channel][index] / Float(max(channelCount, 1))
            }
        }

        var real = [Float](repeating: 0, count: fftSize / 2)
        var imaginary = [Float](repeating: 0, count: fftSize / 2)
        var spectrum = [Float](repeating: 0, count: fftSize / 2)
        let log2Size = vDSP_Length(log2(Float(fftSize)))
        samples.withUnsafeMutableBufferPointer { sampleBuffer in
            real.withUnsafeMutableBufferPointer { realBuffer in
                imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                    spectrum.withUnsafeMutableBufferPointer { spectrumBuffer in
                        var split = DSPSplitComplex(realp: realBuffer.baseAddress!,
                                                    imagp: imaginaryBuffer.baseAddress!)
                        sampleBuffer.baseAddress!.withMemoryRebound(to: DSPComplex.self,
                                                                    capacity: fftSize / 2) { complex in
                            vDSP_ctoz(complex, 2, &split, 1, vDSP_Length(fftSize / 2))
                        }
                        vDSP_fft_zrip(fftSetup, &split, 1, log2Size, FFTDirection(FFT_FORWARD))
                        vDSP_zvmags(&split, 1, spectrumBuffer.baseAddress!, 1,
                                    vDSP_Length(fftSize / 2))
                    }
                }
            }
        }

        let ranges: [(Double, Double)] = [(35, 250), (250, 2_000), (2_000, 10_000)]
        frequencyBands = ranges.map { lower, upper in
            let firstBin = max(1, Int(lower * Double(fftSize) / sampleRate))
            let lastBin = min(fftSize / 2, Int(upper * Double(fftSize) / sampleRate))
            guard firstBin < lastBin else { return 0 }
            let meanPower = spectrum[firstBin..<lastBin].reduce(Float.zero, +)
                / Float(lastBin - firstBin)
            let level = min(1, max(0, sqrt(meanPower) / Float(fftSize) * 60))
            return CGFloat(level)
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
            updateNowPlaying()
        } else {
            if elapsed >= duration - 0.1 { seek(to: 0) }
            guard let audio else { return }
            // Reflect the tap immediately. Audio-session activation can complete
            // asynchronously, so don't make the controls wait for it.
            playbackRequestID += 1
            let requestID = playbackRequestID
            isPlaying = true
            isPreparingPlayback = true
            updateNowPlaying()

            Task { @MainActor in
                let activated = await activateAudioSession()
                guard requestID == playbackRequestID, isPlaying else { return }
                isPreparingPlayback = false
                guard activated, audio.play() else {
                    isPlaying = false
                    updateNowPlaying()
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
        updateNowPlaying()
    }

    func select(_ selected: DemoTrack, autoPlay: Bool = true, slideDirection: ArtworkSlideDirection? = nil) {
        playbackRequestID += 1
        audio?.stop()
        artworkSlideDirection = slideDirection
        track = selected
        isPlaying = false
        loadAudio(startingAt: 0, for: selected)
        updateNowPlaying()
        if autoPlay {
            togglePlayback()
        } else {
            updateNowPlaying()
        }
    }

    func next() {
        guard !DemoTrack.examples.isEmpty else { return }
        let current = DemoTrack.examples.firstIndex(of: track) ?? 0
        guard shuffleEnabled || current < DemoTrack.examples.count - 1 else { return }
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

    private var canAdvanceToNextTrack: Bool {
        guard !DemoTrack.examples.isEmpty else { return false }
        return shuffleEnabled || (DemoTrack.examples.firstIndex(of: track) ?? 0) < DemoTrack.examples.count - 1
    }

    func previous() {
        // Match a conventional music player: a quick tap near the start skips
        // back, while a tap later in the track restarts the current song.
        if elapsed > 3 {
            seek(to: 0)
            if isPlaying {
                audio?.play()
            }
            return
        }
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

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audio?.currentTime ?? elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let audio, audio.duration.isFinite, audio.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = audio.duration
        }
        if let imageName = track.imageName, let image = UIImage(named: imageName) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        let commands = MPRemoteCommandCenter.shared()
        let index = DemoTrack.examples.firstIndex(of: track) ?? 0
        commands.nextTrackCommand.isEnabled = index + 1 < DemoTrack.examples.count
        commands.previousTrackCommand.isEnabled = index > 0
    }

    private func configureRemoteCommands() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true
        let commands = MPRemoteCommandCenter.shared()
        commands.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.isPlaying { self.togglePlayback() }
            }
            return .success
        }
        commands.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.togglePlayback()
            }
            return .success
        }
        commands.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        commands.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.selectPreviousTrack() }
            return .success
        }
    }
}
