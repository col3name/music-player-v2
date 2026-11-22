import SwiftUI
import Combine
import UIKit

private enum ArtworkGestureAxis: Equatable {
    case horizontal
    case vertical
}

struct MiniArtworkFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct MiniTitleFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct FullArtworkFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// The compact and expanded layouts remain mounted together. A single overlay interpolates
/// the poster and track identity between their measured frames, so the transition can track a drag.
struct MusicSheetScene: View {
    @StateObject private var player = AudioPlaybackManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expansionProgress: CGFloat = 0
    @State private var isSheetVisible = true
    @State private var miniArtworkFrame: CGRect = .zero
    @State private var fullArtworkFrame: CGRect = .zero
    @State private var miniTitleFrame: CGRect = .zero
    @State private var isTopRowDragging = false
    @State private var artworkGestureAxis: ArtworkGestureAxis?
    @State private var artworkGestureStartProgress: CGFloat = 1
    @State private var artworkDragX: CGFloat = 0
    @State private var isArtworkSwipeSettling = false
    @State private var posterAmbientColors: [Color] = []
    @State private var posterPulse = false

    private var isExpanded: Bool { expansionProgress > 0.5 }

    private var currentPosterAmbientColors: [Color] {
        posterAmbientColors.count >= 3
            ? posterAmbientColors
            : [Color(red: 0.34, green: 0.22, blue: 0.20),
               Color(red: 0.70, green: 0.44, blue: 0.35),
               Color(red: 0.24, green: 0.19, blue: 0.18)]
    }

