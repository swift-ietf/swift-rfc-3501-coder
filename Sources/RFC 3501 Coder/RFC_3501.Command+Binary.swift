public import Byte
public import RFC_3501

extension [Byte] {

    public init(_ command: RFC_3501.Command, tag: RFC_3501.Tag) throws(RFC_3501.Command.Error) {
        guard !tag.rawValue.isEmpty, tag.rawValue.unicodeScalars.allSatisfy({
            $0.value > 0x20 && $0.value < 0x7F && !"(){ %*\"\\]+".unicodeScalars.contains($0)
        }) else { throw .unquotable("invalid tag") }
        if case .fetch(_, let sequence, let attributes) = command {
            guard !sequence.ranges.isEmpty, !attributes.isEmpty else { throw .unquotable("empty FETCH") }
            for attribute in attributes {
                if case .body(.headerFields(let names), _) = attribute {
                    guard !names.isEmpty, names.allSatisfy({ name in
                        !name.isEmpty && name.utf8.allSatisfy { $0 > 0x20 && $0 < 0x7F && !"(){}[]:\"\\".utf8.contains($0) }
                    }) else { throw .unquotable("invalid header field") }
                }
            }
        }
        let line = tag.rawValue + " " + (try RFC_3501.Grammar.command(command)) + "\r\n"
        guard !line.dropLast(2).contains(where: { $0 == "\r" || $0 == "\n" }) else {
            throw .unquotable("embedded line break")
        }
        self = line.utf8.map(Byte.init(bitPattern:))
    }
}
