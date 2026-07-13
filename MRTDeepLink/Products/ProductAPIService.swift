import Foundation

enum ProductAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Server returned an unexpected response."
        case .decodingFailed:
            return "Could not read product data."
        }
    }
}

enum ProductAPIService {
    static func fetchProducts() async throws -> [Product] {
        try await decode([Product].self, from: "\(AppConfig.appApiURL)/products")
    }

    static func fetchProduct(id: Int) async throws -> Product {
        try await decode(Product.self, from: productURL(id: id))
    }

    static func productURL(id: Int) -> String {
        "\(AppConfig.appApiURL)/products/\(id)"
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        from urlString: String
    ) async throws -> T {
        // API disabled
        throw ProductAPIError.invalidResponse
    }
}
