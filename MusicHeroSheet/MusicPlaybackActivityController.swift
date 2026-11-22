import ActivityKit
import Foundation

@MainActor
enum MusicPlaybackActivityController {
    private static var activity: Activity<MusicPlaybackActivityAttributes>? {
        Activity<MusicPlaybackActivityAttributes>.activities.first
    }

    static func sync(track: DemoTrack, isPlaying: Bool, startIfNeeded: Bool) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = MusicPlaybackActivityAttributes(
            title: track.title,
            artist: track.artist,
            artworkName: track.imageName ?? "music.note"
        )
        let state = MusicPlaybackActivityAttributes.ContentState(isPlaying: isPlaying)

        if let current = activity {
            if current.attributes.title == track.title,
               current.attributes.artist == track.artist,
               current.attributes.artworkName == attributes.artworkName {
                await current.update(ActivityContent(state: state, staleDate: nil))
                return
            }

            await current.end(nil, dismissalPolicy: .immediate)
        } else if !startIfNeeded {
            return
        }

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Could not start music Live Activity: \(error)")
        }
    }
}
