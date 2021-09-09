///
/// Created by Jake Barnby on 9/09/21.
///

import NIO
import NIOHTTP1

class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {

}

extension HTTPVersion {
    static let http11 = HTTPVersion(major: 1, minor: 1)
}
