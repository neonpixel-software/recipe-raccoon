#if os(macOS)
import AppKit
@testable import RecipeRaccoon
import XCTest

@MainActor
final class MacAppDelegateTests: XCTestCase {
    func testRegistersForRemoteNotificationsAtLaunchWhenICloudIsEnabled() {
        var registrations = 0
        let sut = MacAppDelegate(isICloudEnabled: true, registerForRemoteNotifications: { registrations += 1 })

        sut.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertEqual(registrations, 1)
    }

    func testSkipsTheRegistrationWithoutICloud() {
        var registrations = 0
        let sut = MacAppDelegate(isICloudEnabled: false, registerForRemoteNotifications: { registrations += 1 })

        sut.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))

        XCTAssertEqual(registrations, 0)
    }

    /// A failed registration is only logged: the delegate doesn't retry it.
    func testAFailedRegistrationIsOnlyLogged() {
        var registrations = 0
        let sut = MacAppDelegate(isICloudEnabled: true, registerForRemoteNotifications: { registrations += 1 })

        sut.application(NSApplication.shared, didFailToRegisterForRemoteNotificationsWithError: CocoaError(.featureUnsupported))

        XCTAssertEqual(registrations, 0)
    }

    /// Like the store, the push registration stays off in the unit tests' host app (#160).
    func testTheTestHostDoesNotRegister() {
        XCTAssertTrue(RecipeRaccoonApp.isHostingUnitTests)
        XCTAssertFalse(MacAppDelegate().isICloudEnabled)
    }
}
#endif
