import XCTest
import CoreLocation
import UhSpotCoreNavigation
import TestHelper

class NavigationLocationManagerTests: TestCase {
    func testNavigationLocationManagerDefaultAccuracy() {
        let locationManager = NavigationLocationManager()
        XCTAssertEqual(locationManager.desiredAccuracy, kCLLocationAccuracyBest)
    }
}
