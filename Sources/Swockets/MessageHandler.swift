//
// Created by Jake Barnby on 10/09/21.
//

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket

class MessageHandler: ChannelInboundHandler, RemovableChannelHandler {
    
    typealias InboundIn = WebSocketFrame

    private let client: SwocketClient
    private var buffer: ByteBuffer
    private var binaryBuffer: Data = Data()
    private var isText: Bool = false
    private var string: String = ""

    public init(client: SwocketClient) {
        self.client = client
        self.buffer = ByteBufferAllocator().buffer(capacity: 0)
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        if client.delegate != nil {
            client.delegate?.onError(error: error, status: nil)
        } else {
            client.onErrorCallBack(error, nil)
        }
        client.close()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        switch frame.opcode {
        case .text:
            let data = unmaskedData(frame: frame)
            if frame.fin {
                guard let text = data.getString(at: 0, length: data.readableBytes) else {
                    return
                }
                if let delegate = client.delegate {
                    delegate.onText(text: text)
                } else {
                    client.onTextCallback(text)
                }
            } else {
                isText = true
                guard let text = data.getString(at: 0, length: data.readableBytes) else {
                    return
                }
                string = text
            }
        case .connectionClose:
            guard frame.fin else {
                return
            }
            let data = frame.data
            if let delegate = client.delegate {
                delegate.onClose(channel: context.channel, data: data.getData(at: 0, length: data.readableBytes)!)
            } else {
                client.onCloseCallback(context.channel, data.getData(at: 0, length: data.readableBytes)!)
            }
        default:
            break
        }
    }
    
    private func unmaskedData(frame: WebSocketFrame) -> ByteBuffer {
        var frameData = frame.data
        if let maskingKey = frame.maskKey {
            frameData.webSocketUnmask(maskingKey)
        }
        return frameData
    }
}
