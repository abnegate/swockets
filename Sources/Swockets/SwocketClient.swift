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


public let SWOCKET_LOCKER_QUEUE = "SyncLocker"

public class SwocketClient {

    // MARK: - Properties
    let frameKey: String
    let host: String
    let port: Int
    let uri: String
    
    public var maxFrameSize: Int
    
    var channel: Channel? = nil
    var tlsEnabled: Bool = false
    var closeSent: Bool = false
    
    let upgradedSignalled = DispatchSemaphore(value: 0)
    let locker = DispatchQueue(label: SWOCKET_LOCKER_QUEUE)
    let threadGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    weak var delegate: SwocketClientDelegate? = nil

    public var isConnected: Bool {
        channel?.isActive ?? false
    }
    
    // MARK: - Stored callbacks
    
    private var onOpen: (Channel) -> Void = { _ in }

    private var _closeCallback: (Channel, Data) -> Void = { _,_ in }
    var onClose: (Channel, Data) -> Void {
        get {
            return locker.sync {
                return _closeCallback
            }
        }
        set {
            locker.sync {
                _closeCallback = newValue
            }
        }
    }

    private var _textCallback: (String) -> Void = { _ in }
    var onTextMessage: (String) -> Void {
        get {
            return locker.sync {
                return _textCallback
            }
        }
        set {
            locker.sync {
                _textCallback = newValue
            }
        }
    }
    
    private var _binaryCallback: (Data) -> Void = { _ in }
    var onBinaryMessage: (Data) -> Void {
        get {
            return locker.sync {
                return _binaryCallback
            }
        }
        set {
            locker.sync {
                _binaryCallback = newValue
            }
        }
    }
    
    private var _errorCallBack: (Error?, HTTPResponseStatus?) -> Void = { _,_ in }
    var onErrorCallBack: (Error?, HTTPResponseStatus?) -> Void {
        get {
            return locker.sync {
                return _errorCallBack
            }
        }
        set {
            locker.sync {
                _errorCallBack = newValue
            }
        }
    }
    
    // MARK: - Callback setters
    
    public func onMessage(_ callback: @escaping (String) -> Void) {
        onTextMessage = callback
    }

    public func onMessage(_ callback: @escaping (Data) -> Void) {
        onBinaryMessage = callback
    }

    public func onClose(_ callback: @escaping (Channel, Data) -> Void) {
        onClose = callback
    }

    public func onError(_ callback: @escaping (Error?, HTTPResponseStatus?) -> Void) {
        onErrorCallBack = callback
    }
    
    // MARK: - Constructors
    
    /// Create a new `WebSocketClient`.
    ///
    /// - parameters:
    ///     - host: Host name of the remote server
    ///     - port: Port number on which the remote server is listening
    ///     - uri : The "Request-URI" of the GET method, it is used to identify the endpoint of the WebSocket connection
    ///     - frameKey: The key sent by client which server has to include while building it's response. This helps ensure that the server does not accept connections from non-WebSocket clients.
    ///     - maxFrameSize : Maximum allowable frame size of WebSocket client is configured using this parameter.
    ///                      Default value is `14`.
    ///     - tlsEnabled: Is TLS enabled for this client.
    ///     - delegate: Delegate to handle message and error callbacks
    public init?(
        host: String,
        port: Int,
        uri: String,
        frameKey: String,
        maxFrameSize: Int = 14,
        tlsEnabled: Bool = false,
        delegate: SwocketClientDelegate? = nil,
        onOpen: @escaping (Channel?) -> Void = { _ in}
    ) {
        self.frameKey = frameKey
        self.host = host
        self.port = port
        self.uri = uri
        self.onOpen = onOpen
        self.maxFrameSize = maxFrameSize
        self.tlsEnabled = tlsEnabled
        self.delegate = delegate
        self.onOpen = onOpen
    }