    private var heroAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.86)
    }

    var body: some View {
        GeometryReader { geometry in
            let ambientColors = currentPosterAmbientColors
            let darkPoster = paletteIsDark(ambientColors)
            let gradientLightening: [CGFloat] = darkPoster
                ? [0.02, 0.03, 0.04, 0.06, 0.08, 0.10]
                : [0.18, 0.22, 0.28, 0.34, 0.38, 0.42]
            ZStack {
                BaseSceneView(openSheet: {
                    withAnimation(heroAnimation) { isSheetVisible = true }
                })

                if isSheetVisible {
                    librarySheet(sceneHeight: geometry.size.height)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        // The library's rounded card remains behind the player
                        // during expansion; fade the entire sheet out with it.
                        .opacity(1 - expansionProgress)
                        .allowsHitTesting(expansionProgress < 0.98)
                        .transition(.move(edge: .bottom))
                }

                LinearGradient(stops: [
                    .init(color: blended(ambientColors[0], toward: .white, amount: gradientLightening[0]), location: 0),
                    .init(color: blended(ambientColors[1], toward: .white, amount: gradientLightening[1]), location: 0.30),
                    .init(color: blended(ambientColors[2], toward: .white, amount: gradientLightening[2]), location: 0.56),
                    .init(color: blended(ambientColors[2], toward: .white, amount: gradientLightening[3]), location: 0.73),
                    .init(color: blended(ambientColors[1], toward: .white, amount: gradientLightening[4]), location: 0.88),
                    .init(color: blended(ambientColors[0], toward: .white, amount: gradientLightening[5]), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .blur(radius: 16)
                .ignoresSafeArea()
                .opacity(expansionProgress)
                .allowsHitTesting(false)

                ExpandedPlayerView(
                    player: player,
                    progress: $expansionProgress,
                    settle: settleExpansion
                )
                // This view supplies the expanded poster's destination frame.
                // Keep its chrome hidden; the library and mini-player stay put.
                .opacity(0)
                .allowsHitTesting(false)
                .zIndex(1)

                if isSheetVisible {
                    MiniPlayerPanel(
                        player: player,
                        expand: { expand(initialVelocity: $0) },
                        progress: $expansionProgress,
                        isTopRowDragging: $isTopRowDragging,
                        settle: settleExpansion,
                        travelDistance: geometry.size.height * 0.72,
                        // The collapsed sheet has a white surface regardless
                        // of the selected artwork, so keep its controls dark.
                        darkAppearance: darkPoster && expansionProgress > 0.5
                    )
                    .animation(.easeInOut(duration: 0.24), value: darkPoster && expansionProgress > 0.5)
                    .background {
                        // Reveal the scene-wide poster gradient through the
                        // controls area as the player expands.
                        Color.white.opacity(1 - expansionProgress)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .allowsHitTesting(true)
                    // In the collapsed state the interpolated poster and title
                    // must sit above the panel's white background. Once expanded,
                    // keep the panel above the artwork so controls remain tappable.
                    .zIndex(expansionProgress > 0.5 ? 4 : 2)
                }

                heroElements(sceneSize: geometry.size)
                    .zIndex(3)
            }
            .coordinateSpace(name: "musicScene")
            .onPreferenceChange(MiniArtworkFrameKey.self) { miniArtworkFrame = $0 }
            .onPreferenceChange(MiniTitleFrameKey.self) { miniTitleFrame = $0 }
            .onPreferenceChange(FullArtworkFrameKey.self) { fullArtworkFrame = $0 }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
            player.tick()
        }
        .onAppear { updatePosterAmbientColors() }
        .onChange(of: player.track.id) { _, _ in updatePosterAmbientColors() }
        .onChange(of: player.isPlaying) { _, isPlaying in
            guard !reduceMotion else {
                posterPulse = false
                return
            }
            if isPlaying {
                // A subtle 2 pt expansion and return take 400 ms total.
                withAnimation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true)) {
                    posterPulse = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.35)) {
                    posterPulse = false
                }
            }
        }
        .sensoryFeedback(.selection, trigger: isExpanded)
        .onOpenURL { url in
            guard url.scheme == "musichero" else { return }
            switch url.host {
            case "play":
                if !player.isPlaying { player.togglePlayback() }
            case "pause":
                if player.isPlaying { player.togglePlayback() }
            case "previous":
                player.previous()
            case "next":
                player.next()
            default:
                break
            }
        }
    }

    private func expand(initialVelocity: CGFloat = 0) {
        settleExpansion(1, initialVelocity)
    }

    private func updatePosterAmbientColors() {
        withAnimation(.easeInOut(duration: 0.55)) {
            posterAmbientColors = PosterColorPalette.colors(for: player.track)
        }
    }

    private func blended(_ color: Color, toward target: Color, amount: CGFloat) -> Color {
        let source = UIColor(color)
        let destination = UIColor(target)
        var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
        var dr: CGFloat = 0, dg: CGFloat = 0, db: CGFloat = 0, da: CGFloat = 0
        guard source.getRed(&sr, green: &sg, blue: &sb, alpha: &sa),
              destination.getRed(&dr, green: &dg, blue: &db, alpha: &da) else {
            return color
        }
        let t = min(1, max(0, amount))
        return Color(
            red: Double(sr + (dr - sr) * t),
            green: Double(sg + (dg - sg) * t),
            blue: Double(sb + (db - sb) * t),
            opacity: Double(sa + (da - sa) * t)
        )
    }

    private func paletteIsDark(_ colors: [Color]) -> Bool {
        let luminances = colors.map { color -> CGFloat in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
                return 1
            }
            return 0.2126 * red + 0.7152 * green + 0.0722 * blue
        }
        return luminances.reduce(0, +) / CGFloat(max(1, luminances.count)) < 0.32
    }

    private func settleExpansion(_ target: CGFloat, _ velocity: CGFloat) {
        withAnimation(heroAnimation(initialVelocity: velocity)) {
            isTopRowDragging = false
            expansionProgress = target
        }
    }

    private func heroAnimation(initialVelocity: CGFloat) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.15)
            : .interpolatingSpring(mass: 1, stiffness: 300, damping: 28.5,
                                   initialVelocity: initialVelocity)
    }

    private func librarySheet(sceneHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.09))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 33, alignment: .top)
                .padding(.top, 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 12).onEnded { value in
                        if value.translation.height > 130 {
                            withAnimation(heroAnimation) { isSheetVisible = false }
                        }
                    }
                )
                .accessibilityLabel("Drag down to dismiss music library")

            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(DemoTrack.examples) { track in
                        TrackRow(track: track, selected: player.track.id == track.id) {
                            player.select(track)
                        }
                        if track.id != DemoTrack.examples.last?.id {
                            Divider()
                                .padding(.leading, 63)
                                .padding(.trailing, 15)
                        }
                    }
                }
                .padding(.vertical, 1)
                .background(.white, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
                .padding(.horizontal, 15)
                .padding(.top, 0)
                // The list scrolls behind the fixed mini-player. Keep enough
                // trailing content inset for the final row to clear its controls.
                .padding(.bottom, 300)
            }
            // Fill the sheet's available height; a fixed height here stopped the
            // scroll viewport well above the bottom on tall devices.
            .frame(maxHeight: .infinity)
            .scrollIndicators(.visible)
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.top)
        }
        .frame(height: sceneHeight - 46)
        .background(Color(red: 0.944, green: 0.945, blue: 0.962))
        .overlay(alignment: .bottom) {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: currentPosterAmbientColors[1].opacity(0.72), location: 0.48),
                .init(color: currentPosterAmbientColors[2], location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .frame(height: 190)
            .opacity(expansionProgress)
            .allowsHitTesting(false)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 44 * (1 - expansionProgress),
                                          bottomLeadingRadius: 0,
                                          bottomTrailingRadius: 0,
                                          topTrailingRadius: 44 * (1 - expansionProgress)))
    }

    private func heroElements(sceneSize: CGSize) -> some View {
        GeometryReader { _ in
            // Leave room for the swipe scale while keeping the expanded poster
            // visibly 20 pt smaller at rest. Layout and controls stay put.
            let coverSize = min(sceneSize.width - 48, 355) - 60
            let sourceArtwork = miniArtworkFrame.width > 0
                ? miniArtworkFrame
                : CGRect(x: 16, y: sceneSize.height - 260, width: 45, height: 45)
            let destinationArtwork = fullArtworkFrame.width > 0
                ? fullArtworkFrame.insetBy(dx: 30, dy: 30).offsetBy(dx: 0, dy: -25)
                : CGRect(x: (sceneSize.width - coverSize) / 2,
                         y: sceneSize.height * 0.22 - 25,
                         width: coverSize, height: coverSize)
            let interpolatedArtworkFrame = interpolate(sourceArtwork, destinationArtwork, expansionProgress)
            // During the upward swipe, move the cover with the transition while
            // keeping its compact-player dimensions unchanged under the finger.
            let artworkFrame = isTopRowDragging
                ? CGRect(x: interpolatedArtworkFrame.midX - sourceArtwork.width / 2,
                         y: interpolatedArtworkFrame.midY - sourceArtwork.height / 2,
                         width: sourceArtwork.width,
                         height: sourceArtwork.height)
                : interpolatedArtworkFrame
            let titleSource = miniTitleFrame.width > 0
                ? miniTitleFrame
                : CGRect(x: 72, y: sceneSize.height - 259, width: 150, height: 40)
            let titleFrame = CGRect(
                x: titleSource.minX + 52 * expansionProgress,
                y: titleSource.minY,
                width: titleSource.width,
                height: titleSource.height
            )
            let p = expansionProgress
            // Add a small scale transform on top of the frame interpolation so
            // the poster visibly grows with the finger during an upward drag.
            let swipeScale = 1 + 0.06 * p
            let ambientColors = posterAmbientColors.isEmpty
                ? [Color(red: 0.34, green: 0.22, blue: 0.20), Color(red: 0.70, green: 0.44, blue: 0.35), Color(red: 0.24, green: 0.19, blue: 0.18)]
                : posterAmbientColors
            let darkPoster = paletteIsDark(ambientColors)
            let darkAppearance = darkPoster && p > 0.5
            let trackIndex = DemoTrack.examples.firstIndex(of: player.track) ?? 0
            let draggedDirection: ArtworkSlideDirection? = artworkDragX < 0 ? .next : (artworkDragX > 0 ? .previous : nil)
            let previewTrack: DemoTrack? = {
                switch draggedDirection {
                case .some(.next) where trackIndex + 1 < DemoTrack.examples.count:
                    return DemoTrack.examples[trackIndex + 1]
                case .some(.previous) where trackIndex > 0:
                    return DemoTrack.examples[trackIndex - 1]
                default:
                    return nil
                }
            }()
            let dragLimit = max(1, artworkFrame.width)
            let posterSpacing: CGFloat = 18
            let posterTravel = dragLimit + posterSpacing
            let resistedDrag = previewTrack == nil ? artworkDragX * 0.22 : artworkDragX
            let outgoingSwipeProgress = min(1, max(0, abs(artworkDragX) / posterTravel))
            let easedOutgoingProgress = 1 - pow(1 - outgoingSwipeProgress, 3)
            let outgoingPosterScale = 1 - 0.08 * easedOutgoingProgress
            let slideTransition: AnyTransition = {
                guard p > 0.5, let direction = player.artworkSlideDirection else { return .identity }
                let travel = sceneSize.width + artworkFrame.width
                let incomingOffset = direction.sign * travel
                return .asymmetric(
                    insertion: .offset(x: incomingOffset),
                    removal: .offset(x: -incomingOffset)
                )
            }()

            ZStack(alignment: .topLeading) {
                if artworkFrame.width > 0, artworkFrame.height > 0 {
                    if let previewTrack, abs(artworkDragX) > 0 {
                        let previewCenterX = artworkFrame.midX
                            + (artworkDragX < 0 ? posterTravel : -posterTravel)
                            + artworkDragX
                        let approachProgress = min(1, max(0,
                            1 - abs(previewCenterX - artworkFrame.midX) / posterTravel
                        ))
                        let easedApproachProgress = 1 - pow(1 - approachProgress, 3)
                        // Let the incoming cover grow from a clearly smaller
                        // size as it slides in, reaching the current cover's
                        // exact scale when it arrives at the center.
                        let previewScale = 0.92 + 0.08 * easedApproachProgress
                        let previewBlur = 3.5 * (1 - approachProgress)
                        let previewOpacity = 0.58 + 0.42 * approachProgress
                        ArtworkView(track: previewTrack, cornerRadius: 6)
                            .frame(width: artworkFrame.width, height: artworkFrame.height)
                            .scaleEffect(previewScale)
                            .blur(radius: previewBlur)
                            .opacity(previewOpacity)
                            .position(x: previewCenterX, y: artworkFrame.midY)
                            .zIndex(2)
                            .allowsHitTesting(false)
                    }
                    ZStack {
                        // Ambient color wash belongs to the poster layer, so it
                        // follows the cover without shifting the library or controls.
                        LinearGradient(stops: [
                            .init(color: ambientColors[0].opacity(0.78), location: 0),
                            .init(color: ambientColors[1].opacity(0.72), location: 0.42),
                            .init(color: ambientColors[2].opacity(0.48), location: 0.68),
                            .init(color: ambientColors[0].opacity(0.16), location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                            .frame(width: artworkFrame.width + 100, height: artworkFrame.height + 170)
                            .blur(radius: 46)
                            .offset(y: 68)
                            .opacity(p)
                            .allowsHitTesting(false)

                        // A softly enlarged copy lets the poster colors feather into
                        // the ambient backdrop instead of ending at a hard edge.
                        ArtworkView(track: player.track, cornerRadius: 10 + (6 - 10) * p)
                            .frame(width: artworkFrame.width, height: artworkFrame.height)
                            .scaleEffect(1.09)
                            .blur(radius: 24)
                            .opacity(0.72 * p)
                            .allowsHitTesting(false)

                        ArtworkView(track: player.track, cornerRadius: 10 + (6 - 10) * p)
                            .frame(width: artworkFrame.width, height: artworkFrame.height)
                    }
                        .frame(width: artworkFrame.width, height: artworkFrame.height)
                        .position(x: artworkFrame.midX + resistedDrag, y: artworkFrame.midY)
                        .zIndex(1)
                        // Scale after positioning so the transform is centered on
                        // the poster's on-screen bounds, not its layout origin.
                        .scaleEffect(
                            swipeScale
                                * outgoingPosterScale
                                * (player.isPlaying && posterPulse && p > 0.5
                                   ? 1 + 2 / max(1, min(artworkFrame.width, artworkFrame.height))
                                   : 1),
                            anchor: .center
                        )
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 18)
                                .onChanged { value in
                                    guard !isArtworkSwipeSettling else { return }
                                    if artworkGestureAxis == nil {
                                        artworkGestureStartProgress = expansionProgress
                                        artworkGestureAxis = abs(value.translation.width) > abs(value.translation.height)
                                            ? .horizontal
                                            : .vertical
                                    }

                                    if artworkGestureAxis == .vertical {
                                        let travelDistance = max(1, sceneSize.height * 0.72)
                                        let nextProgress = artworkGestureStartProgress
                                            - value.translation.height / travelDistance
                                        var transaction = Transaction()
                                        transaction.animation = nil
                                        withTransaction(transaction) {
                                            expansionProgress = min(1, max(0, nextProgress))
                                        }
                                    } else if artworkGestureAxis == .horizontal {
                                        let width = max(1, artworkFrame.width)
                                        let index = DemoTrack.examples.firstIndex(of: player.track) ?? 0
                                        let hasTrack = value.translation.width < 0
                                            ? index + 1 < DemoTrack.examples.count
                                            : index > 0
                                        let rawDrag = min(width * 1.15, max(-width * 1.15, value.translation.width))
                                        artworkDragX = hasTrack ? rawDrag : rawDrag * 0.22
                                    }
                                }
                                .onEnded { value in
                                    defer { artworkGestureAxis = nil }
                                    switch artworkGestureAxis {
                                    case .horizontal:
                                        let direction = value.predictedEndTranslation.width
                                        let index = DemoTrack.examples.firstIndex(of: player.track) ?? 0
                                        let canMove = direction < 0
                                            ? index + 1 < DemoTrack.examples.count
                                            : index > 0
                                        guard canMove, abs(direction) > max(55, artworkFrame.width * 0.2) else {
                                            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { artworkDragX = 0 }
                                            return
                                        }
                                        finishArtworkSwipe(direction: direction < 0 ? .next : .previous,
                                                           currentIndex: index,
                                                           travel: posterTravel)
                                    case .vertical:
                                        let travelDistance = max(1, sceneSize.height * 0.72)
                                        let projectedProgress = artworkGestureStartProgress
                                            - value.predictedEndTranslation.height / travelDistance
                                        let collapseProgress = max(0, min(1,
                                            value.translation.height / travelDistance
                                        ))
                                        let target: CGFloat = collapseProgress >= (1.0 / 3.0)
                                            || projectedProgress <= 0.5 ? 0 : 1
                                        let projectedVelocity = (value.predictedEndTranslation.height
                                            - value.translation.height) * 5
                                        let velocity = min(5, max(-5, -projectedVelocity / travelDistance))
                                        settleExpansion(target, velocity)
                                    case .none:
                                        break
                                        }
                                }
                        )
                        .allowsHitTesting(p > 0.5 || artworkGestureAxis != nil)
                        .id(player.track.id)
                        .transition(slideTransition)
                }

                if titleFrame.width > 0, titleFrame.height > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.track.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(darkAppearance ? .white : .black)
                            .lineLimit(1)
                        Text(player.track.artist)
                            .font(.system(size: 15))
                            .foregroundStyle(darkAppearance ? .white.opacity(0.78) : .black.opacity(0.72))
                            .lineLimit(1)
                    }
                    .frame(width: titleFrame.width, height: titleFrame.height, alignment: .leading)
                    .position(x: titleFrame.midX, y: titleFrame.midY)
                    .allowsHitTesting(false)
                }

            }
            .animation(.easeInOut(duration: 0.24), value: darkAppearance)
        }
    }

    private func finishArtworkSwipe(direction: ArtworkSlideDirection, currentIndex: Int, travel: CGFloat) {
        let nextIndex = direction == .next ? currentIndex + 1 : currentIndex - 1
        guard DemoTrack.examples.indices.contains(nextIndex) else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { artworkDragX = 0 }
            return
        }

        isArtworkSwipeSettling = true
        let targetOffset = direction == .next ? -travel : travel
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            artworkDragX = targetOffset
        } completion: {
            // The finger-driven preview has already brought the incoming cover
            // to the center. Switch track identity without starting a second
            // insertion transition, which can leave the new poster offset.
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                player.select(DemoTrack.examples[nextIndex],
                              autoPlay: player.isPlaying,
                              slideDirection: nil)
                artworkDragX = 0
            }
            isArtworkSwipeSettling = false
        }
    }

    private func interpolate(_ from: CGRect, _ to: CGRect, _ progress: CGFloat) -> CGRect {
        guard from.width > 0, to.width > 0 else { return .zero }
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * progress }
        return CGRect(x: lerp(from.minX, to.minX), y: lerp(from.minY, to.minY),
                      width: lerp(from.width, to.width), height: lerp(from.height, to.height))
    }
}

