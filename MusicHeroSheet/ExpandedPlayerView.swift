import SwiftUI
import UIKit

private extension Color {
    func withBoostedSaturation(_ factor: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return Color(hue: Double(hue), saturation: Double(min(1, saturation * factor)), brightness: Double(brightness), opacity: Double(alpha))
    }

    func blended(with other: Color, fraction: CGFloat) -> Color {
        let first = UIColor(self)
        let second = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        guard first.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              second.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return self
        }
        let t = min(1, max(0, fraction))
        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t),
            opacity: Double(a1 + (a2 - a1) * t)
        )
    }
}

struct ExpandedPlayerView: View {
    @ObservedObject var player: AudioPlaybackManager
    @Binding var progress: CGFloat
    let settle: (CGFloat, CGFloat) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragStartProgress: CGFloat = 1
    @State private var isDragging = false
    @State private var ambientModeEnabled = false
    @State private var ambientDrift = false
    @State private var ambientColors: [Color] = []

    var body: some View {
        GeometryReader { geometry in
            let coverSize = min(geometry.size.width - 48, 355)

            ZStack {
                expandedBackground(size: geometry.size)

                VStack(spacing: 0) {
                    HStack {
                        Button { settle(0, 0) } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 19, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Close full-screen player")
                        Spacer()
                        Text("NOW PLAYING")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.7)
                            .foregroundStyle(.black.opacity(0.42))
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .foregroundStyle(.black.opacity(0.78))
                    .padding(.horizontal, 17)
                    .padding(.top, max(geometry.safeAreaInsets.top, 49) + 8)

                    Spacer(minLength: 48)

                    ArtworkView(track: player.track, cornerRadius: 6)
                        .frame(width: coverSize, height: coverSize)
                        // Keep vertical sheet dismissal on the artwork surface.
                        // A full-screen drag recognizer competes with the scrubber
                        // and transport buttons, making taps feel unreliable.
                        .simultaneousGesture(expandedDragGesture(in: geometry))
                        .opacity(0)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(key: FullArtworkFrameKey.self,
                                                       value: proxy.frame(in: .named("musicScene")))
                            }
                        }
                        .accessibilityAddTraits(.isImage)

                    // Flowing, blurred poster colors bridge the artwork and controls.
                    if progress > 0.01 {
                        IridescentArtworkBlend(colors: ambientColors)
                            .frame(width: coverSize + 170, height: 220)
                            .offset(y: 110)
                            .frame(height: 0)
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }

                ExpandedControls(player: player)
                        .frame(width: max(0, geometry.size.width - 50))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 15)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 16) + geometry.size.height * 0.09)
                        // Keep the lower control block at one size and position
                        // while the sheet expands; only the player backdrop fades in.
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .onAppear { updateAmbientColors() }
        .onChange(of: player.track.id) { _, _ in updateAmbientColors() }
        .onChange(of: ambientModeEnabled) { _, enabled in
            guard enabled, !reduceMotion else {
                ambientDrift = false
                return
            }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                ambientDrift.toggle()
            }
        }
    }

    private func expandedDragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartProgress = progress
                }
                let travelDistance = max(1, geometry.size.height * 0.72)
                let next = dragStartProgress - value.translation.height / travelDistance
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) { progress = min(1, max(0, next)) }
            }
            .onEnded { value in
                isDragging = false
                let projectedVelocity = (value.predictedEndTranslation.height - value.translation.height) * 5
                let travelDistance = max(1, geometry.size.height * 0.72)
                let projectedProgress = dragStartProgress - value.predictedEndTranslation.height / travelDistance
                let collapseProgress = max(0, min(1, value.translation.height / travelDistance))
                let target: CGFloat = collapseProgress >= (1.0 / 3.0) || projectedProgress <= 0.5 ? 0 : 1
                let velocity = min(5, max(-5, -projectedVelocity / travelDistance))
                settle(target, velocity)
            }
    }

    private func expandedBackground(size: CGSize) -> some View {
        ZStack {
            let colors = ambientColors.isEmpty
                ? [Color(red: 0.23, green: 0.12, blue: 0.11), Color(red: 0.48, green: 0.18, blue: 0.12), Color(red: 0.12, green: 0.09, blue: 0.09)]
                : ambientColors
            let vividColors = colors.map { $0.withBoostedSaturation(1.42) }
            // A warm rose wash reflects the artwork's skin tones and gives the
            // expanded backdrop the richer, rosy color seen in the reference.
            let rose = Color(red: 0.88, green: 0.52, blue: 0.50)

            // Keep the backdrop fully opaque all the way to the screen edges.
            // Translucent gradient stops and their blur can reveal a pale layer
            // underneath as white bands along the top and sides.
            colors[2]

            // The backdrop always follows the current poster. It fades to white
            // below the track title so the poster tint fills the marked artwork area.
            LinearGradient(stops: [
                .init(color: vividColors[0].blended(with: rose, fraction: 0.24), location: 0),
                .init(color: vividColors[1].blended(with: rose, fraction: 0.28), location: 0.34),
                .init(color: vividColors[2].blended(with: rose, fraction: 0.22), location: 0.56),
                .init(color: Color(red: 0.98, green: 0.88, blue: 0.87).opacity(0.88), location: 0.68),
                .init(color: .white, location: 0.76),
                .init(color: .white, location: 1)
            ], startPoint: .top, endPoint: .bottom)
                .animation(.easeInOut(duration: 0.55), value: ambientColors)

            // A broad blurred color-to-white veil softens the transition just
            // below the cover instead of leaving a hard horizontal boundary.
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: vividColors[1].blended(with: rose, fraction: 0.30).opacity(0.48), location: 0.28),
                .init(color: Color(red: 0.99, green: 0.91, blue: 0.90).opacity(0.76), location: 0.76),
                .init(color: .white, location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .frame(height: size.height * 0.20)
            .blur(radius: 34)
            .position(x: size.width / 2, y: size.height * 0.62)
            .allowsHitTesting(false)

            RadialGradient(colors: [vividColors[0].blended(with: rose, fraction: 0.20).opacity(0.44), .clear],
                           center: ambientDrift ? .init(x: 0.2, y: 0.3) : .init(x: 0.8, y: 0.25),
                           startRadius: 12, endRadius: size.width * 0.8)
            RadialGradient(colors: [vividColors[1].blended(with: rose, fraction: 0.18).opacity(0.40), .clear],
                           center: ambientDrift ? .init(x: 0.8, y: 0.58) : .init(x: 0.2, y: 0.62),
                           startRadius: 8, endRadius: size.width * 0.92)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: ambientDrift)

            LinearGradient(colors: [.black.opacity(0.10), .clear, .black.opacity(0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(ambientModeEnabled ? 0.35 : 0)
                .animation(.easeInOut(duration: 0.45), value: ambientModeEnabled)
        }
        // Extend an opaque poster-tinted base beneath every blurred layer so
        // the rounded white sheet underneath cannot show through at the top.
        .background(ambientColors.last ?? Color(red: 0.12, green: 0.09, blue: 0.09))
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
    }

    private func updateAmbientColors() {
        withAnimation(.easeInOut(duration: 0.55)) {
            ambientColors = PosterColorPalette.colors(for: player.track)
        }
    }
}

private struct IridescentArtworkBlend: View {
    let colors: [Color]
    @State private var phase = false

    private var palette: [Color] {
        colors.count >= 3
            ? colors
            : [Color(red: 0.65, green: 0.32, blue: 0.28), Color(red: 0.86, green: 0.62, blue: 0.50), Color(red: 0.28, green: 0.22, blue: 0.19)]
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [palette[0].opacity(0.88), .clear],
                           center: phase ? .init(x: 0.22, y: 0.22) : .init(x: 0.78, y: 0.25),
                           startRadius: 4, endRadius: 230)
            RadialGradient(colors: [palette[1].opacity(0.82), .clear],
                           center: phase ? .init(x: 0.78, y: 0.70) : .init(x: 0.25, y: 0.78),
                           startRadius: 8, endRadius: 250)
            RadialGradient(colors: [palette[2].opacity(0.72), .clear],
                           center: phase ? .init(x: 0.48, y: 0.88) : .init(x: 0.52, y: 0.16),
                           startRadius: 2, endRadius: 180)
        }
        .blur(radius: 48)
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black.opacity(0.9), location: 0.24),
                .init(color: .black.opacity(0.8), location: 0.68),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

