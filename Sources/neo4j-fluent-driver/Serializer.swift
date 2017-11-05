import Foundation
import Fluent
import PackStream
import Bolt
import Theo

class SerializerHelper {
    static var filterCounter: UInt64 = 0
}

protocol RepresentsRelationship {}
extension Pivot: RepresentsRelationship {}

public final class Serializer<E:Entity> {

    private let query: Query<E>

    init(query: Query<E>) {
        self.query = query
    }

    public func serialize() -> Bolt.Request {
        switch query.action {
        case let .fetch(fields):
            return serializeFetch(fields: fields)
        case let .aggregate(field, aggregate):
            return serializeAggregate(field: field, aggregate: aggregate)
        case .delete:
            return serializeDelete()
        case .create:
            return serializeCreate()
        case .modify:
            return serializeModify()
        case let .schema(schema):
            return serializeSchema(schema: schema)
        }
    }

    private func makeFilter() -> Request {

        let rawFilters = query.filters.filter { if case .raw = $0 { return true } else { return false } }

        let filtersWithParams = query.filters.filter { if case .raw = $0 { return false } else { return true } }.map { filterToString(filter: $0) }
        let filters = filtersWithParams.map { $0.0 }.joined(separator: "\nAND ")
        let paramTuples = filtersWithParams.flatMap { $0.1 }
        let parameters = Dictionary(uniqueKeysWithValues: paramTuples.map { $0 })

        let nodeAlias = "`\(E.name)`"
        let queryString = "MATCH (\(nodeAlias))\nWHERE \(filters)\nRETURN (\(nodeAlias))"
        print(queryString)
        return Request.run(statement: queryString, parameters: Map(dictionary: parameters))

    }

    private func filterToString(filter: RawOr<Filter>) -> (String, (String,PackProtocol)?) {
        var property: (String,PackProtocol)? = nil
        SerializerHelper.filterCounter = SerializerHelper.filterCounter + 1

        switch filter {
        case let .raw(string, nodes):
            print(string)
            return ("", nil) // TODO: What does this make?
        case let .some(theFilter):
            let nodeAlias = "`\(theFilter.entity.name)`"
            switch theFilter.method {
            case let .compare(propName, comparison, node):
                let name = "\(propName)\(SerializerHelper.filterCounter)"
                property = (name, node.wrapped.toPackProtocol())

                switch comparison {
                case .equals:
                    let f = "\(nodeAlias).`\(propName)` = {\(name)}"
                    return (f, property)
                case .greaterThan:
                    let f = "\(nodeAlias).`\(propName)` > {\(name)}"
                    return (f, property)
                case .lessThan:
                    let f = "\(nodeAlias).`\(propName)` < {\(name)}"
                    return (f, property)
                case .greaterThanOrEquals:
                    let f = "\(nodeAlias).`\(propName)` >= {\(name)}"
                    return (f, property)
                case .lessThanOrEquals:
                    let f = "\(nodeAlias).`\(propName)` <= {\(name)}"
                    return (f, property)
                case .notEquals:
                    let f = "\(nodeAlias).`\(propName)` != {\(name)}"
                    return (f, property)
                case .hasSuffix:
                    print(propName)
                    return ("", nil)
                case .hasPrefix:
                    print(propName)
                    return ("", nil)
                case .contains:
                    print(propName)
                    return ("", nil)
                case let .custom(string):
                    print(propName)
                    return ("", nil)
                }
            case let .subset(propName, scope, nodes):
                print(propName)
                return ("", nil)
            case let .group(relation, rawOrFilter):
                print(relation)
                return ("", nil)
            }
        }
    }

    private func serializeFetch(fields: [RawOr<ComputedField>]) -> Bolt.Request {

        let queryFilter = makeFilter()
        return queryFilter
    }

    private func serializeAggregate(field: String?, aggregate: Aggregate) -> Bolt.Request {

        return Request.ackFailure()
    }

    private func serializeDelete() -> Bolt.Request {

        let node = queryToNode()
        let request = node.deleteRequest()
        return request
    }

    private func representsRelationship() -> Bool {
        guard let entity = query.entity else { return false }
        return entity is RepresentsRelationship
    }

