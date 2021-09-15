///
/// Created by Jake Barnby on 8/09/21.
///

import Foundation
import NIO
import NIOHTTP1

public protocol SwocketClientDelegate : AnyObject {
    func onMessage(text: String)
    func onMessage(data: Data)
    func onClose(channel: Channel, data: Data)
    func onError(error: Error?, status: HTTPResponseStatus?)
}
