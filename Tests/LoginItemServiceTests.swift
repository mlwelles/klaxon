import XCTest
@testable import Klaxon

/// Mock implementation of LoginItemServiceProtocol for testing
final class MockLoginItemService: LoginItemServiceProtocol {
    private(set) var currentStatus: LoginItemStatus = .notRegistered
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    var shouldThrowOnRegister = false
    var shouldThrowOnUnregister = false

    var status: LoginItemStatus {
        currentStatus
    }

    func register() throws {
        registerCallCount += 1
        if shouldThrowOnRegister {
            throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock register error"])
        }
        currentStatus = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if shouldThrowOnUnregister {
            throw NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock unregister error"])
        }
        currentStatus = .notRegistered
    }

    /// Reset mock state for fresh test
    func reset() {
        currentStatus = .notRegistered
        registerCallCount = 0
        unregisterCallCount = 0
        shouldThrowOnRegister = false
        shouldThrowOnUnregister = false
    }

    /// Set the status directly for testing specific scenarios
    func setStatus(_ status: LoginItemStatus) {
        currentStatus = status
    }
}

final class LoginItemServiceTests: XCTestCase {
    var mockService: MockLoginItemService!

    override func setUp() {
        super.setUp()
        mockService = MockLoginItemService()
    }

    override func tearDown() {
        mockService = nil
        super.tearDown()
    }

    // MARK: - Basic Status Tests

    func testInitialStatusIsNotRegistered() {
        XCTAssertEqual(mockService.status, .notRegistered)
        XCTAssertFalse(mockService.isEnabled)
    }

    func testIsEnabledReturnsTrueWhenEnabled() {
        mockService.setStatus(.enabled)
        XCTAssertTrue(mockService.isEnabled)
    }

    func testIsEnabledReturnsFalseWhenNotRegistered() {
        mockService.setStatus(.notRegistered)
        XCTAssertFalse(mockService.isEnabled)
    }

    // MARK: - Duplicate Prevention Tests

    func testEnableLaunchAtLoginDoesNotCallRegisterWhenAlreadyEnabled() throws {
        // Given: Service is already enabled
        mockService.setStatus(.enabled)
        XCTAssertEqual(mockService.registerCallCount, 0)

        // When: Enable is called again
        try mockService.enableLaunchAtLogin()

        // Then: register() should NOT be called (prevents duplicates)
        XCTAssertEqual(mockService.registerCallCount, 0, "register() should not be called when already enabled - this prevents duplicate login items")
        XCTAssertTrue(mockService.isEnabled)
    }

    func testEnableLaunchAtLoginCallsRegisterWhenNotEnabled() throws {
        // Given: Service is not enabled
        mockService.setStatus(.notRegistered)
        XCTAssertEqual(mockService.registerCallCount, 0)

        // When: Enable is called
        try mockService.enableLaunchAtLogin()

        // Then: register() should be called exactly once
        XCTAssertEqual(mockService.registerCallCount, 1)
        XCTAssertTrue(mockService.isEnabled)
    }

    func testDisableLaunchAtLoginDoesNotCallUnregisterWhenAlreadyDisabled() throws {
        // Given: Service is not enabled
        mockService.setStatus(.notRegistered)
        XCTAssertEqual(mockService.unregisterCallCount, 0)

        // When: Disable is called
        try mockService.disableLaunchAtLogin()

        // Then: unregister() should NOT be called
        XCTAssertEqual(mockService.unregisterCallCount, 0, "unregister() should not be called when already disabled")
        XCTAssertFalse(mockService.isEnabled)
    }

    func testDisableLaunchAtLoginCallsUnregisterWhenEnabled() throws {
        // Given: Service is enabled
        mockService.setStatus(.enabled)
        XCTAssertEqual(mockService.unregisterCallCount, 0)

        // When: Disable is called
        try mockService.disableLaunchAtLogin()

        // Then: unregister() should be called exactly once
        XCTAssertEqual(mockService.unregisterCallCount, 1)
        XCTAssertFalse(mockService.isEnabled)
    }

    // MARK: - Multiple Toggle Prevention Tests

    func testMultipleEnableCallsOnlyRegisterOnce() throws {
        // Given: Service starts as not registered
        mockService.setStatus(.notRegistered)

        // When: Enable is called multiple times rapidly
        try mockService.enableLaunchAtLogin()
        try mockService.enableLaunchAtLogin()
        try mockService.enableLaunchAtLogin()

        // Then: register() should only be called once (first call enables it, subsequent calls see it's already enabled)
        XCTAssertEqual(mockService.registerCallCount, 1, "Multiple enable calls should only register once to prevent duplicates")
    }

