import SwiftUI

struct PlaybackScrubber: View {
    @ObservedObject var player: AudioPlaybackManager
    var darkAppearance: Bool = false
    @State private var draggingValue: Double?

    private var presentedValue: Double { draggingValue ?? player.progress }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(darkAppearance ? Color.white.opacity(0.28) : Color.black.opacity(0.16))
                        .frame(height: 6)
                    Capsule(style: .continuous)
                        .fill(darkAppearance ? Color.white : Color.black)
                        .frame(width: max(11, width * presentedValue), height: 6)
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            draggingValue = min(max(value.location.x / max(width, 1), 0), 1)
                        }
                        .onEnded { value in
                            player.seek(to: min(max(value.location.x / max(width, 1), 0), 1))
                            draggingValue = nil
                        }
                )
                .accessibilityElement()
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(Int(presentedValue * 100)) percent")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: player.seek(to: min(player.progress + 0.05, 1))
                    case .decrement: player.seek(to: max(player.progress - 0.05, 0))
                    @unknown default: break
                    }
                }
            }
            .frame(height: 24)

            HStack {
                Text(AudioPlaybackManager.timeString(presentedValue * player.duration))
                Spacer()
                Text(AudioPlaybackManager.timeString(max(player.duration - presentedValue * player.duration, 0)))
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(darkAppearance ? .white.opacity(0.84) : .black.opacity(0.68))
            .monospacedDigit()
        }
    }
}

struct TransportControls: View {
    @ObservedObject var player: AudioPlaybackManager
    var compact: Bool = false
    var darkAppearance: Bool = false
    var mutedSecondaryControls: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            transportButton("arrow.up.arrow.down", active: player.shuffleEnabled,
                            mutedWhenInactive: mutedSecondaryControls, label: "Shuffle",
                            size: compact ? 19 : 23) {
                player.shuffleEnabled.toggle()
            }
            Spacer(minLength: 8)
            transportButton("backward.fill", label: "Previous track", size: compact ? 28 : 35) {
                player.previous()
            }.buttonStyle(TrackSkipButtonStyle())
            Spacer(minLength: 8)
            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: compact ? 40 : 48, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(darkAppearance ? .white : .black)
                    .frame(width: compact ? 67 : 76, height: compact ? 59 : 66)
            }
            .animation(.snappy(duration: 0.12), value: player.isPlaying)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            Spacer(minLength: 8)
            transportButton("forward.fill", label: "Next track", size: compact ? 28 : 35) {
                player.next()
            }.buttonStyle(TrackSkipButtonStyle())
            Spacer(minLength: 8)
            transportButton("repeat", active: player.repeatEnabled,
                            mutedWhenInactive: mutedSecondaryControls, label: "Repeat",
                            size: compact ? 19 : 23) {
                player.repeatEnabled.toggle()
            }
        }
        .foregroundStyle(darkAppearance ? .white : .black)
        .buttonStyle(.plain)
    }

    private func transportButton(
        _ systemName: String,
        active: Bool = false,
        mutedWhenInactive: Bool = false,
        label: String,
        size: CGFloat = 23,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 44, height: 54)
                .foregroundStyle(active
                    ? Color(red: 0, green: 0.53, blue: 0.98)
                    : (mutedWhenInactive
                        ? (darkAppearance ? .white.opacity(0.58) : Color(red: 0.40, green: 0.40, blue: 0.42))
                        : (darkAppearance ? .white.opacity(size < 30 ? 0.78 : 1) : (compact ? .black : (size < 30 ? .black.opacity(0.62) : .black)))))
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

private struct TrackSkipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct ProfileAddButton: View {
    @ObservedObject var player: AudioPlaybackManager

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                player.addedToProfile.toggle()
            }
        } label: {
            Label(player.addedToProfile ? "Added to Profile" : "Add to Profile",
                  systemImage: player.addedToProfile ? "checkmark.circle.fill" : "person.crop.circle.badge.plus")
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(.white)
                .background(Color(red: 0.0, green: 0.53, blue: 1.0),
                            in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
