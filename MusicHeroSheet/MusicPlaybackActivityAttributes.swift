import ActivityKit
import Foundation

struct MusicPlaybackActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isPlaying: Bool
    }

    var title: String
    var artist: String
    var artworkName: String
}
