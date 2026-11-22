import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MusicHeroSheetWidgetBundle: WidgetBundle {
    var body: some Widget {
        MusicPlaybackLiveActivity()
    }
}

struct MusicPlaybackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MusicPlaybackActivityAttributes.self) { context in
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    artwork(context.attributes.artworkName, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.attributes.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                HStack(spacing: 34) {
                    actionLink("previous", symbol: "backward.end.fill", label: "Previous track")
                    actionLink(context.state.isPlaying ? "pause" : "play",
                               symbol: context.state.isPlaying ? "pause.fill" : "play.fill",
                               label: context.state.isPlaying ? "Pause" : "Play")
                    actionLink("next", symbol: "forward.end.fill", label: "Next track")
                }
                .font(.system(size: 18, weight: .semibold))
            }
            .padding(.vertical, 10)
            .activityBackgroundTint(Color(uiColor: .systemBackground))
            .activitySystemActionForegroundColor(.primary)
            .widgetURL(URL(string: "musichero://player"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    artwork(context.attributes.artworkName, size: 46)
                        .padding(.leading, 2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.attributes.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .symbolEffect(.variableColor.iterative, isActive: context.state.isPlaying)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        actionLink("previous", symbol: "backward.end.fill", label: "Previous track")
                        Spacer()
                        actionLink(context.state.isPlaying ? "pause" : "play",
                                   symbol: context.state.isPlaying ? "pause.fill" : "play.fill",
                                   label: context.state.isPlaying ? "Pause" : "Play")
                        Spacer()
                        actionLink("next", symbol: "forward.end.fill", label: "Next track")
                    }
                    .font(.system(size: 19, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.top, 14)
                }
            } compactLeading: {
                artwork(context.attributes.artworkName, size: 18)
            } compactTrailing: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolEffect(.variableColor.iterative, isActive: context.state.isPlaying)
            } minimal: {
                artwork(context.attributes.artworkName, size: 18)
            }
            .keylineTint(.blue)
            .widgetURL(URL(string: "musichero://player"))
        }
    }

    private func actionLink(_ command: String, symbol: String, label: String) -> some View {
        Link(destination: URL(string: "musichero://\(command)")!) {
            Image(systemName: symbol)
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }

    private func artwork(_ name: String, size: CGFloat) -> some View {
        Group {
            if name == "music.note" {
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.25)
                    .foregroundStyle(.secondary)
                    .background(Color(uiColor: .secondarySystemBackground))
            } else {
                Image(name)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
    }
}
