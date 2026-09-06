import ActorSystemCore

extension CounterError: ActorPortableValue {
    public func encodeActorValue() throws -> ActorByteBuffer {
        var associated = ActorPayloadEncoder()
        let caseID: UInt32
        switch self {
        case .accepted(let value0):
            caseID = 1
            try associated.append(message: value0.encodeActorValue(), field: ActorFieldID(1))
        case .rejected(let value0):
            caseID = 2
            try associated.append(message: value0.encodeActorValue(), field: ActorFieldID(1))
        }
        var encoder = ActorPayloadEncoder()
        try encoder.appendEnumeration(caseID: caseID, associatedValues: associated.finish(), field: ActorFieldID(1))
        return encoder.finish()
    }
    public static func decodeActorValue(from payload: ActorByteBuffer, options: ActorPortableDecodingOptions) throws -> Self {
        var decoder = try ActorPayloadDecoder(payload, options: options)
        guard let field = try decoder.nextField(), field.id == ActorFieldID(1), field.wireType == .enumeration else { throw ActorSystemError.decodingFailed }
        if let _ = try decoder.nextField() { throw ActorSystemError.decodingFailed }
        var decoded = try field.decodeEnumeration()
        let associatedOptions = try options.descending()
        switch decoded.caseID {
        case 1:
            guard let field0 = try decoded.associatedValues.nextField(), field0.id == ActorFieldID(1), field0.wireType == .message else { throw ActorSystemError.decodingFailed }
            let value0 = try Int.decodeActorValue(from: field0.payloadBuffer(), options: associatedOptions.descending())
            if let _ = try decoded.associatedValues.nextField() { throw ActorSystemError.decodingFailed }
            return .accepted(value0)
        case 2:
            guard let field0 = try decoded.associatedValues.nextField(), field0.id == ActorFieldID(1), field0.wireType == .message else { throw ActorSystemError.decodingFailed }
            let value0 = try Int.decodeActorValue(from: field0.payloadBuffer(), options: associatedOptions.descending())
            if let _ = try decoded.associatedValues.nextField() { throw ActorSystemError.decodingFailed }
            return .rejected(value0)
        default: throw ActorSystemError.decodingFailed
        }
    }
}
