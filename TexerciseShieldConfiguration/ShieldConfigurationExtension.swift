import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        shieldConfig()
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        shieldConfig()
    }
    
    private func shieldConfig() -> ShieldConfiguration {
        let points = UserDefaults(suiteName: "group.com.samring.texercise")?
            .integer(forKey: "sharedNetPoints") ?? 0
        let deficit = abs(min(points, 0))
        
        let subtitle = deficit > 0
            ? "You need \(deficit) more point\(deficit == 1 ? "" : "s") to unlock this app. Open Texercise to earn them."
            : "This app is restricted until you earn more points in Texercise."
        
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor.systemBackground,
            icon: UIImage(systemName: "figure.run.circle.fill"),
            title: ShieldConfiguration.Label(
                text: "Time to Move! 💪",
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Go to Home Screen",
                color: .white
            ),
            primaryButtonBackgroundColor: .systemBlue
        )
    }
}
