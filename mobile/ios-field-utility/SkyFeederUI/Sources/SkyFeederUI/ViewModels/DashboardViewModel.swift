import Foundation
import Combine
import SwiftUI
import UIKit

@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var isOffline = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var lastUpdated: Date?
    @Published public private(set) var weightCard: WeightCardState = .placeholder
    @Published public private(set) var visitCard: VisitStatusCardState = .placeholder
    @Published public private(set) var actionBanner: String?
    @Published public private(set) var healthSnapshot: HealthSnapshot?

    private let settingsStore: SettingsStore
    private let healthProvider: HealthProvider
    private let actionProvider: DashboardActionProvider
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?

    public init(
        settingsStore: SettingsStore,
        healthProvider: HealthProvider = HealthProvider(),
        actionProvider: DashboardActionProvider = DashboardActionProvider()
    ) {
        self.settingsStore = settingsStore
        self.healthProvider = healthProvider
        self.actionProvider = actionProvider

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
    }

    deinit {
        refreshTask?.cancel()
    }

    public func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !(Task.isCancelled) {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    public func refresh() async {
        guard let apiBase = settingsStore.state.apiBaseURL else {
            isOffline = true
            errorMessage = HealthProviderError.missingAPIBase.errorDescription
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let snapshot = try await healthProvider.fetchSnapshot(
                baseURL: apiBase,
                deviceId: settingsStore.state.deviceID
            )
            apply(snapshot: snapshot)
            isOffline = false
            lastUpdated = Date()
        } catch {
            if let healthError = error as? LocalizedError {
                errorMessage = healthError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            if shouldMarkOffline(error) {
                isOffline = true
            }
        }
        isLoading = false
    }

    public func triggerManualVisit() async {
        await perform(action: .manualTrigger, successMessage: "Manual trigger sent.")
    }

    public func takeSnapshot() async {
        await perform(action: .snapshot, successMessage: "Snapshot requested.")
    }

    private func perform(action: DashboardAction, successMessage: String) async {
        guard let apiBase = settingsStore.state.apiBaseURL else {
            actionBanner = DashboardActionError.missingAPIBase.errorDescription
            return
        }
        do {
            _ = try await actionProvider.perform(
                action: action,
                baseURL: apiBase,
                deviceId: settingsStore.state.deviceID
            )
            actionBanner = successMessage
            await refresh()
            dismissBannerAfterDelay()
        } catch {
            if let actionError = error as? LocalizedError {
                actionBanner = actionError.errorDescription
            } else {
                actionBanner = error.localizedDescription
            }
            dismissBannerAfterDelay()
        }
    }

    private func dismissBannerAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            withAnimation {
                actionBanner = nil
            }
        }
    }

    private func apply(snapshot: HealthSnapshot) {
        self.healthSnapshot = snapshot

        weightCard = WeightCardState(
            currentGrams: snapshot.weightMetrics.currentGrams,
            rollingAverageGrams: snapshot.weightMetrics.rollingAverageGrams,
            visitsToday: snapshot.weightMetrics.visitsToday ?? 0,
            lastEventDate: snapshot.weightMetrics.lastEventTs
        )

        let presence: VisitStatusCardState.Presence
        if (snapshot.weightMetrics.visitsToday ?? 0) > 0 {
            presence = .present
        } else if snapshot.visitMetrics.today ?? 0 > 0 {
            presence = .present
        } else {
            presence = .absent
        }

        visitCard = VisitStatusCardState(
            presence: presence,
            lastEvent: snapshot.visitMetrics.lastEventTs ?? snapshot.weightMetrics.lastEventTs,
            actionStatus: visitCard.actionStatus
        )
    }

    private func shouldMarkOffline(_ error: Error) -> Bool {
        if error is URLError {
            return true
        }
        if let healthError = error as? HealthProviderError,
           case .missingAPIBase = healthError {
            return true
        }
        return false
    }
}
