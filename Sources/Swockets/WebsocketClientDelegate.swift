///
/// Created by Jake Barnby on 8/09/21.
///

import Foundation
import NIO
import NIOHTTP1

public protocol WebSocketClientDelegate {
    func onText(text: String)
    func onBinary(data: Data)
    func onClose(channel: Channel, data: Data)
    func onError(error: Error?, status: HTTPResponseStatus?)
}

extension WebSocketClientDelegate {
    func onText(text: String) {
    }

    func onBinary(data: Data) {
    }

    func onClose(channel: Channel, data: Data) {
    }

    func onError(error: Error?, status: HTTPResponseStatus?) {
    }
}
