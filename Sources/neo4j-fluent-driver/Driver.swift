import Fluent
import Foundation

public final class Driver: Fluent.Driver {

    public func makeConnection(_ type: ConnectionType) throws -> Fluent.Connection {
        return Connection(queryLogger: queryLogger)!
    }

    public var idKey: String

    public var idType: IdentifierType

    public var keyNamingConvention: KeyNamingConvention

    public var queryLogger: QueryLogger?

    init(idKey: String = "id", idType: IdentifierType = .int, keyNamingConvention: KeyNamingConvention = .camelCase, queryLogger: QueryLogger? = nil) {
        self.idKey = idKey
        self.idType = idType
        self.keyNamingConvention = keyNamingConvention
        self.queryLogger = queryLogger
    }

}
