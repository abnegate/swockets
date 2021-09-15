//
// Created by Jake Barnby on 10/09/21.
//

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket

class MessageHandler {

    private let client: SwocketClient
    private var buffer: ByteBuffer
    private var binaryBuffer: Data = Data()
    private var isText: Bool = false
    private var string: String = ""

    public init(client: SwocketClient) {
        self.client = client
        self.buffer = ByteBufferAllocator().buffer(capacity: 0)
    }
    
    private func unmaskedData(frame: WebSocketFrame) -> ByteBuffer {
        var frameData = frame.data
        if let maskingKey = frame.maskKey {
            frameData.webSocketUnmask(maskingKey)
        }
        return frameData
    }
}

extension MessageHandler: ChannelInboundHandler, RemovableChannelHandler {

    typealias InboundIn = WebSocketFrame
    
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
                    delegate.onMessage(text: text)
                } else {
                    client.onTextMessage(text)
                }
            } else {
                isText = true
                guard let text = data.getString(at: 0, length: data.readableBytes) else {
                    return
                }
                string = text
            }
        case .binary:
            let data = unmaskedData(frame: frame)
            if frame.fin {
                guard let binaryData = data.getData(at: 0, length: data.readableBytes) else {
                    return
                }
                if let delegate = client.delegate {
                    delegate.onMessage(data: binaryData)
                } else {
                    client.onBinaryMessage(binaryData)
                }
            } else {
                guard let binaryData = data.getData(at: 0, length: data.readableBytes) else {
                    return
                }
                binaryBuffer = binaryData
            }
        case .continuation:
            let data = unmaskedData(frame: frame)
            if isText {
                if frame.fin {
                    guard let text = data.getString(at: 0, length: data.readableBytes) else {
                        return
                    }
                    string.append(text)
                    isText = false
                    if let delegate = client.delegate {
                        delegate.onMessage(text: string)
                    } else {
                        client.onTextMessage(string)
                    }
                } else {
                    guard let text = data.getString(at: 0, length: data.readableBytes) else {
                        return
                    }
                    string.append(text)
                }
            } else {
                if frame.fin {
                    guard let binaryData = data.getData(at: 0, length: data.readableBytes) else {
                        return
                    }
                    binaryBuffer.append(binaryData)
                    if let delegate = client.delegate {
                        delegate.onMessage(data: binaryBuffer)
                    } else {
                        client.onBinaryMessage(binaryBuffer)
                    }
                } else {
                    guard let binaryData = data.getData(at: 0, length: data.readableBytes) else {
                        return
                    }
                    binaryBuffer.append(binaryData)
                }
            }
        case .connectionClose:
            guard frame.fin else {
                return
            }
            let data = frame.data
            if !client.closeSent {
                client.close(data: frame.data.getData(at: 0, length: frame.data.readableBytes) ?? Data())
            }
            if let delegate = client.delegate {
                delegate.onClose(channel: context.channel, data: data.getData(at: 0, length: data.readableBytes)!)
            } else {
                client.onClose(context.channel, data.getData(at: 0, length: data.readableBytes)!)
            }
        default:
            break
        }
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
        if client.delegate != nil {
            client.delegate?.onError(error: error, status: nil)
        } else {
            client.onErrorCallBack(error, nil)
        }
        client.close()
    }
}
