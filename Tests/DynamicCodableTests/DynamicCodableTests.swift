import XCTest
@testable import DynamicCodable

public struct Person : Codable, Hashable {
    public let name : String
    public let age : Int
}

final class DynamicCodableTests: XCTestCase {
    
    func testDynamicCodable() throws {
        try CodableTypeRegistry.register(Person.self)
        let bob = Person(name: "Bob", age: 73)
        let encoder = JSONEncoder()
        let data = try encoder.encode(DynamicCodable(bob))
        let decoder = JSONDecoder()
        let person = (try decoder.decode(DynamicCodable.self, from: data)).value as! Person
        XCTAssertEqual(person, bob)
    }

    static var allTests = [
        ("testDynamicCodable", testDynamicCodable),
    ]
}