    /// Create a new `WebSocketClient`.
    ///
    /// - parameters:
    ///     - url : The "Request-URl" of the GET method, it is used to identify the endpoint of the WebSocket
    ///     - delegate: Delegate to handle message and error callbacks.
    public init?(
        _ url: String,
        delegate: SwocketClientDelegate? = nil
    ) {
        self.frameKey = "test"
        let rawUrl = URL(string: url)
        self.host = rawUrl?.host ?? "localhost"
        self.port = rawUrl?.port ?? 8080
        self.uri = rawUrl?.path ?? "/"
        self.maxFrameSize = 24
        self.tlsEnabled = rawUrl?.scheme == "wss" || rawUrl?.scheme == "https"
        self.delegate = delegate
    }
    
    deinit {
        try! threadGroup.syncShutdownGracefully()
    }

    // MARK: - Open connection
    
    public func connect() throws {
        do {
            try openConnection()
        } catch {
            throw SwocketClientConnectionError.connectionFailed
        }
    }

    private func openConnection() throws {
        let socketOptions = ChannelOptions.socket(
            SocketOptionLevel(SOL_SOCKET),
            SO_REUSEPORT
        )
        
        let bootstrap = ClientBootstrap(group: threadGroup)
            .channelOption(socketOptions, value: 1)
            .channelInitializer(self.openChannel)
        
        try bootstrap
            .connect(host: self.host, port: self.port)
            .wait()
        
        self.upgradedSignalled.wait()
    }

    private func openChannel(channel: Channel) -> EventLoopFuture<Void> {
        let httpHandler = HTTPHandler(client: self)
        
        let basicUpgrader = NIOWebSocketClientUpgrader(
            requestKey: self.frameKey,
            maxFrameSize: 1 << self.maxFrameSize,
            automaticErrorHandling: false,
            upgradePipelineHandler: self.upgradePipelineHandler
        )
        
        let config: NIOHTTPClientUpgradeConfiguration = (upgraders: [basicUpgrader], completionHandler: { context in
            context.channel.pipeline.removeHandler(httpHandler, promise: nil)
        })
        
        return channel.pipeline.addHTTPClientHandlers(withClientUpgrade: config).flatMap { _ in
            return channel.pipeline.addHandler(httpHandler).flatMap { _ in
                if self.tlsEnabled {
                    let tlsConfig = TLSConfiguration.makeClientConfiguration()
                    let sslContext = try! NIOSSLContext(configuration: tlsConfig)
                    let sslHandler = try! NIOSSLClientHandler(context: sslContext, serverHostname: self.host)
                    return channel.pipeline.addHandler(sslHandler, position: .first)
                } else {
                    return channel.eventLoop.makeSucceededFuture(())
                }
            }
        }
    }

    private func upgradePipelineHandler(channel: Channel, response: HTTPResponseHead) -> EventLoopFuture<Void> {
        self.onOpen(channel)
        
        let handler = MessageHandler(client: self)
        
        if response.status == .switchingProtocols {
            self.channel = channel
            self.upgradedSignalled.signal()
        }
        
        return channel.pipeline.addHandler(handler)
    }

    // MARK: - Close connection
    
    /// Closes the connection
    ///
    /// - parameters:
    ///     - data: close frame payload, must be less than 125 bytes
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

    /// Sends binary-formatted data to the connected server in multiple frames
    ///
    /// - parameters:
    ///     - data: raw binary data to be sent in the frame
    ///     - opcode: Websocket opcode indicating type of the frame
    ///     - finalFrame: Whether the frame to be sent is the last one, by default this is set to `true`
    ///     - compressed: Whether to compress the current frame to be sent, by default compression is disabled
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

    /// Sends text-formatted data to the connected server in multiple frames
    ///
    /// - parameters:
    ///     - raw: raw text to be sent in the frame
    ///     - opcode: Websocket opcode indicating type of the frame
    ///     - finalFrame: Whether the frame to be sent is the last one, by default this is set to `true`
    ///     - compressed: Whether to compress the current frame to be sent, by default this set to `false`
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

    /// This function sends IOData(ByteBuffer) to the connected server
    ///
    /// - parameters:
    ///     - data: ByteBuffer-formatted to be sent in the frame
    ///     - opcode: Websocket opcode indicating type of the frame
    ///     - finalFrame: Whether the frame to be sent is the last one, by default this is set to `true`
    ///     - compressed: Whether to compress the current frame to be sent, by default this set to `false`
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
}
