//
//  KnittitTests.swift
//  KnittitTests
//
//  Created by Evan Thomas on 9/14/26.
//

import XCTest
@testable import Knittit

final class KnittitTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testUpdateUsernameEmptyValidation() async {
        let result = await ProfileManager.shared.updateUsername(userId: UUID(), newUsername: "   ")
        switch result {
        case .success:
            XCTFail("Expected failure for empty username")
        case .failure(let error):
            if let profileError = error as? ProfileError {
                XCTAssertEqual(profileError, ProfileError.emptyUsername)
            } else {
                XCTFail("Expected ProfileError.emptyUsername")
            }
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
