import Combine
import SwiftUI

@MainActor
final class ProductListViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func loadProducts() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            products = try await ProductAPIService.fetchProducts()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct ProductListView: View {
    @EnvironmentObject private var router: AppDeepLinkRouter
    @StateObject private var viewModel = ProductListViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.isLoading, viewModel.products.isEmpty {
                    ProgressView("Loading products…")
                } else if let errorMessage = viewModel.errorMessage, viewModel.products.isEmpty {
                    ContentUnavailableView {
                        Label("Could Not Load", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadProducts() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(viewModel.products) { product in
                        NavigationLink(value: product.id) {
                            ProductRow(product: product)
                        }
                    }
                    .refreshable {
                        await viewModel.loadProducts()
                    }
                }
            }
            .navigationTitle("Products")
            .navigationDestination(for: Int.self) { productID in
                ProductDetailView(productID: productID)
            }
            .task {
                if viewModel.products.isEmpty {
                    await viewModel.loadProducts()
                }
            }
            .onAppear {
                openPendingProductIfNeeded()
            }
            .onChange(of: router.pendingProductID) { _, _ in
                openPendingProductIfNeeded()
            }
        }
    }

    private func openPendingProductIfNeeded() {
        guard let productID = router.pendingProductID else { return }
        navigationPath.append(productID)
        router.clearPendingProduct()
    }
}

private struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: product.image)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                default:
                    ProgressView()
                }
            }
            .frame(width: 56, height: 56)
            .background(.quaternary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(product.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(product.category.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("$\(product.price, specifier: "%.2f")")
                        .font(.caption.bold())
                    Label(
                        String(format: "%.1f", product.rating.rate),
                        systemImage: "star.fill"
                    )
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProductListView()
        .environmentObject(AppDeepLinkRouter())
}
