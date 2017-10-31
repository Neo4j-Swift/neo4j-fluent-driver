import Foundation
import Fluent
import PackStream
import Bolt
import Theo

class SerializerHelper {
    static var filterCounter: UInt64 = 0
}

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
        var parameters = [String:PackProtocol]()
        
        let rawFilters = query.filters.filter { if case .raw = $0 { return true } else { return false } }
        let filters = query.filters.filter { if case .raw = $0 { return false } else { return true } }.map { filterToString(filter: $0) }
        
        var queryString = "MATCH (n)\nWHERE \n"
        queryString += "RETURN n"
        return Request.run(statement: queryString, parameters: Map(dictionary: parameters))
    }
    
    private func filterToString(filter: RawOr<Filter>) -> String {
        var filterString = ""
        var property = (String,PackProtocol)
        SerializerHelper.filterCounter = SerializerHelper.filterCounter + 1

        switch filter {
        case let .raw(string, nodes):
            return "" // TODO: What does this make?
        case let .some(theFilter):
            let nodeAlias = "`\(theFilter.entity.name)`"
            switch theFilter.method {
            case let .compare(propName, comparison, node):
                let name = "\(propName)\(SerializerHelper.filterCounter)"
                properties[name] = node.wrapped.toPackProtocol()

                switch comparison {
                case .equals:
                    let f = "\(nodeAlias).`\(propName)` = {\(name)}"
                    filters.append(f)
                case .greaterThan:
                    let f = "\(nodeAlias).`\(propName)` > {\(name)}"
                    filters.append(f)
                case .lessThan:
                    let f = "\(nodeAlias).`\(propName)` < {\(name)}"
                    filters.append(f)
                case .greaterThanOrEquals:
                    let f = "\(nodeAlias).`\(propName)` >= {\(name)}"
                    filters.append(f)
                case .lessThanOrEquals:
                    let f = "\(nodeAlias).`\(propName)` <= {\(name)}"
                    filters.append(f)
                case .notEquals:
                    let f = "\(nodeAlias).`\(propName)` != {\(name)}"
                    filters.append(f)
                case .hasSuffix:
                    print(propName)
                case .hasPrefix:
                    print(propName)
                case .contains:
                    print(propName)
                case let .custom(string):
                    print(propName)
                }
            case let .subset(propName, scope, nodes):
                print(propName)
            case let .group(relation, rawOrFilter):
                print(relation)
            }
            
            print(theFilter)
            return ""
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
    
    
    
    private func serializeCreate() -> Request {
        let node = queryToNode()
        let request = node.createRequest()
        return request
    }

    private func queryToNode() -> Theo.Node {
        var labels = [String]()
        if let entity = query.entity {
            let label = type(of: entity).name.capitalizingFirstLetter()
            labels.append(label)
        }
        
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

        
        let node = Theo.Node(labels: labels, properties: properties)
        if let id = id {
            node.id = id
        }
        return node
    }
    
    private func serializeModify() -> Bolt.Request {
        
        
        
        return Request.ackFailure()
    }
    
    private func serializeSchema(schema: Schema) -> Bolt.Request {
        
        return Request.ackFailure()
    }
    
}