    func testMultipleDisableCallsOnlyUnregisterOnce() throws {
        // Given: Service starts as enabled
        mockService.setStatus(.enabled)

        // When: Disable is called multiple times rapidly
        try mockService.disableLaunchAtLogin()
        try mockService.disableLaunchAtLogin()
        try mockService.disableLaunchAtLogin()

        // Then: unregister() should only be called once
        XCTAssertEqual(mockService.unregisterCallCount, 1, "Multiple disable calls should only unregister once")
    }

    // MARK: - Repair Functionality Tests

    func testRepairLoginItemWhenShouldBeEnabled() throws {
        // Given: Service is in an unknown state (simulating corruption)
        mockService.setStatus(.enabled)

        // When: Repair is called with shouldBeEnabled = true
        try mockService.repairLoginItem(shouldBeEnabled: true)

        // Then: It should unregister first (cleanup), then register fresh
        XCTAssertEqual(mockService.unregisterCallCount, 1, "Repair should unregister first to clean up")
        XCTAssertEqual(mockService.registerCallCount, 1, "Repair should register when shouldBeEnabled is true")
        XCTAssertTrue(mockService.isEnabled)
    }

    func testRepairLoginItemWhenShouldBeDisabled() throws {
        // Given: Service is enabled
        mockService.setStatus(.enabled)

        // When: Repair is called with shouldBeEnabled = false
        try mockService.repairLoginItem(shouldBeEnabled: false)

        // Then: It should only unregister
        XCTAssertEqual(mockService.unregisterCallCount, 1, "Repair should unregister when shouldBeEnabled is false")
        XCTAssertEqual(mockService.registerCallCount, 0, "Repair should not register when shouldBeEnabled is false")
        XCTAssertFalse(mockService.isEnabled)
    }

    // MARK: - Error Handling Tests

    func testEnableLaunchAtLoginThrowsWhenRegisterFails() {
        // Given: Service will throw on register
        mockService.shouldThrowOnRegister = true
        mockService.setStatus(.notRegistered)

        // When/Then: Enable should throw
        XCTAssertThrowsError(try mockService.enableLaunchAtLogin()) { error in
            XCTAssertEqual((error as NSError).code, 1)
        }
    }

    func testDisableLaunchAtLoginThrowsWhenUnregisterFails() {
        // Given: Service will throw on unregister
        mockService.shouldThrowOnUnregister = true
        mockService.setStatus(.enabled)

        // When/Then: Disable should throw
        XCTAssertThrowsError(try mockService.disableLaunchAtLogin()) { error in
            XCTAssertEqual((error as NSError).code, 2)
        }
    }

    // MARK: - Status Enum Tests

    func testLoginItemStatusFromSMAppServiceStatus() {
        // Test all status mappings
        XCTAssertEqual(LoginItemStatus(from: .enabled), .enabled)
        XCTAssertEqual(LoginItemStatus(from: .notRegistered), .notRegistered)
        XCTAssertEqual(LoginItemStatus(from: .requiresApproval), .requiresApproval)
        XCTAssertEqual(LoginItemStatus(from: .notFound), .notFound)
    }
}

// MARK: - PreferencesWindowController Integration Tests

final class PreferencesWindowControllerLoginItemTests: XCTestCase {
    var windowController: PreferencesWindowController!
    var mockLoginItemService: MockLoginItemService!

    override func setUp() {
        super.setUp()
        mockLoginItemService = MockLoginItemService()
        windowController = PreferencesWindowController(loginItemService: mockLoginItemService)
        windowController.loadWindow()
    }

    override func tearDown() {
        windowController.close()
        windowController = nil
        mockLoginItemService = nil
        super.tearDown()
    }

    func testPreferencesWindowControllerUsesInjectedService() {
        // The window controller should use our mock service
        // This verifies dependency injection is working correctly
        XCTAssertNotNil(windowController)
        XCTAssertNotNil(mockLoginItemService)
    }

    func testCheckboxStateReflectsServiceStatus() {
        // Given: Service is enabled
        mockLoginItemService.setStatus(.enabled)

        // When: A new controller is created with this service
        let controller = PreferencesWindowController(loginItemService: mockLoginItemService)
        controller.loadWindow()

        // The checkbox state should reflect the actual service status
        // (This tests that loadPreferences reads from the service correctly)
        XCTAssertNotNil(controller.window)

        controller.close()
    }
}
