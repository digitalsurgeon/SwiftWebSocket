//
//  websockethandler.swift
//  websocketserver
//
//  Created by Ahmad Mushtaq on 17/05/15.
//  Copyright (c) 2015 Ahmad Mushtaq. All rights reserved.
//  Portions of this code from the Qt Websockets library
//   qwebsockets git at http://code.qt.io/cgit/qt/qtwebsockets.git/

import Foundation

@objc(WebSocketHandler)
class WebSocketHandler: Handler {
    
    enum ProcessingState
    {
        case PS_READ_HEADER
        case PS_READ_PAYLOAD_LENGTH
        case PS_READ_BIG_PAYLOAD_LENGTH
        case PS_READ_MASK
        case PS_READ_PAYLOAD
        case PS_DISPATCH_RESULT
        case PS_WAIT_FOR_MORE_DAT
    }
    
    enum OpCode: UInt8
    {
        case OpCodeContinue    = 0x0
        case OpCodeText        = 0x1
        case OpCodeBinary      = 0x2
        case OpCodeReserved3   = 0x3
        case OpCodeReserved4   = 0x4
        case OpCodeReserved5   = 0x5
        case OpCodeReserved6   = 0x6
        case OpCodeReserved7   = 0x7
        case OpCodeClose       = 0x8
        case OpCodePing        = 0x9
        case OpCodePong        = 0xA
        case OpCodeReservedB   = 0xB
        case OpCodeReservedC   = 0xC
        case OpCodeReservedD   = 0xD
        case OpCodeReservedE   = 0xE
        case OpCodeReservedF   = 0xF
    }
    
    func messageReceived(var frame: WebSocketFrame) {
        Swell.info("Message received: \(frame.payLoad)")
    }
    
    func messageSent(var tag:Int, success: Bool) {
        Swell.info("Message with tag \(tag) sent: \(success)")
    }
    
    func connected() {
        Swell.info("Connected")
    }
    
    func disconnected() {
        Swell.info("Disconnected")
    }
    
    
    func send(var data:NSData, var tag: Int) {
        
        //maximum size of a frame when sending a message
        let FRAME_SIZE_IN_BYTES = 512 * 512 * 2;
        
        //currently only support text messages
        let firstOpCode:OpCode = .OpCodeText
        
        var numFrames = (data.length / FRAME_SIZE_IN_BYTES)
        if numFrames == 0 {
            numFrames = 1
        }
        
        var bytesWritten = 0
        
        for (var i = 0; i < numFrames; ++i) {
            var maskingKey:UInt32 = 0 //generateMaskingKey();
            
            let isLastFrame = (i == (numFrames - 1))
            let isFirstFrame = (i == 0)
            
            let opcode = isFirstFrame ? firstOpCode : .OpCodeContinue;
            
            var header: NSMutableData = NSMutableData(data: getFrameHeader(opcode, payloadLength: UInt64(data.length), maskingKey: maskingKey, lastFrame: isLastFrame))
            var buffer:[UInt8] = [UInt8] (count: data.length, repeatedValue: 0)
            data.getBytes(&buffer, length: buffer.count)
            
            //web socket server does not mask the data it sends.
            //applyMask(&buffer, payloadSize: buffer.count, maskingKey: maskingKey)
            
            header.appendBytes(&buffer, length: buffer.count)
            socket!.writeData(header, withTimeout: 10, tag: tag)
            
        }
        
    }
    