/// Samples the cover into a small color histogram so Ambient Mode follows the artwork's
/// actual palette instead of stretching or blurring its full image.
enum PosterColorPalette {
    private struct Bucket {
        var red = 0
        var green = 0
        var blue = 0
        var count = 0
    }

    static func colors(for track: DemoTrack) -> [Color] {
        guard let name = track.imageName,
              let image = UIImage(named: name)?.cgImage else {
            return fallback(for: track.id)
        }

        let width = 32
        let height = 32
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let didRender = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard didRender else {
            return fallback(for: track.id)
        }

        var buckets: [Int: Bucket] = [:]
        var totalBrightness = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Int(pixels[index])
            let g = Int(pixels[index + 1])
            let b = Int(pixels[index + 2])
            let brightness = max(r, g, b)
            totalBrightness += Double(brightness) / 255.0
            guard brightness > 24, brightness < 248 else { continue }

            let key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
            var bucket = buckets[key, default: Bucket()]
            bucket.red += r
            bucket.green += g
            bucket.blue += b
            bucket.count += 1
            buckets[key] = bucket
        }

        let ranked = buckets.values
            .filter { $0.count > 0 }
            .sorted { lhs, rhs in
                let lhsSaturation = Double(max(lhs.red, max(lhs.green, lhs.blue)) - min(lhs.red, min(lhs.green, lhs.blue))) / 255
                let rhsSaturation = Double(max(rhs.red, max(rhs.green, rhs.blue)) - min(rhs.red, min(rhs.green, rhs.blue))) / 255
                return Double(lhs.count) * (0.65 + lhsSaturation) > Double(rhs.count) * (0.65 + rhsSaturation)
            }

