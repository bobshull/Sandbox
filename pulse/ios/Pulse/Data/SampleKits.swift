import Foundation

struct SampleKit {
    let id: String
    let name: String
}

enum SampleKits {
    static let all: [SampleKit] = [
        SampleKit(id: "studio",      name: "Studio"),
        SampleKit(id: "dusty-tape",  name: "Dusty Tape"),
        SampleKit(id: "boom-bap",    name: "Boom Bap"),
        SampleKit(id: "808",         name: "808"),
        SampleKit(id: "jazz",        name: "Jazz"),
        SampleKit(id: "rainy-night", name: "Rainy Night"),
        SampleKit(id: "music-box",   name: "Music Box"),
        SampleKit(id: "wind-chimes", name: "Wind Chimes"),
        SampleKit(id: "marimba",     name: "Marimba"),
        SampleKit(id: "arcade",      name: "Arcade"),
        SampleKit(id: "glass",       name: "Glass"),
        SampleKit(id: "toy-piano",   name: "Toy Piano"),
        SampleKit(id: "jungle",      name: "Jungle"),
        SampleKit(id: "space",       name: "Space"),
    ]

    static func find(_ id: String) -> SampleKit {
        all.first { $0.id == id } ?? all[0]
    }
}
