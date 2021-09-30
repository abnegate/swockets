///
/// Created by Jake Barnby on 9/09/21.
///

import NIO
import NIOHTTP1
import Foundation

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
    
    public typealias InboundIn = HTTPClientResponsePart
    public typealias OutboundOut = HTTPClientRequestPart
    
    func channelActive(context: ChannelHandlerContext) {
        var headers = HTTPHeaders()
        
        headers.add(name: "Host", value: "\(client.host):\(client.port)")
        headers.add(name: "Content-Type", value: "text/plain")
        headers.add(name: "Content-Length", value: "\(1)")
        
        let requestHead = HTTPRequestHead(
            version: .http1_1,
            method: .GET,
            uri: client.uri,
            headers: headers
        )
        
        context.write(wrapOutboundOut(.head(requestHead)), promise: nil)
        context.write(wrapOutboundOut(.body(.byteBuffer(ByteBuffer(string: "\r\n")))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let response = unwrapInboundIn(data)

        switch response {
        case .head(let header):
            print(String(describing: response))
            upgradeFailure(status: header.status)
            break
        case .body(var body):
            print(body.readString(length: body.readableBytes)!)
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
