import XCTest
@testable import SkyFeederUI

@MainActor
final class DashboardViewModelTests: XCTestCase {
    
    func testLoadData() async {
        // Given
        let viewModel = DashboardViewModel(
            deviceService: MockDeviceService(),
            visitService: MockVisitService(),
            statsService: MockStatsService()
        )
        
        // When
        await viewModel.loadData()
        
        // Then
        XCTAssertNotNil(viewModel.currentDevice)
        XCTAssertEqual(viewModel.weeklyStats.count, 7)
        XCTAssertFalse(viewModel.recentVisits.isEmpty)
        XCTAssertFalse(viewModel.videoGallery.isEmpty)
        XCTAssertNotNil(viewModel.selectedGalleryItem)
    }
    
    func testGalleryNavigation() async {
        // Given
        let viewModel = DashboardViewModel(
            deviceService: MockDeviceService(),
            visitService: MockVisitService(),
            statsService: MockStatsService()
        )
        await viewModel.loadData()
        
        guard let firstItem = viewModel.selectedGalleryItem else {
            XCTFail("Gallery should have items")
            return
        }
        
        // When
        viewModel.selectNextGalleryItem()
        
        // Then
        XCTAssertNotEqual(viewModel.selectedGalleryItem?.id, firstItem.id)
        
        // When
        viewModel.selectPreviousGalleryItem()
        
        // Then
        XCTAssertEqual(viewModel.selectedGalleryItem?.id, firstItem.id)
    }
}
