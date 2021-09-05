import Foundation
import XCTest
import MapboxNavigationNative
import TestHelper
import MapboxDirections
@testable import UhSpotCoreNavigation

final class TilesetDescriptorFactoryTests: TestCase {
    func testLatestDescriptorsAreFromGlobalNavigatorCacheHandle() {
        NavigationSettings.shared.initialize(directions: .mocked,
                                             tileStoreConfiguration: .custom(FileManager.default.temporaryDirectory))
        UhSpotCoreNavigation.Navigator._recreateNavigator()

        let tilesetReceived = expectation(description: "Tileset received")
        TilesetDescriptorFactory.getLatest(completionQueue: .global()) { latestTilesetDescriptor in
            tilesetReceived.fulfill()
            XCTAssertEqual(latestTilesetDescriptor,
                           TilesetDescriptorFactory.getLatestForCache(Navigator.shared.cacheHandle))
        }
        waitForExpectations(timeout: 2, handler: nil)
    }
}
