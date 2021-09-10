///
/// Created by Jake Barnby on 9/09/21.
///

import NIO
import NIOHTTP1

class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {

    typealias InboundIn = HTTPClientResponsePart

    unowned var client: SwocketClient

    init(client: SwocketClient) {
        self.client = client
    }

    func channelActive(context: ChannelHandlerContext) {
        var request = HTTPRequestHead(version: HTTPVersion.http11, method: .GET, uri: client.uri)
        var headers = HTTPHeaders()
        headers.add(name: "Host", value: "\(client.host):\(client.port)")
        request.headers = headers
        context.channel.write(NIOAny(HTTPClientRequestPart.head(request)), promise: nil)
        context.channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil)), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)
        switch response {
        case .head(let header):
            upgradeFailure(status: header.status)
        case .body(_):
            break
        case .end(_):
            break
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if client.delegate != nil {
            client.delegate?.onError(error: error, status: nil)
        } else {
            client.onErrorCallBack(error, nil)
        }
    }
}

extension HTTPVersion {
    static let http11 = HTTPVersion(major: 1, minor: 1)
}
