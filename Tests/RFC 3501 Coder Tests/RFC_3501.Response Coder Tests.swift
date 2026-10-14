import Byte
import RFC_3501
import RFC_3501_Coder
import Testing

extension RFC_3501.Response {

    @Suite
    struct Test {

        @Suite
        struct Unit {}

        @Suite
        struct `Edge Case` {}

        static func parse(_ text: String) throws(RFC_3501.Response.Error) -> RFC_3501.Response {
            try RFC_3501.Response(binary: [Byte](utf8: text))
        }

        static func responses(_ chunks: [String]) -> [String] {
            var stream = RFC_3501.Response.Stream()
            var responses: [String] = []
            for chunk in chunks {
                stream.append([Byte](utf8: chunk))
                while let response = stream.next() {
                    responses.append(String(decoding: response.map(\.bitPattern), as: UTF8.self))
                }
            }
            return responses
        }
    }
}

extension RFC_3501.Response.Test.Unit {

    @Test
    func `a greeting with a capability code parses`() throws {
        let response = try RFC_3501.Response.Test.parse("* OK [CAPABILITY IMAP4rev1 IDLE] ready\r\n")

        #expect(response == .untagged(.condition(.init(status: .ok, code: .capability(["IMAP4rev1", "IDLE"]), text: "ready"))))
    }

    @Test
    func `a tagged completion parses`() throws {
        #expect(try RFC_3501.Response.Test.parse("A1 OK [READ-ONLY] EXAMINE completed\r\n")
            == .tagged(.init(rawValue: "A1"), .init(status: .ok, code: .readOnly, text: "EXAMINE completed")))
        #expect(try RFC_3501.Response.Test.parse("A2 NO login failed\r\n")
            == .tagged(.init(rawValue: "A2"), .init(status: .no, code: nil, text: "login failed")))
    }

    @Test
    func `mailbox data parses`() throws {
        #expect(try RFC_3501.Response.Test.parse("* 23 EXISTS\r\n") == .untagged(.exists(23)))
        #expect(try RFC_3501.Response.Test.parse("* OK [UIDVALIDITY 3857529045] UIDs valid\r\n")
            == .untagged(.condition(.init(status: .ok, code: .uidValidity(3857529045), text: "UIDs valid"))))
        #expect(try RFC_3501.Response.Test.parse("* FLAGS (\\Answered \\Seen)\r\n") == .untagged(.flags(["\\Answered", "\\Seen"])))
    }

    @Test
    func `list responses parse quoted and atom mailboxes`() throws {
        #expect(try RFC_3501.Response.Test.parse("* LIST (\\HasNoChildren) \"/\" \"Sent Messages\"\r\n")
            == .untagged(.list(.init(attributes: ["\\HasNoChildren"], delimiter: "/", mailbox: .init(rawValue: "Sent Messages")))))
        #expect(try RFC_3501.Response.Test.parse("* LIST () NIL INBOX\r\n")
            == .untagged(.list(.init(attributes: [], delimiter: nil, mailbox: .inbox))))
    }

    @Test
    func `search results parse`() throws {
        #expect(try RFC_3501.Response.Test.parse("* SEARCH 2 84 882\r\n") == .untagged(.search([2, 84, 882])))
        #expect(try RFC_3501.Response.Test.parse("* SEARCH\r\n") == .untagged(.search([])))
    }

    @Test
    func `a fetch with a literal body parses`() throws {
        let response = try RFC_3501.Response.Test.parse("* 12 FETCH (UID 4827 RFC822.SIZE 12 BODY[] {12}\r\nSubject: x\r\n FLAGS (\\Seen))\r\n")

        #expect(response == .untagged(.fetch(12, [
            .uid(4827),
            .rfc822Size(12),
            .body(.whole, origin: nil, data: [Byte](utf8: "Subject: x\r\n")),
            .flags(["\\Seen"]),
        ])))
    }

    @Test
    func `a header fields section and an origin parse`() throws {
        let response = try RFC_3501.Response.Test.parse("* 1 FETCH (BODY[HEADER.FIELDS (FROM SUBJECT)]<0> \"From: a\")\r\n")

        #expect(response == .untagged(.fetch(1, [.body(.headerFields(["FROM", "SUBJECT"]), origin: 0, data: [Byte](utf8: "From: a"))])))
    }

    @Test
    func `unknown fetch items are kept raw`() throws {
        let response = try RFC_3501.Response.Test.parse("* 1 FETCH (ENVELOPE (NIL \"subject\" ((NIL NIL \"a\" \"b\"))) UID 3)\r\n")

        #expect(response == .untagged(.fetch(1, [
            .other("ENVELOPE", [Byte](utf8: "(NIL \"subject\" ((NIL NIL \"a\" \"b\")))")),
            .uid(3),
        ])))
    }

    @Test
    func `a continuation request parses`() throws {
        #expect(try RFC_3501.Response.Test.parse("+ Ready for literal data\r\n") == .continuation("Ready for literal data"))
    }

    @Test
    func `the stream frames responses across chunks and literals`() {
        let responses = RFC_3501.Response.Test.responses([
            "* 1 EXISTS\r\n* 1 FETCH (BODY[] {5}\r\nab",
            "\r\nc)\r\nA1 OK",
            " done\r\n",
        ])

        #expect(responses == ["* 1 EXISTS\r\n", "* 1 FETCH (BODY[] {5}\r\nab\r\nc)\r\n", "A1 OK done\r\n"])
    }
}

extension RFC_3501.Response.Test.`Edge Case` {

    @Test
    func `an incomplete response stays in the stream`() {
        #expect(RFC_3501.Response.Test.responses(["* 1 FETCH (BODY[] {10}\r\nabc"]).isEmpty)
    }

    @Test
    func `a literal longer than the response is refused`() {
        #expect(throws: RFC_3501.Response.Error.self) {
            try RFC_3501.Response.Test.parse("* 1 FETCH (BODY[] {50}\r\nshort)\r\n")
        }
    }

    @Test
    func `an unknown status is refused`() {
        #expect(throws: RFC_3501.Response.Error.self) {
            try RFC_3501.Response.Test.parse("A1 MAYBE\r\n")
        }
    }

    @Test
    func `unknown untagged data is kept as text`() throws {
        #expect(try RFC_3501.Response.Test.parse("* ID NIL\r\n") == .untagged(.other("ID NIL")))
    }
}
