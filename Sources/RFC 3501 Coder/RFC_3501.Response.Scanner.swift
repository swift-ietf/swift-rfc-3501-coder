import RFC_3501

extension RFC_3501.Response {

    struct Scanner {

        let bytes: [UInt8]

        var position: Int
    }
}
