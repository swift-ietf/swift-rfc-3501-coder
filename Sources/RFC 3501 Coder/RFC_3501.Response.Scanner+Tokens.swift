import Byte
import RFC_3501

extension RFC_3501.Response.Scanner {

    init(_ bytes: [UInt8]) {
        self.init(bytes: bytes, position: bytes.startIndex)
    }

    var isAtEnd: Bool {
        position >= bytes.endIndex || bytes[position] == 0x0D || bytes[position] == 0x0A
    }

    var current: UInt8? {
        position < bytes.endIndex ? bytes[position] : nil
    }

    mutating func skip(_ byte: UInt8) -> Bool {
        guard current == byte else { return false }
        position += 1
        return true
    }

    mutating func expect(_ byte: UInt8) throws(RFC_3501.Response.Error) {
        guard skip(byte) else {
            throw .malformed("expected \(Character(Unicode.Scalar(byte))) at \(position)")
        }
    }

    mutating func spaces() {
        while current == 0x20 { position += 1 }
    }

    mutating func atom(stoppingAt stops: Set<UInt8> = [0x20, 0x28, 0x29, 0x5B, 0x5D, 0x7B, 0x22, 0x0D, 0x0A]) -> String {
        let start = position
        while let byte = current, !stops.contains(byte) { position += 1 }
        return String(decoding: bytes[start..<position], as: UTF8.self)
    }

    mutating func number() throws(RFC_3501.Response.Error) -> UInt32 {
        let start = position
        while let byte = current, byte >= 0x30, byte <= 0x39 { position += 1 }
        guard position > start, let value = UInt32(String(decoding: bytes[start..<position], as: UTF8.self)) else {
            throw .malformed("expected a number at \(start)")
        }
        return value
    }

    mutating func rest() -> String {
        let start = position
        while !isAtEnd { position += 1 }
        return String(decoding: bytes[start..<position], as: UTF8.self)
    }

    mutating func quoted() throws(RFC_3501.Response.Error) -> [UInt8] {
        try expect(0x22)
        var value: [UInt8] = []
        while let byte = current, byte != 0x22 {
            position += 1
            switch byte {
            case 0x5C:
                guard let escaped = current else { throw .malformed("unterminated quoted string") }
                value.append(escaped)
                position += 1
            default:
                value.append(byte)
            }
        }
        try expect(0x22)
        return value
    }

    mutating func literal() throws(RFC_3501.Response.Error) -> [UInt8] {
        try expect(0x7B)
        let count = try number()
        _ = skip(0x2B)
        try expect(0x7D)
        _ = skip(0x0D)
        try expect(0x0A)
        let end = position + Int(count)
        guard end <= bytes.endIndex else { throw .malformed("literal runs past the response") }
        defer { position = end }
        return Array(bytes[position..<end])
    }

    mutating func nstring() throws(RFC_3501.Response.Error) -> [UInt8]? {
        switch current {
        case 0x22: return try quoted()
        case 0x7B: return try literal()
        default:
            let word = atom()
            guard word.uppercased() == "NIL" else { throw .malformed("expected a string at \(position)") }
            return nil
        }
    }

    mutating func astring() throws(RFC_3501.Response.Error) -> [UInt8] {
        switch current {
        case 0x22: return try quoted()
        case 0x7B: return try literal()
        default: return Array(atom(stoppingAt: [0x20, 0x28, 0x29, 0x7B, 0x22, 0x0D, 0x0A]).utf8)
        }
    }

    mutating func words() throws(RFC_3501.Response.Error) -> [String] {
        try expect(0x28)
        var words: [String] = []
        spaces()
        while current != 0x29 {
            guard current != nil, !isAtEnd else { throw .malformed("unterminated list") }
            words.append(atom(stoppingAt: [0x20, 0x29, 0x0D, 0x0A]))
            spaces()
        }
        try expect(0x29)
        return words
    }

    mutating func value(depth: Int = 0) throws(RFC_3501.Response.Error) -> [UInt8] {
        guard depth < 128 else { throw .malformed("value nesting limit") }
        let start = position
        switch current {
        case 0x28:
            position += 1
            spaces()
            while current != 0x29 {
                guard current != nil else { throw .malformed("unterminated list") }
                _ = try value(depth: depth + 1)
                spaces()
            }
            position += 1
        case 0x22:
            _ = try quoted()
        case 0x7B:
            _ = try literal()
        default:
            if atom().isEmpty { position += 1 }
        }
        return Array(bytes[start..<position])
    }
}
