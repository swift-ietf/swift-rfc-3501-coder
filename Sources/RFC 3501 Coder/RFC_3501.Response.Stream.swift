public import RFC_3501

extension RFC_3501.Response {

    public struct Stream: Sendable {

        var buffer: [UInt8]

        public init() {
            self.buffer = []
        }
    }
}
