# swift-rfc-3501-coder

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Serializer and parser for the RFC 3501 (IMAP4rev1) types in swift-rfc-3501.

- Commands serialize to a tagged command line, with atoms and quoted strings as the grammar requires; a value that would need a literal is refused.
- `RFC_3501.Response.Stream` splits a byte stream into complete responses, literals (`{n}` followed by n octets) included.
- `RFC_3501.Response(binary:)` parses a response: continuation requests, tagged and untagged conditions with their response codes, CAPABILITY, FLAGS, LIST and LSUB, SEARCH, EXISTS, RECENT, EXPUNGE and FETCH (UID, FLAGS, INTERNALDATE, RFC822.SIZE and BODY sections, other items as raw octets).

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
