///
/// Created by Jake Barnby on 9/09/21.
///

import NIO
import NIOHTTP1

class HTTPHandler {

    unowned var client: SwocketClient

    init(client: SwocketClient) {
        self.client = client
    }

    func upgradeFailure(status: HTTPResponseStatus) {
        if let delegate = client.delegate {
            switch status {
            case .badRequest:
                delegate.onError(error: SwocketClientError.badRequest, status: status)
            case .notFound:
                delegate.onError(error: SwocketClientError.notFound, status: status)
            default:
                break
            }
        } else {
            switch status {
            case .badRequest:
                client.onErrorCallBack(SwocketClientError.badRequest, status)
            case .notFound:
                client.onErrorCallBack(SwocketClientError.notFound, status)
            default:
                break
            }
        }
    }
}

extension HTTPHandler : ChannelInboundHandler, RemovableChannelHandler {
    
    typealias InboundIn = HTTPClientResponsePart
    
    func channelActive(context: ChannelHandlerContext) {
        var request = HTTPRequestHead(
            version: HTTPVersion(major: 1, minor: 1),
            method: .GET,
            uri: client.uri
        )
        
        var headers = HTTPHeaders()
        headers.add(
            name: "Host",
            value: "\(client.host):\(client.port)"
        )
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
