import XCTest
@testable import TransmissionTransport

final class TransmissionTransportTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(TransmissionTransport().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
