import Foundation
import Fluent
import PackStream
import Bolt
import Theo

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
    
    private func structuredDataToPackProtocol(data: StructuredData) -> PackProtocol {
        switch data {
        case .null:
            return PackStream.Null()
        case let .bool(value):
            return value
        case let .number(value):
            switch value {
            case let .int(v):
                return Int64(v)
            case let .uint(v):
                return Int64(v) //TODO: Add a good test
            case let .double(v):
                return v
            }
        case let .string(value):
            return value
        case let .array(value):
            return List(items: value.map { structuredDataToPackProtocol(data: $0) })
        case let .object(value):
            return Map(dictionary: Dictionary(uniqueKeysWithValues:
                value.map { key, value in (key, structuredDataToPackProtocol(data: value)) }))
            return value
        case let .bytes(value):
            return List(items: value as! [PackProtocol]) // TODO: Do we support byte arrays as something other than a list of UInt8s?
        case let .date(value):
            return value.timeIntervalSince1970
        }
    }
    
    private func serializeFetch(fields: [RawOr<ComputedField>]) -> Bolt.Request {

        return Request.ackFailure()
    }
    
    private func serializeAggregate(field: String?, aggregate: Aggregate) -> Bolt.Request {
        
        return Request.ackFailure()
    }
    
    private func serializeDelete() -> Bolt.Request {
        
        return Request.ackFailure()
    }
    
    private func serializeCreate() -> Request {
        
        var labels = [String]()
        if let entity = query.entity {
            let label = type(of: entity).name
            labels.append(label)
        }
        
        var properties = [String:PackProtocol]()
        for (key, value) in query.data {
            if let key = key.wrapped,
                let structuredValue = value.wrapped?.wrapped {
                let value = structuredDataToPackProtocol(data: structuredValue)
                properties[key] = value
            } else {
                print("It's raw!!")
            }
        }

        let node = Theo.Node(labels: labels, properties: properties)
        let request = node.createRequest()
        return request
    }
    
    private func serializeModify() -> Bolt.Request {
        
        return Request.ackFailure()
    }
    
    private func serializeSchema(schema: Schema) -> Bolt.Request {
        
        return Request.ackFailure()
    }
    
}

