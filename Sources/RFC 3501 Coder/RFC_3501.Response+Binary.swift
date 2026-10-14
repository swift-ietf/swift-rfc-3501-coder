public import Byte
public import RFC_3501

extension RFC_3501.Response {

    public init<Bytes: Swift::Collection>(binary input: Bytes) throws(RFC_3501.Response.Error) where Bytes.Element == Byte {
        var scanner = RFC_3501.Response.Scanner(input.map(\.bitPattern))
        switch scanner.current {
        case 0x2B:
            scanner.position += 1
            scanner.spaces()
            self = .continuation(scanner.rest())
        case 0x2A:
            scanner.position += 1
            try scanner.expect(0x20)
            self = .untagged(try scanner.data())
        default:
            let tag = scanner.atom()
            guard !tag.isEmpty else { throw .malformed("missing tag") }
            try scanner.expect(0x20)
            self = .tagged(RFC_3501.Tag(rawValue: tag), try scanner.condition(scanner.atom()))
        }
    }
}

extension RFC_3501.Response.Scanner {

    static func status(_ word: String) -> RFC_3501.Response.Status? {
        switch word.uppercased() {
        case "OK": .ok
        case "NO": .no
        case "BAD": .bad
        case "PREAUTH": .preauth
        case "BYE": .bye
        default: nil
        }
    }

    mutating func condition(_ word: String) throws(RFC_3501.Response.Error) -> RFC_3501.Response.Condition {
        guard let status = Self.status(word) else { throw .malformed("unknown status \(word)") }
        spaces()
        let code = try current == 0x5B ? self.code() : nil
        spaces()
        return RFC_3501.Response.Condition(status: status, code: code, text: rest())
    }

    mutating func code() throws(RFC_3501.Response.Error) -> RFC_3501.Response.Code {
        try expect(0x5B)
        let name = atom(stoppingAt: [0x20, 0x5D, 0x0D, 0x0A]).uppercased()
        spaces()
        let code: RFC_3501.Response.Code
        switch name {
        case "ALERT": code = .alert
        case "READ-ONLY": code = .readOnly
        case "READ-WRITE": code = .readWrite
        case "UIDVALIDITY": code = .uidValidity(try number())
        case "UIDNEXT": code = .uidNext(try number())
        case "UNSEEN": code = .unseen(try number())
        case "CAPABILITY": code = .capability(atom(stoppingAt: [0x5D, 0x0D, 0x0A]).split(separator: " ").map(String.init))
        default:
            let detail = atom(stoppingAt: [0x5D, 0x0D, 0x0A])
            code = .other(detail.isEmpty ? name : name + " " + detail)
        }
        while let byte = current, byte != 0x5D, !isAtEnd { position += 1 }
        try expect(0x5D)
        return code
    }

    mutating func data() throws(RFC_3501.Response.Error) -> RFC_3501.Response.Data {
        guard let byte = current, byte >= 0x30, byte <= 0x39 else {
            let word = atom()
            spaces()
            switch word.uppercased() {
            case "OK", "NO", "BAD", "PREAUTH", "BYE":
                return .condition(try condition(word))
            case "CAPABILITY":
                return .capability(rest().split(separator: " ").map(String.init))
            case "FLAGS":
                return .flags(try words())
            case "LIST", "LSUB":
                return .list(try list())
            case "SEARCH":
                return .search(rest().split(separator: " ").compactMap { UInt32($0) })
            default:
                return .other(word + " " + rest())
            }
        }
        let number = try number()
        try expect(0x20)
        let word = atom()
        switch word.uppercased() {
        case "EXISTS": return .exists(number)
        case "RECENT": return .recent(number)
        case "EXPUNGE": return .expunge(number)
        case "FETCH":
            spaces()
            return .fetch(number, try items())
        default: return .other("\(number) \(word) " + rest())
        }
    }

    mutating func list() throws(RFC_3501.Response.Error) -> RFC_3501.Response.List {
        let attributes = try words()
        try expect(0x20)
        let delimiter = try nstring().map { String(decoding: $0, as: UTF8.self) }
        try expect(0x20)
        let mailbox = String(decoding: try astring(), as: UTF8.self)
        return RFC_3501.Response.List(attributes: attributes, delimiter: delimiter, mailbox: RFC_3501.Mailbox(rawValue: mailbox))
    }

    mutating func items() throws(RFC_3501.Response.Error) -> [RFC_3501.Fetch.Item] {
        try expect(0x28)
        var items: [RFC_3501.Fetch.Item] = []
        spaces()
        while current != 0x29 {
            guard current != nil else { throw .malformed("unterminated FETCH") }
            items.append(try item())
            spaces()
        }
        try expect(0x29)
        return items
    }

    mutating func item() throws(RFC_3501.Response.Error) -> RFC_3501.Fetch.Item {
        let name = atom().uppercased()
        switch name {
        case "BODY" where current == 0x5B, "BODY.PEEK" where current == 0x5B:
            let section = try self.section()
            let origin = try skip(0x3C) ? number() : nil
            if origin != nil { try expect(0x3E) }
            try expect(0x20)
            return .body(section, origin: origin, data: try nstring().map { $0.map(Byte.init(bitPattern:)) })
        case "UID":
            try expect(0x20)
            return .uid(try number())
        case "RFC822.SIZE":
            try expect(0x20)
            return .rfc822Size(try number())
        case "FLAGS":
            try expect(0x20)
            return .flags(try words())
        case "INTERNALDATE":
            try expect(0x20)
            return .internalDate(String(decoding: try quoted(), as: UTF8.self))
        default:
            try expect(0x20)
            return .other(name, try value().map(Byte.init(bitPattern:)))
        }
    }

    mutating func section() throws(RFC_3501.Response.Error) -> RFC_3501.Fetch.Section {
        try expect(0x5B)
        let name = atom(stoppingAt: [0x20, 0x5D, 0x0D, 0x0A]).uppercased()
        let section: RFC_3501.Fetch.Section
        switch name {
        case "": section = .whole
        case "HEADER": section = .header
        case "TEXT": section = .text
        case "HEADER.FIELDS":
            spaces()
            section = .headerFields(try words())
        default:
            throw .malformed("unsupported section \(name)")
        }
        try expect(0x5D)
        return section
    }
}
