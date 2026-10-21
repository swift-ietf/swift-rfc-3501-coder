import Byte
import RFC_3501
import RFC_3501_Coder
import Testing

extension RFC_3501.Body {
    @Suite struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension RFC_3501.Body.Test.Unit {
    @Test func `nested attachment preserves type and filename`() throws {
        let body = try RFC_3501.Body(
            binary: [Byte](
                utf8:
                    #"(("TEXT" "PLAIN" NIL NIL NIL "7BIT" 4 1)("APPLICATION" "OCTET-STREAM" NIL NIL NIL "BASE64" 8 NIL ("ATTACHMENT" ("FILENAME" "invoice.PDF"))) "MIXED")"#
            )
        )
        #expect(body.type == "multipart")
        #expect(body.parts.count == 2)
        #expect(body.parts.last?.parameters["filename"] == "invoice.PDF")
    }
    @Test func `a subject containing PDF is not a PDF part`() throws {
        let body = try RFC_3501.Body(
            binary: [Byte](utf8: #"("TEXT" "PLAIN" NIL NIL "invoice.pdf" "7BIT" 4 1)"#)
        )
        #expect(body.type == "text")
        #expect(body.parameters.isEmpty)
    }
}

extension RFC_3501.Body.Test.`Edge Case` {
    @Test func `truncated structure fails`() {
        #expect(throws: RFC_3501.Response.Error.self) {
            _ = try RFC_3501.Body(binary: [Byte](utf8: #"("APPLICATION" "PDF""#))
        }
    }
}