    private func serializeCreate() -> Request {
        
        if representsRelationship() {
            return serializeCreateRelationship()
        } else {
            return serializeCreateNode()
        }
    }

    private func serializeCreateRelationship() -> Request {
        
        let (_, labels, properties) = queryToIdLabelAndProperties()
        assert(labels.count == 1)
        let sides = labels[0].split(separator: "_").map { $0.lowercased() }
        let leftSide = sides[0]
        let rightSide = sides[1]
        guard let leftSideId = properties[leftSide + "Id"]?.uintValue(),
              let rightSideId = properties[rightSide + "Id"]?.uintValue()
        else {
            return Bolt.Request.ackFailure()
        }

        guard
            let relationshipFrom = Relationship(fromNodeId: leftSideId, toNodeId: rightSideId, name: "relates", type: .from, properties: [:]),
            let relationshipTo = Relationship(fromNodeId: leftSideId, toNodeId: rightSideId, name: "relates", type: .to, properties: [:])
        else {
            return Bolt.Request.ackFailure()
        }

        return [relationshipFrom, relationshipTo].createRequest(withReturnStatement: true)

    }
    
    private func serializeCreateNode() -> Request {
        
        let node = queryToNode()
        let request = node.createRequest()
        return request
    }

    private func queryToNode() -> Theo.Node {
        let (id, labels, properties) = queryToIdLabelAndProperties()
        
        let node = Theo.Node(labels: labels, properties: properties)
        if let id = id {
            node.id = id
        }
        return node
    }
    
    private func queryToIdLabelAndProperties() -> (UInt64?, [String], [String:PackProtocol]) {
        var labels = [String]()
        let label = E.name.capitalizingFirstLetter()
        labels.append(label)

        var id: UInt64? = {
            let uint = query.entity?.id?.wrapped.uint
            if let uint = uint {
                return UInt64(uint)
            } else {
                return nil
            }
        }()

        var properties = [String:PackProtocol]()
        for (key, value) in /* query.entity?.storage.fetchedRow ?? */ query.data {
            if let key = key.wrapped,
                let structuredValue = value.wrapped?.wrapped {
                let value = structuredValue.toPackProtocol()

                if id == nil,
                   key == "id" {
                    id = value.uintValue()
                } else {
                    properties[key] = value
                }
            } else {
                print("It's raw!!")
            }
        }

        return (id, labels, properties)
    }

    private func serializeModify() -> Bolt.Request {

        var statement: [String] = []
        
        var theProperties = [String:PackProtocol]()
        let nodeAlias = "`\(E.name)`"
        let (idCandidate, labels, properties) = queryToIdLabelAndProperties()
        guard let id = idCandidate else {
            print("Can only update an existing node, but node was missing Id. Did you mean to create it instead?")
            return Bolt.Request.ackFailure()
        }
        
        statement += "MATCH (\(nodeAlias))"
        statement += "WHERE id(\(nodeAlias)) = \(id)"
        
        if !query.data.isEmpty {
            var fragments: [String] = []
            
            var i = 0
            query.data.forEach { (key, value) in
                i = i + 1

                let keyString: String
                switch key {
                case .raw(let raw, _):
                    keyString = raw
                case .some(let key):
                    keyString = key
                }
                
                
                let valueString: String
                switch value {
                case .raw(let raw, _):
                    valueString = raw
                case .some(let value):
                    valueString = "{\(keyString)\(i)}"
                    if keyString != "id" {
                        theProperties["\(keyString)\(i)"] = value.toPackProtocol()
                    }
                }
                
                if keyString != "id" {
                    fragments += "\(nodeAlias).`\(keyString)` = \(valueString)"
                }
            }
            
            if fragments.count > 0 {
                
                statement += "SET"
                statement += fragments.joined(separator: ",\n")
            } else {
                return Bolt.Request.run(statement: "RETURN 1 as n", parameters: Map(dictionary: [:]))
            }
        }

        let queryString = statement.joined(separator: "\n")
        let request = Bolt.Request.run(statement: queryString, parameters: Map(dictionary: theProperties))
        print(queryString)
        return request
    }

    private func serializeSchema(schema: Schema) -> Bolt.Request {

        return Request.ackFailure()
    }

}
