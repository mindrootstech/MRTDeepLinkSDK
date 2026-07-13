import Foundation

struct Product: Identifiable, Decodable, Hashable, Sendable {
    let id: Int
    let title: String
    let price: Double
    let description: String
    let category: String
    let image: String
    let rating: Rating

    struct Rating: Decodable, Hashable, Sendable {
        let rate: Double
        let count: Int
    }
}
