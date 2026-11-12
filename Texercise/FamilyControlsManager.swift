import Foundation
import Combine
import UIKit
import FamilyControls
import ManagedSettings

@MainActor
final class FamilyControlsManager: ObservableObject {

    static let shared = FamilyControlsManager()

    @Published var isAuthorized = false
    @Published var authorizationError: String? = nil

    private var cancellables = Set<AnyCancellable>()
    private let appGroup = "group.com.samring.texercise"

    /// Set once the user has approved access at least once. Lets us re-confirm
    /// silently on later launches without ever surprising a brand-new user
    /// with a permission prompt.
    private let everApprovedKey = "familyControlsEverApproved"
    private var everApproved: Bool {
        get { UserDefaults.standard.bool(forKey: everApprovedKey) }
        set { UserDefaults.standard.set(newValue, forKey: everApprovedKey) }
    }

    private var isConfirming = false
    private var lastConfirmAttempt: Date = .distantPast

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

        // With .individual authorization, a relaunched app process can read
        // .notDetermined even though the user approved — and while it does,
        // iOS ignores this process's shield writes. The debug log showed
        // exactly that: blocks "applied" with live=Not Determined that never
        // took effect. Re-requesting is silent when access is still granted,
        // so do it on every launch and every return to the foreground.
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.confirmAuthorizationSilently(reason: "foreground")
            }
            .store(in: &cancellables)

        confirmAuthorizationSilently(reason: "launch")
    }

    func checkAuthorization() {
        apply(AuthorizationCenter.shared.authorizationStatus, source: "check")
    }

    /// Re-confirms access without a prompt, provided the user has approved
    /// before. If access really was revoked, iOS shows its normal Face ID
    /// prompt, which is the right thing to ask for anyway.
    func confirmAuthorizationSilently(reason: String) {
        // A saved app selection is only possible after approval, so it also
        // counts — covers installs that approved before this flag existed.
        guard everApproved || ScreenTimeCategoryStore.shared.hasSelection else { return }
        guard !isConfirming else { return }
        // Throttle: applyRestrictions can call this several times a second.
        guard Date().timeIntervalSince(lastConfirmAttempt) > 30 else { return }

        isConfirming = true
        lastConfirmAttempt = Date()
        appendDebugLog("AUTH confirm start reason=\(reason) status=\(AuthorizationCenter.shared.authorizationStatus)")

        Task { @MainActor in
            defer { isConfirming = false }
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                appendDebugLog("AUTH confirm ok status=\(AuthorizationCenter.shared.authorizationStatus)")
                apply(.approved, source: "confirm")
            } catch {
                appendDebugLog("AUTH confirm failed: \(error.localizedDescription)")
                print("❌ Silent authorization confirm failed: \(error.localizedDescription)")
            }
        }
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
                    self.everApproved = false
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
        // Access button. Don't let a one-off read downgrade an approved state.
        // The publisher stays authoritative for genuine revokes.
        if wasAuthorized && status == .notDetermined && source != "publisher" {
            print("🔐 Ignoring transient .notDetermined (\(source)) — keeping approved")
            return
        }

        let nowAuthorized = (status == .approved)
        isAuthorized = nowAuthorized
        if nowAuthorized { everApproved = true }

        if wasAuthorized != nowAuthorized {
            appendDebugLog("AUTH \(source) status=\(status) authorized=\(nowAuthorized)")
            print("🔐 FamilyControls status (\(source)): \(status)")
        }

        if nowAuthorized {
            // Access coming back may mean iOS wiped the DeviceActivity schedule;
            // ensureMonitoring restarts it only if it's actually missing.
            if !wasAuthorized {
                ScreenTimeCategoryStore.shared.startMonitoringIfNeeded()
            }
            // Any shield written while we weren't recognised as authorized was
            // dropped by iOS — write it again now that we are.
            if source == "confirm" || source == "request" || !wasAuthorized {
                AppBlockingManager.shared.reassertIfBlocking()
            }
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
