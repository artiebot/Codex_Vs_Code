//
//  SkyFeederFieldUtilityApp.swift
//  SkyFeederFieldUtility
//
//  Created for A1.3 scaffolding. Real functionality will be added in subsequent milestones.
//

import SwiftUI

@main
struct SkyFeederFieldUtilityApp: App {
    @StateObject private var applicationRouter = ApplicationRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(applicationRouter)
        }
    }
}
