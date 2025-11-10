import SwiftUI
import UIKit

public enum AppTheme {
    public static func apply() {
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithDefaultBackground()
        navigationAppearance.backgroundColor = AppColors.backgroundUIColor
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]

        UINavigationBar.appearance().tintColor = AppColors.accentUIColor
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance

        UIToolbar.appearance().tintColor = AppColors.accentUIColor
        UIButton.appearance(whenContainedInInstancesOf: [UINavigationBar.self]).tintColor = AppColors.accentUIColor
    }
}
