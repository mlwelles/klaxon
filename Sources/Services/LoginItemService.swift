import Foundation
import ServiceManagement

/// Status of the login item registration
enum LoginItemStatus: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
    case unknown

    init(from smStatus: SMAppService.Status) {
        switch smStatus {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .notRegistered
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        @unknown default:
            self = .unknown
        }
    }
}

/// Protocol for managing login item registration
/// Abstracted to enable testing without system side effects
protocol LoginItemServiceProtocol {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

/// Default implementation using SMAppService
final class LoginItemService: LoginItemServiceProtocol {
    static let shared = LoginItemService()

    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: LoginItemStatus {
        LoginItemStatus(from: service.status)
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}

/// Extension with convenience methods for managing login state
extension LoginItemServiceProtocol {
    /// Whether the login item is currently enabled
    var isEnabled: Bool {
        status == .enabled
    }

    /// Enable launch at login, preventing duplicates by checking status first
    /// - Returns: true if registration succeeded or was already enabled
    @discardableResult
    func enableLaunchAtLogin() throws -> Bool {
        guard status != .enabled else {
            // Already enabled, no action needed (prevents duplicates)
            return true
        }
        try register()
        return status == .enabled
    }

    /// Disable launch at login
    /// - Returns: true if unregistration succeeded or was already disabled
    @discardableResult
    func disableLaunchAtLogin() throws -> Bool {
        guard status == .enabled else {
            // Already disabled, no action needed
            return true
        }
        try unregister()
        return status != .enabled
    }

    /// Attempt to repair login item state by unregistering and re-registering
    /// This can help clean up corrupted state or duplicates in some cases
    /// - Parameter shouldBeEnabled: Whether the login item should be enabled after repair
    func repairLoginItem(shouldBeEnabled: Bool) throws {
        // First, attempt to unregister regardless of current state
        // This is a best-effort cleanup
        if status == .enabled {
            try? unregister()
        }

        // If it should be enabled, register fresh
        if shouldBeEnabled {
            try register()
        }
    }
}
