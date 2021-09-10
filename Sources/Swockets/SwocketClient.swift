///
/// Created by Jake Barnby on 8/09/21.
///

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import Dispatch
import NIOFoundationCompat
import NIOSSL

public class SwocketClient {

    let host: String
    let port: Int
    let uri: String
    var channel: Channel? = nil
    public var maxFrameSize: Int
    var tlsEnabled: Bool = false

    let callbackQueue = DispatchQueue(label: "CallbackSync")

    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    public var delegate: WebSocketClientDelegate? = nil

    var closeSent: Bool = false

    public var isConnected: Bool {
        channel?.isActive ?? false
    }
    
    // MARK: - Stored callbacks
    
    var onOpenCallback: (Channel) -> Void = { _ in }

    var _closeCallback: (Channel, Data) -> Void = { _,_ in }

    var onCloseCallback: (Channel, Data) -> Void {
        get {
            return callbackQueue.sync {
                return _closeCallback
            }
        }
        set {
            callbackQueue.sync {
                _closeCallback = newValue
            }
        }
    }

    var _textCallback: (String) -> Void = { _ in }

    var onTextCallback: (String) -> Void {
        get {
            return callbackQueue.sync {
                return _textCallback
            }
        }
        set {
            callbackQueue.sync {
                _textCallback = newValue
            }
        }
    }
    
    var _binaryCallback: (Data) -> Void = { _ in }

    var onBinaryCallback: (Data) -> Void {
        get {
            return callbackQueue.sync {
                return _binaryCallback
            }
        }
        set {
            callbackQueue.sync {
                _binaryCallback = newValue
            }
        }
    }
    
    var _errorCallBack: (Error?, HTTPResponseStatus?) -> Void = { _,_ in }

    var onErrorCallBack: (Error?, HTTPResponseStatus?) -> Void {
        get {
            return callbackQueue.sync {
                return _errorCallBack
            }
        }
        set {
            callbackQueue.sync {
                _errorCallBack = newValue
            }
        }
    }
    
    // MARK: - Constructors
    
    public init?(
        host: String,
        port: Int,
        uri: String,
        requestKey: String,
        maxFrameSize: Int = 14,
        tlsEnabled: Bool = false,
        onOpen: @escaping (Channel?) -> Void = { _ in}
    ) {
        self.host = host
        self.port = port
        self.uri = uri
        self.onOpenCallback = onOpen
        self.maxFrameSize = maxFrameSize
        self.tlsEnabled = tlsEnabled
    }

    public init?(_ url: String) {
        let rawUrl = URL(string: url)
        self.host = rawUrl?.host ?? "localhost"
        self.port = rawUrl?.port ?? 8080
        self.uri = rawUrl?.path ?? "/"
        self.maxFrameSize = 24
        self.tlsEnabled = rawUrl?.scheme == "wss" || rawUrl?.scheme == "https"
    }

    // MARK: - Open connection
    
    public func connect() throws {
        do {
            try makeConnection()
        } catch {
            throw SwocketClientConnectionError.connectionFailed
        }
    }

    private func makeConnection() throws {
    }

    // MARK: - Close connection
    
    public func close(data: Data = Data()) {
        closeSent = true
        
        var buffer = ByteBufferAllocator()
            .buffer(capacity: data.count)
        
        buffer.writeBytes(data)
        
        send(
            data: buffer,
            opcode: .connectionClose,
            finalFrame: true
        )
    }
    
    // MARK: - Send data

    public func send(
        binary: Data,
        opcode: WebSocketOpcode = .binary,
        finalFrame: Bool = true
    ) {
        var buffer = ByteBufferAllocator()
            .buffer(capacity: binary.count)
        
        buffer.writeBytes(binary)
        
        send(
            data: buffer,
            opcode: opcode,
            finalFrame: finalFrame
        )
    }

    public func send(
        text: String,
        opcode: WebSocketOpcode = .text,
        finalFrame: Bool = true
    ) {
        var buffer = ByteBufferAllocator()
            .buffer(capacity: text.count)
        
        buffer.writeString(text)
        
        send(
            data: buffer,
            opcode: opcode,
            finalFrame: finalFrame
        )
    }

    public func send<T: Codable>(
        model: T,
        opcode: WebSocketOpcode = .text,
        finalFrame: Bool = true
    ) {
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(model)
            let string = String(data: jsonData, encoding: .utf8)!
            var buffer = ByteBufferAllocator()
                .buffer(capacity: string.count)
            
            buffer.writeString(string)
            
            send(
                data: buffer,
                opcode: opcode,
                finalFrame: finalFrame
            )
        } catch let error {
            print(error)
        }
    }

    public func send(
        data: Data,
        opcode: WebSocketOpcode,
        finalFrame: Bool = true
    ) {
        var buffer = ByteBufferAllocator()
            .buffer(capacity: data.count)
        
        buffer.writeBytes(data)
        
        if opcode == .connectionClose {
            self.closeSent = true
        }
        
        send(
            data: buffer,
            opcode: opcode,
            finalFrame: finalFrame
        )
    }

    private func send(
        data: ByteBuffer,
        opcode: WebSocketOpcode,
        finalFrame: Bool
    ) {
        let frame = WebSocketFrame(
            fin: finalFrame,
            opcode: opcode,
            maskKey: nil,
            data: data
        )
        
        guard let channel = channel else {
            return
        }
        
        if finalFrame {
            channel.writeAndFlush(frame, promise: nil)
        } else {
            channel.write(frame, promise: nil)
        }
    }


    // MARK: - Callback setters
    
    public func onMessage(_ callback: @escaping (String) -> Void) {
        onTextCallback = callback
    }

    public func onMessage(_ callback: @escaping (Data) -> Void) {
        onBinaryCallback = callback
    }

    public func onClose(_ callback: @escaping (Channel, Data) -> Void) {
        onCloseCallback = callback
    }

    public func onError(_ callback: @escaping (Error?, HTTPResponseStatus?) -> Void) {
        onErrorCallBack = callback
    }
}
