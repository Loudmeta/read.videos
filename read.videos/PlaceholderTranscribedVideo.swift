import Foundation

struct PlaceholderTranscribedVideo: Identifiable {
    let id = UUID()
    let title: String
    let imageURL: URL
    let previewText: String
}

extension PlaceholderTranscribedVideo {
    static let placeholders: [PlaceholderTranscribedVideo] = [
        PlaceholderTranscribedVideo(
            title: "Nature Documentary",
            imageURL: URL(string: "https://picsum.photos/seed/nature/200")!,
            previewText: "Explore the wonders of nature in this captivating..."
        ),
        PlaceholderTranscribedVideo(
            title: "Tech Talk",
            imageURL: URL(string: "https://picsum.photos/seed/tech/200")!,
            previewText: "Discover the latest innovations in technology and..."
        ),
        PlaceholderTranscribedVideo(
            title: "Cooking Show",
            imageURL: URL(string: "https://picsum.photos/seed/cooking/200")!,
            previewText: "Learn to cook delicious meals with our expert chef..."
        ),
        PlaceholderTranscribedVideo(
            title: "Travel Vlog",
            imageURL: URL(string: "https://picsum.photos/seed/travel/200")!,
            previewText: "Join us on an adventure around the world as we..."
        ),
        PlaceholderTranscribedVideo(
            title: "Fitness Workout",
            imageURL: URL(string: "https://picsum.photos/seed/fitness/200")!,
            previewText: "Get in shape with our high-intensity workout routine..."
        ),
        PlaceholderTranscribedVideo(
            title: "Music Performance",
            imageURL: URL(string: "https://picsum.photos/seed/music/200")!,
            previewText: "Experience the magic of live music with this stunning..."
        ),
        PlaceholderTranscribedVideo(
            title: "Art Tutorial",
            imageURL: URL(string: "https://picsum.photos/seed/art/200")!,
            previewText: "Learn the basics of painting and unleash your creativity..."
        ),
        PlaceholderTranscribedVideo(
            title: "Science Experiment",
            imageURL: URL(string: "https://picsum.photos/seed/science/200")!,
            previewText: "Witness amazing scientific phenomena in this educational..."
        )
    ]
}