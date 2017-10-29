import Foundation
import Fluent
import Bolt
import Theo

public final class Connection: Fluent.Connection {
    public var isClosed: Bool = true

    public var queryLogger: QueryLogger?

    private let client: BoltClient

    init?(queryLogger: QueryLogger?) {
        self.queryLogger = queryLogger
        
        do {
            print("Creating client")
            client = try BoltClient(hostname: "192.168.0.106", port: 7687, username: "neo4j", password: "<passcode>", encrypted: true)
            print("Did create client")
        } catch(let error) {
            print("Failed to create client with error \(error)")
            return nil
        }

        //TODO: What is going on?? Why do I need this time???
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.1) {
            group.leave()
        }
        group.wait()
        
        print("Connect to client")
        client.connect() { result in
            switch result {
            case let .failure(error):
                print("Failed to connect with error \(error)")
            case let .success(isSuccess):
                if !isSuccess {
                    print("Connection not successful")
                } else {
                    print("Connected, really!")
                }
            }
        }
    }
    
    // Actually performs a query
    public func query<E>(_ query: RawOr<Query<E>>) throws -> Fluent.Node where E : Entity {
        
        print("Start query")
        var node: Fluent.Node! = nil
        switch query {
        case let .raw(cypher, nodes):
            // todo: convert cypher + node into Bolt.Request
            print("Raw cypher: \(cypher)")
            node = Fluent.Node(booleanLiteral: false)
        case let .some(query):
            let serializer = Serializer(query: query)
            let request = serializer.serialize()
            
            let group = DispatchGroup()
            group.enter()
            client.execute(request: request) { response in
                switch response {
                case let .failure(error):
                    print("Failure executing request: \(error)")
                    node = Fluent.Node(booleanLiteral: false)
                    group.leave()
                case let .success((isSuccess, partialQueryResult)):
                    if !isSuccess {
                        print("Query did not succeed")
                        node = Fluent.Node(booleanLiteral: false)
                        group.leave()
                    } else {
                        self.client.pullAll(partialQueryResult: partialQueryResult) { result in
                            switch result {
                            case let .failure(error):
                                print("Failure fetching response: \(error)")
                                node = Fluent.Node(booleanLiteral: false)
                            case let .success(isSuccess, queryResult):
                                if !isSuccess {
                                    print("Query did not succeed")
                                    node = Fluent.Node(booleanLiteral: false)
                                } else {
                                    // Success!
                                    if let resultNode = queryResult.nodes.first?.value {
                                        //TODO: Get better way of mapping back to [String:StructuredData]
                                        // don't forget "id"
                                        node = Fluent.Node(StructuredData.object(resultNode.properties as! [String:StructuredData]), in: nil)
//                                        node = Fluent.Node(booleanLiteral: true)

                                    } else {
                                        print("Query did not contain result")
                                        node = Fluent.Node(booleanLiteral: false)
                                    }
                                }
                            }
                            group.leave()
                        }
                    }
                    //TODO: Turn this into a Node
                }
            }
            group.wait()
        }
        
        print("Now execute cypher synchronously and prepare vapor node for return")
        return node
    }
}

