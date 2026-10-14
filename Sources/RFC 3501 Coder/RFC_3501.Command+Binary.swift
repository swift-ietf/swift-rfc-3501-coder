public import Byte
public import RFC_3501

extension [Byte] {

    public init(_ command: RFC_3501.Command, tag: RFC_3501.Tag) throws(RFC_3501.Command.Error) {
        let line = tag.rawValue + " " + (try RFC_3501.Grammar.command(command)) + "\r\n"
        self = line.utf8.map(Byte.init(bitPattern:))
    }
}
