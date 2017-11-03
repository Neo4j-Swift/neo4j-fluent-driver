import XCTest
import Fluent
import PackStream
import Bolt
import Theo

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
    
    private func makeClient() throws -> BoltClient {
        let theo = try Theo.BoltClient(
            hostname: "192.168.0.106",
            port: 7687,
            username: "neo4j",
            password: "<passcode>",
            encrypted: true)

        let group = DispatchGroup()
        group.enter()
        performConnect(client: theo) { isSuccess in
            XCTAssertTrue(isSuccess)
            group.leave()
        }
        group.wait()

        return theo
    }

    private func performConnect(client: BoltClient, completionBlock: ((Bool) -> ())? = nil) {
        client.connect() { connectionResult in
            switch connectionResult {
            case let .failure(error):
                if error.errorCode == -9806 {
                    self.performConnect(client: client) { result in
                        completionBlock?(result)
                    }
                } else {
                    XCTFail()
                    completionBlock?(false)
                }
            case let .success(isConnected):
                if !isConnected {
                    print("Error, could not connect!")
                }
                completionBlock?(isConnected)
            }
        }
    }

    func testFilterQueryWithOneParameter() throws {

        let query = Query<User>(db)
        try query.filter("name", "bob")

        let matchingNode = Theo.Node(labels: ["User"], properties: [ "name": "bob" ])

        try doTestFilterWith(query: query, forMatchingNode: matchingNode)
        
    }

    func testFilterQueryWithTwoParameters() throws {
        
        let query = Query<User>(db)
        try query.filter("name", "anne")
        try query.filter("age", 35)
        
        let matchingNode = Theo.Node(labels: ["User"], properties: [ "name": "anne", "age": 35 ])
        
        try doTestFilterWith(query: query, forMatchingNode: matchingNode)
        
    }

    func doTestFilterWith<E: Entity>(query: Query<E>, forMatchingNode matchingNode: Theo.Node) throws {
        
        let exp = expectation(description: "Filter returned a node")
        let theo = try makeClient()

        let request = serialize(query)
        
        let group = DispatchGroup()
        group.enter()
        var foundNodes = 0
        theo.executeWithResult(request: request) { result in
            switch result {
            case let .failure(error):
                XCTFail(error.localizedDescription)
            case let .success((isSuccess, queryResult)):
                XCTAssertTrue(isSuccess)
                foundNodes = queryResult.nodes.count
                group.leave()
            }
        }
        group.wait()

        let createResponse = theo.createNodeSync(node: matchingNode)
        XCTAssertNil(createResponse.error)
        XCTAssertTrue(createResponse.value!)

        theo.executeWithResult(request: request) { result in
            switch result {
            case let .failure(error):
                XCTFail(error.localizedDescription)
            case let .success((isSuccess, queryResult)):
                XCTAssertTrue(isSuccess)
                XCTAssertEqual(foundNodes + 1, queryResult.nodes.count)
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 15.0) { error in
            XCTAssertNil(error)
        }
    }
    
    func testCreateQuery() throws {
        let atom = Atom(name: "Miniton")
        try atom.save()
        XCTAssertNotNil(atom.id)
    }
    
    func testUpdateQuery() throws {
        let atom = Atom(name: "Miniton")
        try atom.save()
        atom.name = "Miniton the great"
        try atom.save()
    }
    
    func testDeleteQuery() throws {
        let atom = Atom(name: "Miniton")
        try atom.save()
        try atom.delete()
    }


    static var allTests = [
        ("testFilterQueryWithOneParameter", testFilterQueryWithOneParameter),
        ("testFilterQueryWithTwoParameters", testFilterQueryWithTwoParameters),
        ("testCreateQuery", testCreateQuery),
        ("testUpdateQuery", testUpdateQuery),
        ("testDeleteQuery", testDeleteQuery),
    ]
}

extension neo4j_fluent_driverTests {
    private func serialize<E:Entity>(_ query: Query<E>) -> Request {
        let serializer = Serializer<E>(query: query)
        return serializer.serialize()
    }
}
