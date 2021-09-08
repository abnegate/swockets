///
/// Created by Jake Barnby on 8/09/21.
///

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import Dispatch
import WebSocketCompression
import NIOFoundationCompat
import NIOSSL

public class WebSocketClient {

    let host: String
    let port: Int
    let uri: String
    var channel: Channel? = nil
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    // MARK: - Stored callbacks
    
    /// Note: setter and getters of callback functions need to be synchronized to avoid TSan errors
    var onOpenCallback: (Channel) -> Void?
    var onOpenCallback: (Channel, Data) -> Void {
        get {
            callBackSync.sync {
                _closeCallback
            }
        }
        set {
            callbackQueue.sync {
                _closeCallback = newValue
            }
        }
    }

    var _closeCallback: (Channel, Data) -> Void?
    var onCloseCallback: (Channel, Data) -> Void {
        get {
            callBackSync.sync {
                _closeCallback
            }
        }
        set {
            callbackQueue.sync {
                _closeCallback = newValue
            }
        }
    }

    var _textCallback: (String) -> Void?
    var onTextCallback: (String) -> Void {
        get {
            callBackSync.sync {
                _textCallback
            }
        }
        set {
            callbackQueue.sync {
                _textCallback = newValue
            }
        }
    }

    var _binaryCallback: (Data) -> Void?
    var onBinaryCallback: (Data) -> Void {
        get {
            callBackSync.sync {
                _binaryCallback
            }
        }
        set {
            callbackQueue.sync {
                _binaryCallback = newValue
            }
        }
    }

    var _errorCallBack: (Error?, HTTPResponseStatus?) -> Void?
    var onErrorCallBack: (Error?, HTTPResponseStatus?) -> Void {

        get {
            callBackSync.sync {
                _errorCallBack
            }
        }
        set {
            _ = callbackQueue.sync {
                _errorCallBack = newValue
            }
        }
    }
    
    // MARK: - Open connection
    
    public func connect() throws {
    }

    // MARK: - Close connection
    
    public func close() {
    }
    
    // MARK: - Send data

    public func send(
        binary: Data,
        opcode: WebSocketOpcode = .binary,
        finalFrame: Bool = true,
        compressed: Bool = false
    ) {
    }

    public func send(
        text: String,
        opcode: WebSocketOpcode = .text,
        finalFrame: Bool = true,
        compressed: Bool = false
    ) {
    }

    public func send<T: Codable>(
        model: T,
        opcode: WebSocketOpcode = .text,
        finalFrame: Bool = true,
        compressed: Bool = false
    ) {
    }

    public func send(
        data: Data,
        opcode: WebSocketOpcode,
        finalFrame: Bool = true,
        compressed: Bool = false
    ) {
    }

    private func send(data: ByteBuffer, opcode: WebSocketOpcode, finalFrame: Bool, compressed: Bool) {
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
