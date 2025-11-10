import SwiftUI

struct MediaCarouselView: View {
    let title: String
    let icon: String
    @ObservedObject var viewModel: MediaCarouselViewModel

    var body: some View {
        DashboardCardContainer(title: title, icon: icon) {
            VStack(alignment: .leading, spacing: 12) {
                if !viewModel.items.isEmpty {
                    Text("\(viewModel.items.count) shown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                } else if viewModel.items.isEmpty {
                    Text("No items yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.items) { item in
                                MediaThumbnail(item: item)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
        .task {
            await viewModel.refresh()
        }
    }
}

private struct MediaThumbnail: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: item.url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        Color(.tertiarySystemFill)
                        Image(systemName: "photo")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                    }
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 140, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(item.filename)
                .font(.footnote)
                .lineLimit(1)
        }
        .frame(width: 140, alignment: .leading)
    }
}
