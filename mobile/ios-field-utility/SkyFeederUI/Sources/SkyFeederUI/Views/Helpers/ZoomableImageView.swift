import SwiftUI

public struct ZoomableImageView: View {
    let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
            @unknown default:
                EmptyView()
            }
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
}
