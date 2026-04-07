import XCTest
@testable import JobSearchApp

final class KeychainManagerTests: XCTestCase {
    let manager = KeychainManager.shared
    let testKey = "test.keychain.key"

    override func tearDown() {
        try? manager.delete(key: testKey)
        super.tearDown()
    }

    func test_save_andRetrieve_value() throws {
        try manager.save("sk-test-api-key-12345", forKey: testKey)
        let retrieved = try manager.retrieve(forKey: testKey)
        XCTAssertEqual(retrieved, "sk-test-api-key-12345")
    }

    func test_retrieve_missingKey_returnsNil() throws {
        let result = try manager.retrieve(forKey: "nonexistent.key.xyz")
        XCTAssertNil(result)
    }

    func test_save_overwrites_existingValue() throws {
        try manager.save("old-value", forKey: testKey)
        try manager.save("new-value", forKey: testKey)
        let retrieved = try manager.retrieve(forKey: testKey)
        XCTAssertEqual(retrieved, "new-value")
    }

    func test_delete_removesValue() throws {
        try manager.save("to-be-deleted", forKey: testKey)
        try manager.delete(key: testKey)
        let result = try manager.retrieve(forKey: testKey)
        XCTAssertNil(result)
    }
}
