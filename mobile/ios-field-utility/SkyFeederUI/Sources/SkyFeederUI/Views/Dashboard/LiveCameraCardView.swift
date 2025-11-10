import SwiftUI

struct LiveCameraCardView: View {
    @ObservedObject var viewModel: LiveStreamViewModel

    var body: some View {
        DashboardCardContainer(title: "Live Camera", icon: "video") {
            VStack(alignment: .leading, spacing: 12) {
                LiveStreamView(viewModel: viewModel)
                    .frame(height: 180)

                if let status = viewModel.statusMessage {
                    Label(status, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .transition(.opacity)
                }

                Toggle(isOn: bindingForStreaming) {
                    Label("Keep stream active", systemImage: viewModel.isStreaming ? "pause.circle" : "play.circle")
                }
                .toggleStyle(.switch)
            }
        }
    }

    private var bindingForStreaming: Binding<Bool> {
        Binding(
            get: { viewModel.isStreaming },
            set: { newValue in
                if newValue {
                    viewModel.start()
                } else {
                    viewModel.stop()
                }
            }
        )
    }
}
