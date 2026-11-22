import Foundation

struct DemoTrack: Identifiable, Equatable {
    let id: Int
    let title: String
    let detail: String
    let artist: String
    let listedDuration: String?
    let imageName: String?
    let audioFileName: String

    static let examples: [Self] = [
      
        .init(id: 9, title: "Flower In A Hurricane", detail: "3:45 · Justice", artist: "Justice", listedDuration: "3:45", imageName: "music-cover-9", audioFileName: "Justice - Flower In A Hurricane (ft Tame Impala, SZA, King Gizzard & the Lizard Wizard) [from GTAVI] - Justice.mp3"),
        .init(id: 0, title: "Veraldar Vættir", detail: "4:16 · Frosty Ida", artist: "Frosty Ida", listedDuration: "4:16", imageName: "track-0", audioFileName: "track-0.m4a"),
        .init(id: 1, title: "Wolf Totem", detail: "5:25 · The HU", artist: "The HU", listedDuration: "5:25", imageName: "track-1", audioFileName: "track-1.m4a"),
        .init(id: 2, title: "Трек из music", detail: "3:48 · Unknown Artist", artist: "Unknown Artist", listedDuration: "3:48", imageName: "track-2", audioFileName: "track-2.mp3"),
        .init(id: 3, title: "Свой Живой Интернет", detail: "3:22 · durikovich", artist: "durikovich", listedDuration: "3:22", imageName: "track-3", audioFileName: "track-3.mp3"),
        .init(id: 4, title: "Skål! Viking Drinking Song", detail: "3:00 · Nordic Folk", artist: "Nordic Folk", listedDuration: "3:00", imageName: "track-4", audioFileName: "track-4.m4a"),
        .init(id: 5, title: "Success", detail: "13:21 · Jim Rohn", artist: "Jim Rohn", listedDuration: "13:21", imageName: "track-5", audioFileName: "track-5.mp3"),
        .init(id: 6, title: "Эх ВПНы Верные", detail: "3:13 · durikovich", artist: "durikovich", listedDuration: "3:13", imageName: "track-6", audioFileName: "track-6.mp3"),
        .init(id: 7, title: "Wild Hunt", detail: "3:49 · Unknown Artist", artist: "Unknown Artist", listedDuration: "3:49", imageName: "track-7", audioFileName: "track-7.m4a"),
//        .init(id: 10, title: "6AM в Будапеште", detail: "3:34 · OG Buda", artist: "OG Buda", listedDuration: "3:34", imageName: "music-cover-10", audioFileName: "OG Buda   6AM в Будапеште slowed + reverb - flosssy.mp3"),
//        .init(id: 11, title: "PSYCHO!", detail: "2:34 · 666SWISH", artist: "666SWISH", listedDuration: "2:34", imageName: "music-cover-11", audioFileName: "PSYCHO! - 666SWISH.mp3"),
//        .init(id: 12, title: "Round 2", detail: "2:08 · JaeyBxrd", artist: "JaeyBxrd", listedDuration: "2:08", imageName: "music-cover-12", audioFileName: "Round 2 - JaeyBxrd.mp3"),
//        .init(id: 13, title: "UGU", detail: "2:37 · MORGENSHTERN", artist: "MORGENSHTERN", listedDuration: "2:37", imageName: "music-cover-13", audioFileName: "UGU - MORGENSHTERN.mp3"),
//        .init(id: 14, title: "Бассок", detail: "3:17 · Платина", artist: "Платина", listedDuration: "3:17", imageName: "music-cover-14", audioFileName: "Бассок (feat. Voskresenskii) - Платина.mp3"),
//        .init(id: 15, title: "ДИНАСТИЯ", detail: "2:31 · VILLIAN", artist: "VILLIAN", listedDuration: "2:31", imageName: "music-cover-15", audioFileName: "ДИНАСТИЯ - VILLIAN.mp3"),
//        .init(id: 8, title: "Broke Day", detail: "4:07 · Big Baby Tape", artist: "Big Baby Tape", listedDuration: "4:07", imageName: "music-cover-8", audioFileName: "Broke Day - Big Baby Tape.mp3"),
    ]
}
