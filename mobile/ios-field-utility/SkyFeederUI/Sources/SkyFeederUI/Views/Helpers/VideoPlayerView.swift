import SwiftUI
import AVKit

public struct VideoPlayerView: View {
    let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public var body: some View {
        VideoPlayer(player: AVPlayer(url: url))
            .edgesIgnoringSafeArea(.all)
    }
}