    override func handle(var request:Request, var socket: GCDAsyncSocket)
    {
        super.handle(request, socket: socket)
        Swell.info("WSH - Handling web socket")
        
        if let webSocketKey = request.headers["Sec-WebSocket-Key"] {
            var webSocketResponseKey = generateWebSocketAcceptKey(webSocketKey + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
            Swell.info("websocket response key:" + webSocketResponseKey)
            
            var response = Response(socket: socket)
            response.setCode(Response.Code.WebSocketHandShake)
            response.addHeader("Sec-WebSocket-Accept", value: webSocketResponseKey)
            response.addHeader("Connection", value: "Upgrade")
            response.addHeader("Upgrade", value: "websocket")
            response.generateResponse()
            
            socket.readDataWithTimeout(-1, tag: 0)
        }
    }
    
    func generateWebSocketAcceptKey(var s:String) -> String {
        let str = s.cStringUsingEncoding(NSUTF8StringEncoding)
        let strLen = CUnsignedInt(s.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        let digestLen = Int(CC_SHA1_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<UInt8>.alloc(digestLen)
        
        CC_SHA1(str!, strLen, result)
        
        var ns:NSData = NSData(bytes: result, length: digestLen)
        var key = ns.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(0))
        
        result.destroy()
        return key
    }
    
    func getFrameHeader(var opCode:OpCode, var payloadLength:UInt64, var maskingKey:UInt32,
        var lastFrame:Bool) -> NSData
    {
        var header = NSMutableData()
        var byte:UInt8 = (opCode.rawValue & 0x0F) | (lastFrame ? 0x80 : 0x00)
        
        header.appendBytes(&byte, length: 1)
        
        byte = 0x00
        if maskingKey != 0 {
            byte |= 0x80
        }
        if payloadLength <= 125 {
            byte |= UInt8(payloadLength)
            header.appendBytes(&byte, length:1)
        } else if payloadLength <= 0xFFFF {
            byte |= 126
            header.appendBytes(&byte, length: 1)
            var swapped = UInt16(payloadLength).bigEndian
            header.appendBytes(&swapped, length:2);
        } else if payloadLength <= 0x7FFFFFFFFFFFFFFF {
            byte |= 127
            header.appendBytes(&byte, length: 1)
            var swapped = UInt64(payloadLength).bigEndian
            header.appendBytes(&swapped, length: 8);
        }
        
        if maskingKey != 0 {
            var mask = maskingKey.bigEndian
            header.appendBytes(&mask, length: 4)
        }
        
        return header
    }
    
    func generateMaskingKey() -> UInt32 {
        return UInt32(arc4random_uniform(UInt32.max)+1)
    }
    
    func applyMask( inout payload: [UInt8], var payloadSize: Int, var maskingKey:UInt32 ) {
        
        var mask: [UInt8] = [ UInt8((maskingKey & 0xFF000000) >> 24),
            UInt8((maskingKey & 0x00FF0000) >> 16),
            UInt8((maskingKey & 0x0000FF00) >> 8),
            UInt8((maskingKey & 0x000000FF))
        ]
        
        for var i = 0; i < payloadSize; ++i {
            payload[i] ^= mask[i % 4]
        }
        
    }
    
    struct WebSocketFrame {
        var isFinalFrame: Bool
        var opCode: OpCode
        var payLoad: NSData?
    }
    
    func parseWebSocketIncomingFrame(data: NSData) -> WebSocketFrame? {
        
        var processingState = ProcessingState.PS_READ_HEADER;
        
        var payloadLength:UInt64 = 0
        var mask : UInt32 = 0
        var index: Int = 0
        var isFinalFrame: Bool = false
        var hasMask: Bool = false
        var payload: NSData? = nil
        var opCode:OpCode = OpCode.OpCodeText
        
        
        while processingState != .PS_DISPATCH_RESULT {
            switch processingState {
            case .PS_READ_HEADER:
                var buffer = [UInt8](count: 2, repeatedValue: 0);
                data.getBytes(&buffer, range: NSRange(location: index, length:buffer.count))
                index += buffer.count
                
                isFinalFrame = (buffer[0] & 0x80) != 0
                // don't care about rsv values.
                //var rsv1 = (buffer[0] & 0x40);
                //var rsv2 = (buffer[0] & 0x20);
                //var rsv3 = (buffer[0] & 0x10);
                opCode = OpCode(rawValue: buffer[0] & 0x0F)!;
                
                hasMask = (buffer[1] & 0x80) != 0;
                var frame_length:UInt8 = (buffer[1] & 0x7F);
                
                switch frame_length
                {
                case 126:
                    processingState = .PS_READ_PAYLOAD_LENGTH;
                case 127:
                    processingState = .PS_READ_BIG_PAYLOAD_LENGTH;
                default:
                    payloadLength = UInt64 (frame_length);
                    processingState = hasMask ? .PS_READ_MASK : .PS_READ_PAYLOAD;
                }
                
            case .PS_READ_PAYLOAD_LENGTH:
                var buffer = [UInt8](count: 2, repeatedValue: 0);
                data.getBytes(&buffer, range: NSRange(location: index, length:buffer.count))
                index += buffer.count
                
                let u16 = UnsafePointer<UInt16>(buffer).memory.bigEndian
                payloadLength = UInt64(u16)
                if payloadLength < 126 {
                    //see http://tools.ietf.org/html/rfc6455#page-28 paragraph 5.2
                    //"in all cases, the minimal number of bytes MUST be used to encode
                    //the length, for example, the length of a 124-byte-long string
                    //can't be encoded as the sequence 126, 0, 124"
                    
                    // some error situation. but I dont care about this.
                    
                    processingState = .PS_DISPATCH_RESULT
                } else {
                    processingState = hasMask ? .PS_READ_MASK : .PS_READ_PAYLOAD;
                }
                
                
            case .PS_READ_BIG_PAYLOAD_LENGTH:
                var buffer = [UInt8](count: 8, repeatedValue: 0);
                data.getBytes(&buffer, range: NSRange(location: index, length:buffer.count))
                index += buffer.count
                
                let u64 = UnsafePointer<UInt64>(buffer).memory.bigEndian
                payloadLength = UInt64(u64)
                
            case .PS_READ_MASK:
                var buffer = [UInt8](count: 4, repeatedValue: 0);
                data.getBytes(&buffer, range: NSRange(location: index, length:buffer.count))
                index += buffer.count
                
                let u32 = UnsafePointer<UInt32>(buffer).memory.bigEndian
                mask =  UInt32(u32)
                processingState = .PS_READ_PAYLOAD
                
            case .PS_READ_PAYLOAD:
                var buffer = [UInt8](count: Int(payloadLength), repeatedValue: 0)
                data.getBytes(&buffer, range: NSRange(location: index, length:buffer.count))
                
                applyMask(&buffer, payloadSize: buffer.count, maskingKey: mask)
                
                payload =  NSData(bytes: &buffer, length: buffer.count)
                processingState = .PS_DISPATCH_RESULT
                
            default:
                Swell.info("default case in parseWebSocketIncomingFrame")
                return nil
            }
        }
        
        return WebSocketFrame(isFinalFrame: isFinalFrame, opCode: opCode, payLoad: payload)
        
    }
    
    func socket(socket: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        Swell.info("WSH - Read some data. length:\(data.length)")
        let frame: WebSocketFrame? = parseWebSocketIncomingFrame(data)
        if let f = frame {
            
            switch f.opCode {
            case .OpCodeClose:
                disconnect()
            default:
                messageReceived(f)
                socket.readDataWithTimeout(-1, tag: 0)
            }
        }
        
    }
    
    func socket(socket:GCDAsyncSocket, didWriteDataWithTag: Int) {
        Swell.info("WSH - Did write data witg tag " + String(didWriteDataWithTag))
        messageSent(didWriteDataWithTag, success: true)
    }
    
    func socket(sock: GCDAsyncSocket!, shouldTimeoutWriteWithTag tag: Int, elapsed: NSTimeInterval, bytesDone length: UInt) -> NSTimeInterval {
        messageSent(tag, success: false)
        return 0
    }
    
    func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        disconnected()
    }
}
