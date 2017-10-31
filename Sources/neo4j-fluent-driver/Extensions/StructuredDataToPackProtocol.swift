import Foundation
import Fluent
import PackStream
import Bolt
import Theo

extension PackProtocol {
    
    public func toStructuredData() -> StructuredData {
        if let uint = self.uintValue() {
            let value = UInt(uint)
            return StructuredData.number(StructuredData.Number.uint(value))
        } else if let int = self.intValue() {
            let value = Int(truncatingIfNeeded: int)
            return StructuredData.number(StructuredData.Number.int(value))
        } else if let double = self as? Double {
            return StructuredData.number(StructuredData.Number.double(double))
        } else if let bool = self as? Bool {
            return StructuredData.bool(bool)
        } else if let list = self as? List {
            return StructuredData.array(list.items.map { $0.toStructuredData() })
        } else if let map = self as? Map {
            return StructuredData.object(Dictionary(uniqueKeysWithValues:
                map.dictionary.map { key, value in (key, value.toStructuredData()) }))
        } else if self is Null {
            return StructuredData.null
        } else if let string = self as? String {
            return StructuredData.string(string)
        } else if let s = self as? Structure {
            print("Structure of type \(s.signature) is not supported")
            return StructuredData.null
        } else {
            print("\(type(of: self)) is unsupported for casting to structured data")
            return StructuredData.null
        }
    }
}

extension StructuredData {
    
    public func toPackProtocol() -> PackProtocol {
        switch self {
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
            return List(items: value.map { $0.toPackProtocol() })
        case let .object(value):
            return Map(dictionary: Dictionary(uniqueKeysWithValues:
                value.map { key, value in (key, value.toPackProtocol()) }))
        case let .bytes(value):
            return List(items: value as! [PackProtocol]) // TODO: Do we support byte arrays as something other than a list of UInt8s?
        case let .date(value):
            return value.timeIntervalSince1970
        }
    }
}
