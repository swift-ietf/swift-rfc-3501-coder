import Byte
import RFC_3501
import RFC_3501_Coder
import Testing

extension RFC_3501.Command {

    @Suite
    struct Test {

        @Suite
        struct Unit {}

        @Suite
        struct `Edge Case` {}

        static func line(_ command: RFC_3501.Command) throws -> String {
            String(decoding: try [Byte](command, tag: RFC_3501.Tag(rawValue: "A1")).map(\.bitPattern), as: UTF8.self)
        }
    }
}

extension RFC_3501.Command.Test.Unit {

    @Test
    func `simple commands carry their tag and end in CRLF`() throws {
        #expect(try RFC_3501.Command.Test.line(.capability) == "A1 CAPABILITY\r\n")
        #expect(try RFC_3501.Command.Test.line(.logout) == "A1 LOGOUT\r\n")
    }

    @Test
    func `login quotes what is not an atom`() throws {
        #expect(try RFC_3501.Command.Test.line(.login(user: "me@example.com", password: "abcd-efgh")) == "A1 LOGIN me@example.com abcd-efgh\r\n")
        #expect(try RFC_3501.Command.Test.line(.login(user: "a b", password: "q\"x")) == "A1 LOGIN \"a b\" \"q\\\"x\"\r\n")
    }

    @Test
    func `list keeps wildcards and quotes an empty reference`() throws {
        #expect(try RFC_3501.Command.Test.line(.list(reference: "", pattern: "*")) == "A1 LIST \"\" *\r\n")
    }

    @Test
    func `examine names its mailbox`() throws {
        #expect(try RFC_3501.Command.Test.line(.examine(.inbox)) == "A1 EXAMINE INBOX\r\n")
        #expect(try RFC_3501.Command.Test.line(.examine(RFC_3501.Mailbox(rawValue: "Sent Messages"))) == "A1 EXAMINE \"Sent Messages\"\r\n")
    }

    @Test
    func `a UID search serializes its keys`() throws {
        let line = try RFC_3501.Command.Test.line(
            .search(uid: true, [.from("example.nl"), .since(RFC_3501.Date(year: 2024, month: 3, day: 1)), .not(.larger(1000))])
        )

        #expect(line == "A1 UID SEARCH FROM example.nl SINCE 1-Mar-2024 NOT LARGER 1000\r\n")
    }

    @Test
    func `or and grouped keys serialize`() throws {
        let line = try RFC_3501.Command.Test.line(.search(uid: false, [.or(.from("a"), .and([.to("b"), .subject("c d")]))]))

        #expect(line == "A1 SEARCH OR FROM a (TO b SUBJECT \"c d\")\r\n")
    }

    @Test
    func `a UID fetch serializes its set and attributes`() throws {
        let line = try RFC_3501.Command.Test.line(
            .fetch(uid: true, RFC_3501.SequenceSet(ranges: [.init(lower: 1, upper: 5), .init(lower: 9, upper: 9), .init(lower: 20, upper: nil)]),
                   [.uid, .rfc822Size, .body(.headerFields(["FROM", "SUBJECT"]), peek: true)])
        )

        #expect(line == "A1 UID FETCH 1:5,9,20:* (UID RFC822.SIZE BODY.PEEK[HEADER.FIELDS (FROM SUBJECT)])\r\n")
    }

    @Test
    func `a single fetch attribute has no parentheses`() throws {
        #expect(try RFC_3501.Command.Test.line(.fetch(uid: true, RFC_3501.SequenceSet([7]), [.body(.whole, peek: true)])) == "A1 UID FETCH 7 BODY.PEEK[]\r\n")
    }
}

extension RFC_3501.Command.Test.`Edge Case` {

    @Test
    func `a value needing a literal is refused`() {
        #expect(throws: RFC_3501.Command.Error.unquotable("café")) {
            try RFC_3501.Command.Test.line(.search(uid: true, [.subject("café")]))
        }
        #expect(throws: RFC_3501.Command.Error.unquotable("a\r\nb")) {
            try RFC_3501.Command.Test.line(.login(user: "a\r\nb", password: "x"))
        }
    }
}

@Suite struct `Command boundaries` {
    @Test func `header fields cannot inject a second command`() {
        #expect(throws: RFC_3501.Command.Error.self) {
            _ = try [Byte](.fetch(uid: true, RFC_3501.SequenceSet([1]), [.body(.headerFields(["FROM) ]\r\nZ STORE 1 +FLAGS (test)"]), peek: true)]), tag: RFC_3501.Tag(rawValue: "A"))
        }
    }
    @Test func `tags cannot inject a second command`() {
        #expect(throws: RFC_3501.Command.Error.self) {
            _ = try [Byte](.noop, tag: RFC_3501.Tag(rawValue: "A\r\nB"))
        }
    }
}
