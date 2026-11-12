import Foundation
import Combine
import FamilyControls
import ManagedSettings

@MainActor
final class FamilyControlsManager: ObservableObject {

    static let shared = FamilyControlsManager()

    @Published var isAuthorized = false
    @Published var authorizationError: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let appGroup = "group.com.samring.texercise"

    /// iOS 26 reports a second approved state, "Approved with Data Access".
    /// The app only accepted `.approved`, so whenever iOS reported the other
    /// one the app thought access was gone: the Grant Access button kept
    /// coming back, and each false "regained access" kicked off a monitoring
    /// restart that reset the usage counters. Written without naming the new
    /// case so it compiles on any SDK.
    nonisolated static func isApproved(_ status: AuthorizationStatus) -> Bool {
        switch status {
        case .approved:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return String(describing: status).lowercased().hasPrefix("approved")
        }
    }

    private init() {
        checkAuthorization()

        // AuthorizationCenter can report .notDetermined for a moment at launch
        // before the real status loads, so follow the publisher rather than
        // trusting a single read.
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] status in
                self?.apply(status, source: "publisher")
            }
            .store(in: &cancellables)
    }

    func checkAuthorization() {
        apply(AuthorizationCenter.shared.authorizationStatus, source: "check")
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationError = nil
            print("✅ FamilyControls authorization granted")
            apply(AuthorizationCenter.shared.authorizationStatus, source: "request", assumeApproved: true)
            // The user explicitly granted access, so a missing schedule here
            // is real (e.g. first setup, or access was switched off).
            ScreenTimeCategoryStore.shared.startMonitoringIfNeeded()
        } catch {
            isAuthorized = false
            authorizationError = error.localizedDescription
            appendDebugLog("AUTH request failed: \(error.localizedDescription)")
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

    // MARK: - Internals

    private func apply(_ status: AuthorizationStatus, source: String, assumeApproved: Bool = false) {
        let wasAuthorized = isAuthorized

        // A one-off read can briefly report .notDetermined even when access is
        // approved. Don't let that downgrade an approved state; the publisher
        // stays authoritative for genuine revokes.
        if wasAuthorized && status == .notDetermined && source != "publisher" {
            print("🔐 Ignoring transient .notDetermined (\(source)) — keeping approved")
            return
        }

        let nowAuthorized = assumeApproved || Self.isApproved(status)
        isAuthorized = nowAuthorized

        if wasAuthorized != nowAuthorized {
            appendDebugLog("AUTH \(source) status=\(status) authorized=\(nowAuthorized)")
            print("🔐 FamilyControls status (\(source)): \(status)")
        }

        // Deliberately no monitoring restart here. Restarts reset the usage
        // counters; they now happen only on an explicit grant (above), on a
        // new day, or when a settings change requires it.

        // Shield writes made while iOS didn't yet recognise this process as
        // authorized can be dropped — rewrite once it does.
        if nowAuthorized && !wasAuthorized {
            AppBlockingManager.shared.reassertIfBlocking()
        }
    }

    private func appendDebugLog(_ message: String) {
        let defaults = UserDefaults(suiteName: appGroup)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        var log = defaults?.string(forKey: SharedKeys.debugLog) ?? ""
        log += line
        if log.count > 20_000 {
            let trimmed = String(log.suffix(15_000))
            log = String(trimmed.drop(while: { $0 != "\n" }).dropFirst())
        }
        defaults?.set(log, forKey: SharedKeys.debugLog)
    }
}
