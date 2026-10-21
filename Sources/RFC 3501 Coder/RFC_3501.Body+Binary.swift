public import Byte
public import RFC_3501

extension RFC_3501.Body {
    public init<Bytes: Swift::Collection>(binary input: Bytes) throws(RFC_3501.Response.Error) where Bytes.Element == Byte {
        var scanner = RFC_3501.Response.Scanner(input.map(\.bitPattern))
        self = try scanner.body(depth: 0)
        scanner.spaces()
        guard scanner.isAtEnd else { throw .malformed("trailing body structure") }
    }
}

extension RFC_3501.Response.Scanner {
    mutating func body(depth: Int) throws(RFC_3501.Response.Error) -> RFC_3501.Body {
        guard depth < 64 else { throw .malformed("body nesting limit") }
        try expect(0x28)
        spaces()
        if current == 0x28 {
            var parts: [RFC_3501.Body] = []
            while current == 0x28 {
                parts.append(try body(depth: depth + 1))
                spaces()
            }
            let subtype = try bodyString().lowercased()
            spaces()
            let parameters = current == 0x29 ? [:] : try bodyParameters()
            try bodyEnd()
            return .init(type: "multipart", subtype: subtype, parameters: parameters, parts: parts)
        }
        let type = try bodyString().lowercased()
        try expect(0x20)
        let subtype = try bodyString().lowercased()
        try expect(0x20)
        var parameters = try bodyParameters()
        for _ in 0..<3 {
            try expect(0x20)
            _ = try nstring()
        }
        try expect(0x20)
        _ = try number()
        var parts: [RFC_3501.Body] = []
        if type == "text" {
            try expect(0x20)
            _ = try number()
        } else if type == "message" && subtype == "rfc822" {
            try expect(0x20)
            _ = try value()
            try expect(0x20)
            parts.append(try body(depth: depth + 1))
            try expect(0x20)
            _ = try number()
        }
        spaces()
        if current != 0x29 {
            _ = try nstring()
            spaces()
            if current == 0x28 {
                try expect(0x28)
                _ = try bodyString()
                try expect(0x20)
                let disposition = try bodyParameters()
                parameters.merge(disposition) { _, right in right }
                try expect(0x29)
            } else if current != 0x29 {
                _ = try nstring()
            }
        }
        try bodyEnd()
        return .init(type: type, subtype: subtype, parameters: parameters, parts: parts)
    }

    mutating func bodyString() throws(RFC_3501.Response.Error) -> String {
        guard let bytes = try nstring() else { throw .malformed("missing body string") }
        return String(decoding: bytes, as: UTF8.self)
    }

    mutating func bodyParameters() throws(RFC_3501.Response.Error) -> [String: String] {
        if current != 0x28 {
            guard try nstring() == nil else { throw .malformed("invalid body parameters") }
            return [:]
        }
        try expect(0x28)
        var result: [String: String] = [:]
        while current != 0x29 {
            let name = try bodyString().lowercased()
            try expect(0x20)
            result[name] = try bodyString()
            spaces()
        }
        try expect(0x29)
        return result
    }

    mutating func bodyEnd() throws(RFC_3501.Response.Error) {
        spaces()
        while current != 0x29 {
            guard current != nil, !isAtEnd else { throw .malformed("unterminated body structure") }
            _ = try value()
            spaces()
        }
        try expect(0x29)
    }
}
