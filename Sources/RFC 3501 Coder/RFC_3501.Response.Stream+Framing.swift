public import Byte
public import RFC_3501

extension RFC_3501.Response.Stream {

    public mutating func append(_ bytes: some Swift::Collection<Byte>) {
        buffer.append(contentsOf: bytes.map(\.bitPattern))
    }

    public mutating func next() -> [Byte]? {
        guard let end = Self.end(of: buffer) else { return nil }
        let response = buffer[..<end].map(Byte.init(bitPattern:))
        buffer.removeFirst(end)
        return response
    }

    static func end(of bytes: [UInt8]) -> Int? {
        var position = bytes.startIndex
        while position < bytes.endIndex {
            guard let lineFeed = bytes[position...].firstIndex(of: 0x0A) else { return nil }
            let lineEnd = lineFeed > position && bytes[lineFeed - 1] == 0x0D ? lineFeed - 1 : lineFeed
            guard let count = literal(bytes[position..<lineEnd]) else { return lineFeed + 1 }
            let literalEnd = lineFeed + 1 + count
            guard literalEnd <= bytes.endIndex else { return nil }
            position = literalEnd
        }
        return nil
    }

    static func literal(_ line: ArraySlice<UInt8>) -> Int? {
        guard line.last == 0x7D, let open = line.lastIndex(of: 0x7B) else { return nil }
        let inner = line[(open + 1)..<(line.endIndex - 1)]
        let digits = inner.last == 0x2B ? inner.dropLast() : inner
        guard !digits.isEmpty, digits.allSatisfy({ $0 >= 0x30 && $0 <= 0x39 }) else { return nil }
        return Int(String(decoding: digits, as: UTF8.self))
    }
}
