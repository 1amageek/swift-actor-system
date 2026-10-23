/// Run with the same optimized compiler and Core sources before and after changes.
@main
struct CodecBenchmark {
    static func main() throws {
        _ = try run(iterations: 1_000)
        var samples: [Double] = []
        var expectedChecksum: UInt64?
        for _ in 0..<5 {
            let clock = ContinuousClock()
            let start = clock.now
            let checksum = try run(iterations: 20_000)
            let elapsed = start.duration(to: clock.now).components
            samples.append(Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15)
            if let expectedChecksum {
                precondition(checksum == expectedChecksum)
            } else {
                expectedChecksum = checksum
            }
        }
        guard let expectedChecksum else { preconditionFailure("Missing benchmark samples") }
        print("codec-roundtrips=20000 samples-ms=\(samples) median-ms=\(samples.sorted()[2]) checksum=\(expectedChecksum)")
    }

    @inline(never)
    static func run(iterations: Int) throws -> UInt64 {
        var checksum: UInt64 = 0
        for iteration in 0..<iterations {
            var encoder = ActorPayloadEncoder()
            try encoder.append(Int64(-iteration), field: ActorFieldID(1))
            try encoder.append(Double(iteration) + 0.5, field: ActorFieldID(2))
            try encoder.append("actor-codec-benchmark-value", field: ActorFieldID(3))
            for field in 4...20 {
                try encoder.append(UInt64(iteration + field), field: ActorFieldID(UInt32(field)))
            }
            var decoder = try ActorPayloadDecoder(encoder.finish(), options: ActorPortableDecodingOptions())
            while let field = try decoder.nextField() {
                switch field.id.rawValue {
                case 1:
                    checksum &+= UInt64(bitPattern: try field.decodeSignedInteger(as: Int64.self))
                case 2:
                    checksum &+= try field.decodeDouble().bitPattern
                case 3:
                    checksum &+= UInt64(try field.decodeString().utf8.count)
                default:
                    checksum &+= try field.decodeUnsignedInteger(as: UInt64.self)
                }
            }
        }
        return checksum
    }
}
