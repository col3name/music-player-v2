import SwiftUI

struct ArtworkView: View {
    let track: DemoTrack
    let cornerRadius: CGFloat

    private var fallbackColors: [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.15, green: 0.27, blue: 0.48), Color(red: 0.48, green: 0.25, blue: 0.48)],
            [Color(red: 0.10, green: 0.38, blue: 0.35), Color(red: 0.06, green: 0.16, blue: 0.24)],
            [Color(red: 0.55, green: 0.22, blue: 0.25), Color(red: 0.18, green: 0.12, blue: 0.23)],
            [Color(red: 0.75, green: 0.40, blue: 0.14), Color(red: 0.30, green: 0.15, blue: 0.14)]
        ]
        return palettes[track.id % palettes.count]
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let name = track.imageName {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: fallbackColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        Circle()
                            .stroke(.white.opacity(0.13), lineWidth: max(1, geometry.size.width * 0.012))
                            .frame(width: geometry.size.width * 0.8)
                            .offset(x: geometry.size.width * 0.36, y: -geometry.size.height * 0.32)
                        Circle()
                            .stroke(.white.opacity(0.1), lineWidth: max(1, geometry.size.width * 0.012))
                            .frame(width: geometry.size.width * 0.56)
                            .offset(x: geometry.size.width * 0.48, y: -geometry.size.height * 0.45)
                        VStack(alignment: .leading, spacing: geometry.size.width * 0.025) {
                            Text(track.artist.uppercased())
                                .font(.system(size: max(6, geometry.size.width * 0.035), weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)
                            Text(track.title)
                                .font(.system(size: max(12, geometry.size.width * 0.09), weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(3)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(geometry.size.width * 0.085)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .accessibilityLabel("Artwork for \(track.title)")
    }
}