        let selected = Array(ranked.prefix(3).map { bucket in
            Color(.sRGB,
                  red: Double(bucket.red) / Double(bucket.count * 255),
                  green: Double(bucket.green) / Double(bucket.count * 255),
                  blue: Double(bucket.blue) / Double(bucket.count * 255),
                  opacity: 1)
        })
        if selected.count == 3 {
            return selected
        }
        let averageBrightness = totalBrightness / Double(width * height)
        return averageBrightness < 0.24 ? darkFallback : fallback(for: track.id)
    }

    private static let darkFallback: [Color] = [
        Color(red: 0.13, green: 0.14, blue: 0.15),
        Color(red: 0.20, green: 0.20, blue: 0.21),
        Color(red: 0.09, green: 0.10, blue: 0.11)
    ]

    private static func fallback(for id: Int) -> [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.15, green: 0.27, blue: 0.48), Color(red: 0.48, green: 0.25, blue: 0.48), Color(red: 0.08, green: 0.13, blue: 0.25)],
            [Color(red: 0.10, green: 0.38, blue: 0.35), Color(red: 0.06, green: 0.16, blue: 0.24), Color(red: 0.18, green: 0.31, blue: 0.28)],
            [Color(red: 0.55, green: 0.22, blue: 0.25), Color(red: 0.18, green: 0.12, blue: 0.23), Color(red: 0.34, green: 0.16, blue: 0.18)],
            [Color(red: 0.75, green: 0.40, blue: 0.14), Color(red: 0.30, green: 0.15, blue: 0.14), Color(red: 0.45, green: 0.25, blue: 0.13)]
        ]
        return palettes[abs(id) % palettes.count]
    }
}

private struct ExpandedControls: View {
    @ObservedObject var player: AudioPlaybackManager

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.track.title)
                        .font(.system(size: 22, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(player.track.artist)
                        .font(.system(size: 16))
                        .foregroundStyle(.black.opacity(0.48))
                        .lineLimit(1)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .opacity(0)
                HStack {
                    Spacer(minLength: 0)
                    ShareLink(item: "Listening to \(player.track.title) — \(player.track.artist)") {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share current track")
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 8)

            PlaybackScrubber(player: player)

            // Match the original player action-button sizes shown in the reference.
            TransportControls(player: player, compact: true)
                .padding(.top, 5)

            ProfileAddButton(player: player)
                .padding(.top, 15)
        }
    }
}
