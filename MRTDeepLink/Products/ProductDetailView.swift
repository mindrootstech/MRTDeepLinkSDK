import Combine
import SwiftUI

@MainActor
final class ProductDetailViewModel: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func loadProduct(id: Int) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            product = try await ProductAPIService.fetchProduct(id: id)
            if let product {
                let url = ProductAPIService.productURL(id: product.id)
                print("══════════════════════════════════════")
                print("🛍️ PRODUCT DETAIL")
                print("══════════════════════════════════════")
                print("ID:  \(product.id)")
                print("URL: \(url)")
                print("══════════════════════════════════════")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct ProductDetailView: View {
    let productID: Int

    @StateObject private var viewModel = ProductDetailViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading, viewModel.product == nil {
                ProgressView("Loading details…")
            } else if let errorMessage = viewModel.errorMessage, viewModel.product == nil {
                ContentUnavailableView {
                    Label("Product Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") {
                        Task { await viewModel.loadProduct(id: productID) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let product = viewModel.product {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        AsyncImage(url: URL(string: product.image)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            case .failure:
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 220)
                            default:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 220)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.quaternary.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        VStack(alignment: .leading, spacing: 12) {
                            Text(product.title)
                                .font(.title2.bold())

                            HStack {
                                Text("$\(product.price, specifier: "%.2f")")
                                    .font(.title3.bold())
                                    .foregroundStyle(.green)

                                Spacer()

                                Label(
                                    "\(String(format: "%.1f", product.rating.rate)) (\(product.rating.count))",
                                    systemImage: "star.fill"
                                )
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                            }

                            Text(product.category.capitalized)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Product Info")
                                    .font(.headline)

                                detailRow(label: "ID", value: "\(product.id)")
                                detailRow(
                                    label: "FakeStore API",
                                    value: ProductAPIService.productURL(id: product.id)
                                )
                                if let shareURL = AppConfig.productShareURL(productID: product.id) {
                                    detailRow(label: "Share link", value: shareURL.absoluteString)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            if let shareURL = AppConfig.productShareURL(productID: product.id) {
                                ShareLink(item: shareURL) {
                                    Label("Share Product Deep Link", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            Text("Description")
                                .font(.headline)

                            Text(product.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Product #\(productID)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: productID) {
            await viewModel.loadProduct(id: productID)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(productID: 1)
    }
}
