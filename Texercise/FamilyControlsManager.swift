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

    private init() {
        checkAuthorization()

        // AuthorizationCenter often reports .notDetermined for a moment at
        // launch before the real status loads, so follow the publisher rather
        // than trusting a single read.
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
            apply(.approved, source: "request")
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

    private func apply(_ status: AuthorizationStatus, source: String) {
        let wasAuthorized = isAuthorized

        // A one-off synchronous read can briefly report .notDetermined even
        // when access is approved — that's what kept bringing back the Grant
        // Access button (tapping it then succeeded silently because iOS
        // already had the grant). Don't let a one-off read downgrade an
        // approved state. The publisher stays authoritative, so a genuine
        // revoke in Settings still comes through.
        if wasAuthorized && status == .notDetermined && source != "publisher" {
            print("🔐 Ignoring transient .notDetermined (\(source)) — keeping approved")
            return
        }

        let nowAuthorized = (status == .approved)
        isAuthorized = nowAuthorized

        if wasAuthorized != nowAuthorized {
            appendDebugLog("AUTH \(source) status=\(status) authorized=\(nowAuthorized)")
            print("🔐 FamilyControls status (\(source)): \(status)")
        }

        // Access coming back (first launch read, a re-grant in Settings, or the
        // Grant Access button) means iOS may have wiped the DeviceActivity
        // schedule. ensureMonitoring now detects a missing schedule and
        // restarts it; otherwise it's a no-op that preserves today's counters.
        if nowAuthorized && !wasAuthorized {
            ScreenTimeCategoryStore.shared.startMonitoringIfNeeded()
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
