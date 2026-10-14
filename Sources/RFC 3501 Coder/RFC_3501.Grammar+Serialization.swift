import RFC_3501

extension RFC_3501.Grammar {

    static let atomSpecials: Set<Character> = ["(", ")", "{", " ", "%", "*", "\"", "\\", "]"]

    static func astring(_ value: String, wildcards: Bool = false) throws(RFC_3501.Command.Error) -> String {
        guard value.unicodeScalars.allSatisfy({ $0.value >= 0x01 && $0.value <= 0x7F && $0 != "\r" && $0 != "\n" }) else {
            throw .unquotable(value)
        }
        let isAtom =
            !value.isEmpty
            && value.allSatisfy { character in
                guard let scalar = character.unicodeScalars.first, scalar.value > 0x1F, scalar.value != 0x7F else { return false }
                return wildcards && (character == "%" || character == "*") || !atomSpecials.contains(character)
            }
        return isAtom ? value : quoted(value)
    }

    static func quoted(_ value: String) -> String {
        "\"" + value.reduce(into: "") { result, character in
            result += character == "\"" || character == "\\" ? "\\\(character)" : String(character)
        } + "\""
    }

    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func date(_ date: RFC_3501.Date) -> String {
        "\(date.day)-\(months[max(1, min(12, date.month)) - 1])-\(date.year)"
    }

    static func sequence(_ set: RFC_3501.SequenceSet) -> String {
        set.ranges.map { range in
            switch range.upper {
            case nil: "\(range.lower):*"
            case let upper? where upper == range.lower: "\(range.lower)"
            case let upper?: "\(range.lower):\(upper)"
            }
        }.joined(separator: ",")
    }

    static func key(_ key: RFC_3501.Search.Key) throws(RFC_3501.Command.Error) -> String {
        switch key {
        case .all: return "ALL"
        case .from(let value): return "FROM " + (try astring(value))
        case .to(let value): return "TO " + (try astring(value))
        case .subject(let value): return "SUBJECT " + (try astring(value))
        case .body(let value): return "BODY " + (try astring(value))
        case .text(let value): return "TEXT " + (try astring(value))
        case .header(let name, let value): return "HEADER " + (try astring(name)) + " " + (try astring(value))
        case .since(let value): return "SINCE " + date(value)
        case .before(let value): return "BEFORE " + date(value)
        case .on(let value): return "ON " + date(value)
        case .uid(let value): return "UID " + sequence(value)
        case .larger(let value): return "LARGER \(value)"
        case .smaller(let value): return "SMALLER \(value)"
        case .not(let value): return "NOT " + (try self.key(value))
        case .or(let left, let right): return "OR " + (try self.key(left)) + " " + (try self.key(right))
        case .and(let keys): return "(" + (try keys.map { (key: RFC_3501.Search.Key) throws(RFC_3501.Command.Error) -> String in try self.key(key) }).joined(separator: " ") + ")"
        }
    }

    static func section(_ section: RFC_3501.Fetch.Section) -> String {
        switch section {
        case .whole: ""
        case .header: "HEADER"
        case .headerFields(let names): "HEADER.FIELDS (" + names.joined(separator: " ") + ")"
        case .text: "TEXT"
        }
    }

    static func attribute(_ attribute: RFC_3501.Fetch.Attribute) -> String {
        switch attribute {
        case .uid: "UID"
        case .flags: "FLAGS"
        case .internalDate: "INTERNALDATE"
        case .rfc822Size: "RFC822.SIZE"
        case .envelope: "ENVELOPE"
        case .bodyStructure: "BODYSTRUCTURE"
        case .body(let value, let peek): (peek ? "BODY.PEEK[" : "BODY[") + section(value) + "]"
        }
    }

    static func command(_ command: RFC_3501.Command) throws(RFC_3501.Command.Error) -> String {
        switch command {
        case .capability:
            return "CAPABILITY"
        case .noop:
            return "NOOP"
        case .logout:
            return "LOGOUT"
        case .login(let user, let password):
            return "LOGIN " + (try astring(user)) + " " + (try astring(password))
        case .list(let reference, let pattern):
            return "LIST " + (reference.isEmpty ? "\"\"" : try astring(reference)) + " "
                + (pattern.isEmpty ? "\"\"" : try astring(pattern, wildcards: true))
        case .examine(let mailbox):
            return "EXAMINE " + (try astring(mailbox.rawValue))
        case .search(let uid, let keys):
            let criteria = try keys.map { (key: RFC_3501.Search.Key) throws(RFC_3501.Command.Error) -> String in try self.key(key) }
            return (uid ? "UID " : "") + "SEARCH " + criteria.joined(separator: " ")
        case .fetch(let uid, let set, let attributes):
            let items = attributes.map(attribute)
            return (uid ? "UID " : "") + "FETCH " + sequence(set) + " "
                + (items.count == 1 ? items[0] : "(" + items.joined(separator: " ") + ")")
        }
    }
}
