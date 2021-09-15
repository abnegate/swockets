///
/// Created by Jake Barnby on 9/09/21.
///

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

enum SwocketClientConnectionError: Error {
    case connectionFailed(_ error: Error)
}
