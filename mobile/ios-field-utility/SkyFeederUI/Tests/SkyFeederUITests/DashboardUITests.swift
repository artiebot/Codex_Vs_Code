import XCTest

final class DashboardUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testDashboardLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check for Dashboard tab
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].exists)
        
        // Check for main sections
        XCTAssertTrue(app.staticTexts["Video Gallery"].exists)
        XCTAssertTrue(app.staticTexts["Visits This Week"].exists)
        XCTAssertTrue(app.staticTexts["Recent Activity"].exists)
    }
    
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Go to Developer tab
        app.tabBars.buttons["Developer"].tap()
        XCTAssertTrue(app.navigationBars["Developer"].exists)
        
        // Go to Settings tab
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        
        // Go back to Dashboard
        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(app.staticTexts["Video Gallery"].exists)
    }
}
