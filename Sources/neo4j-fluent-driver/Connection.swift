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
        var theId: UInt64? = nil
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
                                    if queryResult.nodes.count == 0 {
                                        node = Fluent.Node.null
                                    } else if queryResult.nodes.count == 1 {
                                        let resultNode = queryResult.nodes.first!.value
                                        node = self.theoNodeToFluentNode(resultNode: resultNode)
                                        if let id = resultNode.id {
                                            theId = id
                                        }

                                    } else if queryResult.nodes.count > 1 {
                                        let resultNodes = queryResult.nodes.values.map { self.theoNodeToFluentNode(resultNode: $0) }
                                        node = Fluent.Node.array(resultNodes)
                                    }
                                }
                            }
                            group.leave()
                        }
                    }
                }
            }
            group.wait()
        }

        if let action = query.wrapped?.action,
            let theId = theId {
            if case .create = action {
                return Node(StructuredData.number(StructuredData.Number.int(Int(theId))))
            }
        }

        return node
    }

    func theoNodeToFluentNode(resultNode: Theo.Node) -> Fluent.Node {
        var properties = Dictionary(uniqueKeysWithValues:
            resultNode.properties.map { key, value in (key, value.toStructuredData()) })
        if let id = resultNode.id {
            let idInt = Int(id)
            properties["id"] = StructuredData.number(StructuredData.Number.int(idInt))
        }
        let fluentNode = Fluent.Node(StructuredData.object(properties), in: nil)
        return fluentNode
    }
}
