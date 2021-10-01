/// Error mapped HTTP codes
enum SwocketClientError: UInt, Error {
    case notFound = 404
    case badRequest = 400

    func code() -> UInt? {
        switch self {
        case .notFound:
            return 404
        case .badRequest:
            return 400
        }
    }
}
