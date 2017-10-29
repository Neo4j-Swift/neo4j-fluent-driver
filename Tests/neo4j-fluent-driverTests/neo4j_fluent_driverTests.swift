import XCTest
import Fluent
import Bolt

@testable import neo4j_fluent_driver

class neo4j_fluent_driverTests: XCTestCase {
    
    
    var driver: neo4j_fluent_driver.Driver!
    var db: Database!
    
    override func setUp() {
        super.setUp()
        
        driver = Driver()
        db = Database(driver)
        Compound.database = db
        Atom.database = db
    }
    
    func testFilterQuery() throws {
        let query = Query<User>(db)
        try query.filter("name", "bob")
        
        let request = serialize(query)
    }
    
    func testCreateQuery() throws {
        let atom = Atom(name: "Miniton")
        try atom.save()
    }
    
    func testUpdateQuery() throws {
    
    }
    
    func testDeleteQuery() throws {
        let atom = Atom(name: "Miniton")
        try atom.save()
        try atom.delete()
    }


    static var allTests = [
        ("testFilterQuery", testFilterQuery),
    ]
}

extension neo4j_fluent_driverTests {
    private func serialize<E:Entity>(_ query: Query<E>) -> Request {
        let serializer = Serializer<E>(query: query)
        return serializer.serialize()
    }
}
