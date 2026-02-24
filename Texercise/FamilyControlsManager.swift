import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class FamilyControlsManager: ObservableObject {
    
    static let shared = FamilyControlsManager()
    
    @Published var isAuthorized = false
    @Published var authorizationError: String? = nil
    
    private init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        let status = AuthorizationCenter.shared.authorizationStatus
        isAuthorized = (status == .approved)
    }
    
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
            authorizationError = nil
            print("✅ FamilyControls authorization granted")
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
            print("❌ FamilyControls authorization failed: \(error.localizedDescription)")
        }
    }
    
    func revokeAuthorization() {
        AuthorizationCenter.shared.revokeAuthorization { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    self.isAuthorized = false
                    print("✅ FamilyControls authorization revoked")
                }
            case .failure(let error):
                print("❌ Failed to revoke authorization: \(error.localizedDescription)")
            }
        }
    }
}
