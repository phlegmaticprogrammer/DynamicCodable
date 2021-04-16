import Foundation

public typealias CodableTypeId = String

public enum DynamicCodableError : Error {
    
    case typeIsAlreadyRegistered(typeId : CodableTypeId)
    
    case noSuchTypeIdFound(typeId : CodableTypeId)
    
    case cannotEncode(value : Any, typeId : CodableTypeId)

    case cannotDecode(typeId : CodableTypeId)
}

public struct CodableType {
    
    public let typeId : CodableTypeId
    
    public let dynamicDecode : (inout UnkeyedDecodingContainer) throws -> AnyHashable
    
    public let dynamicEncode : (_ value : AnyHashable, inout UnkeyedEncodingContainer) throws -> Void
    
    public init(typeId : CodableTypeId,
                dynamicDecode: @escaping (inout UnkeyedDecodingContainer) throws -> AnyHashable,
                dynamicEncode: @escaping (_ value : AnyHashable, inout UnkeyedEncodingContainer) throws -> Void)
    {
        self.typeId = typeId
        self.dynamicDecode = dynamicDecode
        self.dynamicEncode = dynamicEncode
    }
    
}

public struct CodableTypeRegistry {
    
    private static var registry : [CodableTypeId : CodableType] = [:]
    private static let lock : NSLock = NSLock()
    
    public static func register(_ codableType : CodableType) throws {
        let id = codableType.typeId
        lock.lock()
        defer { lock.unlock() }
        if registry[id] != nil { throw DynamicCodableError.typeIsAlreadyRegistered(typeId: id) }
        registry[id] = codableType
    }
    
    public static func register<C : Codable>(_ ty : C.Type, as typeId : CodableTypeId) throws {
        let codableType = CodableType(
            typeId: typeId,
            dynamicDecode: { container in
                guard let h = (try container.decode(ty)) as? AnyHashable else {
                    throw DynamicCodableError.cannotDecode(typeId: typeId)
                }
                return h
            },
            dynamicEncode: { value, container in
                guard let typedValue : C = value as? C else {
                    throw DynamicCodableError.cannotEncode(value: value, typeId: typeId)
                }
                try container.encode(typedValue)
            })
        try register(codableType)
    }
    
    public static func lookup(typeId : CodableTypeId) -> CodableType? {
        lock.lock()
        defer { lock.unlock() }
        return registry[typeId]
    }
    
}

public struct DynamicCodable : Decodable, Encodable, Hashable {
    
    public let typeId : CodableTypeId
    
    public let value : AnyHashable
            
    public init<H:Hashable>(typeId : CodableTypeId, value : H) {
        self.typeId = typeId
        self.value = value
    }
        
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        typeId = try container.decode(String.self)
        guard let ty = CodableTypeRegistry.lookup(typeId: typeId) else {
            throw DynamicCodableError.noSuchTypeIdFound(typeId: typeId)
        }
        value = try ty.dynamicDecode(&container)
    }
    
    public func encode(to encoder: Encoder) throws {
        guard let ty = CodableTypeRegistry.lookup(typeId: typeId) else {
            throw DynamicCodableError.noSuchTypeIdFound(typeId: typeId)
        }
        var container = encoder.unkeyedContainer()
        try container.encode(typeId)
        try ty.dynamicEncode(value, &container)
    }
    
}

