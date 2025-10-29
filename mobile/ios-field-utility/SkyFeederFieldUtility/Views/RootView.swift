import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: ApplicationRouter

    var body: some View {
        switch router.destination {
        case .gallery:
            GalleryPlaceholderView()
        case .placeholder:
            GalleryPlaceholderView()
        }
    }
}

struct GalleryPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(.secondary)
            Text("SkyFeeder Field Utility")
                .font(.title3.weight(.semibold))
            Text("SwiftUI scaffolding ready. Upcoming milestones will replace this placeholder with the full gallery, detail, and settings experience.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}
