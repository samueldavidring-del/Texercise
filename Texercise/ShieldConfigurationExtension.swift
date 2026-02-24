import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "figure.run.circle.fill"),
            title: ShieldConfiguration.Label(
                text: "Time to Move! 💪",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This app is restricted until you earn more points in Texercise.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Texercise",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Dismiss",
                color: .systemBlue
            )
        )
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "figure.run.circle.fill"),
            title: ShieldConfiguration.Label(
                text: "Time to Move! 💪",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Apps in this category are restricted until you earn more points in Texercise.",
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Open Texercise",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemBlue,
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "Dismiss",
                color: .systemBlue
            )
        )
    }
}
