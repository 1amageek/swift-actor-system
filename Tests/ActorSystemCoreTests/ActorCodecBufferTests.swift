@_spi(Transport) import ActorSystemCore
import Synchronization
import Testing

@Suite
struct ActorCodecBufferTests {
    @Test
    func directEncodingPreservesGoldenWireBytes() throws {
        var encoder = ActorPayloadEncoder()
        try encoder.append(true, field: ActorFieldID(1))
        try encoder.append(Int64.min, field: ActorFieldID(2))
        try encoder.append(UInt64.max, field: ActorFieldID(3))
        try encoder.append("A😀", field: ActorFieldID(4))
        try encoder.appendEnumeration(
            caseID: 0x01020304,
            associatedValues: ActorByteBuffer([0xaa, 0xbb]),
            field: ActorFieldID(5)
        )
        #expect(encoder.finish().bytes == [
            0, 0, 0, 1, 1, 0, 0, 0, 1, 1,
            0, 0, 0, 2, 2, 0, 0, 0, 8, 128, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 3, 3, 0, 0, 0, 8, 255, 255, 255, 255, 255, 255, 255, 255,
            0, 0, 0, 4, 6, 0, 0, 0, 5, 65, 240, 159, 152, 128,
            0, 0, 0, 5, 9, 0, 0, 0, 6, 1, 2, 3, 4, 170, 187,
        ])
    }

    @Test(arguments: [UInt64(0), 1, 0x0102030405060708, .max])
    func integersMatchReferenceBytesAndDecodeFromUnalignedStorage(_ value: UInt64) throws {
        var encoder = ActorPayloadEncoder()
        try encoder.append(value, field: ActorFieldID(1))
        let expected = [UInt8](arrayLiteral: 0, 0, 0, 1, 3, 0, 0, 0, 8)
            + (0..<8).reversed().map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) }
        #expect(encoder.finish().bytes == expected)
        let owner = ActorByteBuffer([0xff] + expected + [0xee])
        var decoder = try ActorPayloadDecoder(
            owner.slice(1..<(1 + expected.count)),
            options: ActorPortableDecodingOptions()
        )
        let next = try decoder.nextField()
        let field = try #require(next)
        #expect(try field.decodeUnsignedInteger(as: UInt64.self) == value)
        let remaining = try decoder.nextField()
        #expect(remaining == nil)
    }

    @Test
    func floatingPointBitsAndEncoderSnapshotsArePreserved() throws {
        var encoder = ActorPayloadEncoder()
        let float = Float(bitPattern: 0x7fc00042)
        let double = Double(bitPattern: 0x8000000000000000)
        try encoder.append(float, field: ActorFieldID(1))
        try encoder.append(double, field: ActorFieldID(2))
        let snapshot = encoder.finish()
        try encoder.append("later", field: ActorFieldID(3))
        var decoder = try ActorPayloadDecoder(snapshot, options: ActorPortableDecodingOptions())
        let first = try decoder.nextField()
        let second = try decoder.nextField()
        #expect(try #require(first).decodeFloat().bitPattern == float.bitPattern)
        #expect(try #require(second).decodeDouble().bitPattern == double.bitPattern)
        let remaining = try decoder.nextField()
        #expect(remaining == nil)
        #expect(encoder.finish().count > snapshot.count)
    }

    @Test
    func truncatedIntegersThrowInsteadOfTrapping() throws {
        for count in 0..<8 {
            var encoder = ActorPayloadEncoder()
            // A message has the same length-prefixed framing as an integer.
            try encoder.append(message: ActorByteBuffer([UInt8](repeating: 0, count: count)), field: ActorFieldID(1))
            var bytes = encoder.finish().bytes
            bytes[4] = ActorWireType.unsignedInteger.rawValue
            var decoder = try ActorPayloadDecoder(ActorByteBuffer(bytes), options: ActorPortableDecodingOptions())
            let next = try decoder.nextField()
            let field = try #require(next)
            #expect(throws: ActorSystemError.decodingFailed) {
                try field.decodeUnsignedInteger(as: UInt64.self)
            }
        }
    }

    @Test
    func rawSpanBorrowsOnlySliceAndRetainsItsStorage() throws {
        let released = ReleaseState()
        var owner: ActorByteBuffer? = ActorByteBuffer(storage: TrackedStorage(released: released))
        var slice = owner?.slice(1..<5)
        owner = nil
        #expect(!released.value.withLock { $0 })
        let value = try #require(slice).withRawSpan {
            UInt32(bigEndian: $0.load(fromByteOffset: 0, as: UInt32.self))
        }
        #expect(value == 42)
        #expect(throws: BorrowFailure.expected) {
            try #require(slice).withRawSpan { _ in throw BorrowFailure.expected }
        }
        slice = nil
        #expect(released.value.withLock { $0 })
    }

    private enum BorrowFailure: Error { case expected }

    private final class ReleaseState: Sendable {
        let value = Mutex(false)
    }

    private final class TrackedStorage: ActorByteBufferStorage, Sendable {
        let bytes: [UInt8] = [255, 0, 0, 0, 42, 255]
        let released: ReleaseState

        init(released: ReleaseState) {
            self.released = released
        }

        deinit { released.value.withLock { $0 = true } }

        var count: Int { bytes.count }
        subscript(index: Int) -> UInt8 { bytes[index] }
        func withUnsafeBytes(_ body: (UnsafeRawBufferPointer) throws -> Void) rethrows {
            try bytes.withUnsafeBytes(body)
        }
    }
}