private struct TrackRow: View {
    let track: DemoTrack
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ArtworkView(track: track, cornerRadius: 22)
                    .frame(width: 42, height: 42)
                    .overlay {
                        if track.imageName == "Siopi" {
                            Image(systemName: "play.fill")
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.45), radius: 2)
                                .offset(x: 1)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Text(track.detail)
                        .font(.system(size: 14.2))
                        .foregroundStyle(Color(red: 0.57, green: 0.57, blue: 0.59))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 58)
            .padding(.horizontal, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(track.title), \(track.detail)")
        .accessibilityHint(selected ? "Currently selected. Tap to restart." : "Play this track")
    }
}

private struct MiniPlayerPanel: View {
    @ObservedObject var player: AudioPlaybackManager
    let expand: (CGFloat) -> Void
    @Binding var progress: CGFloat
    @Binding var isTopRowDragging: Bool
    let settle: (CGFloat, CGFloat) -> Void
    let travelDistance: CGFloat
    let darkAppearance: Bool
    @State private var dragStartProgress: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Button { expand(0) } label: {
                    ArtworkView(track: player.track, cornerRadius: 10)
                        .frame(width: 45, height: 45)
                        .opacity(0)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(key: MiniArtworkFrameKey.self,
                                                       value: proxy.frame(in: .named("musicScene")))
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityLabel("Expand current track artwork")
                .accessibilityHint("Opens full-screen player")

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.track.title)
                        .font(.system(size: 17, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(darkAppearance ? .white : .black)
                    Text(player.track.artist)
                        .font(.system(size: 15))
                        .lineLimit(1)
                        .foregroundStyle(darkAppearance ? .white.opacity(0.78) : .black.opacity(0.72))
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: MiniTitleFrameKey.self,
                                               value: proxy.frame(in: .named("musicScene")))
                    }
                }
                .opacity(0)
                Spacer(minLength: 8)
                ShareLink(item: "Listening to \(player.track.title) — \(player.track.artist)") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 23, weight: .regular))
                        .frame(width: 44, height: 48)
                        .foregroundStyle(darkAppearance ? .white : .black)
                }
                .accessibilityLabel("Share current track")
            }
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 9)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        // Only an upward swipe on the highlighted top row expands the player.
                        guard value.translation.height < 0 || isDragging else { return }
                        if !isDragging {
                            isDragging = true
                            isTopRowDragging = true
                            dragStartProgress = progress
                        }
                        let next = dragStartProgress - value.translation.height / max(1, travelDistance)
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) { progress = min(1, max(0, next)) }
                    }
                    .onEnded { value in
                        guard isDragging else { return }
                        isDragging = false
                        let projectedVelocity = (value.predictedEndTranslation.height - value.translation.height) * 5
                        let projectedProgress = dragStartProgress - value.predictedEndTranslation.height / max(1, travelDistance)
                        // A short upward flick should open the player without needing to drag
                        // the sheet halfway across the screen.
                        let shortUpwardSwipe = value.translation.height < -28
                            || value.predictedEndTranslation.height < -85
                        let target: CGFloat = shortUpwardSwipe || projectedProgress > 0.5 ? 1 : 0
                        settle(target, min(5, max(-5, -projectedVelocity / max(1, travelDistance))))
                    }
            )

            PlaybackScrubber(player: player, darkAppearance: darkAppearance)
                .padding(.horizontal, 24)

            TransportControls(player: player, compact: true, darkAppearance: darkAppearance,
                              mutedSecondaryControls: true)
                .padding(.horizontal, 22)
                .padding(.top, 5)

            ProfileAddButton(player: player)
                .padding(.horizontal, 28)
                .padding(.top, 15)
                .padding(.bottom, 30)
        }
    }
}

private struct BaseSceneView: View {
    let openSheet: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.45, green: 0.56, blue: 0.41),
                                    Color(red: 0.78, green: 0.85, blue: 0.71)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 12) {
                Text("Music Profile")
                    .font(.system(size: 31, weight: .bold))
                Text("A collection of the songs you love")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Button("Open Music Library", action: openSheet)
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0, green: 0.53, blue: 1))
                    .padding(.top, 10)
            }
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .ignoresSafeArea()
    }
}
