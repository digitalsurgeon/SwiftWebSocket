//
//  response.swift
//  websocketserver
//
//  Created by Ahmad Mushtaq on 17/05/15.
//  Copyright (c) 2015 Ahmad Mushtaq. All rights reserved.
//

import Foundation

public class Response {
    
    public enum Code {
        case WebSocketHandShake
        case Ok
        case NotFound
        
        func code() -> String {
            switch self {
            case .WebSocketHandShake:
                return "101"
            case .Ok:
                return "200"
            case .NotFound:
                return "404"
            }
        }
        
        func description() -> String {
            switch self {
            case .WebSocketHandShake:
                return "Web Socket Protocol Handshake"
            case .Ok:
                return "Ok"
            case .NotFound:
                return "Not Found"
            }
        }
    }
    
    private var headers:        [String: String] = [:]
    private var socket:         GCDAsyncSocket
    private var responseCode:   Code = .Ok
    private var data:           NSData? = nil
    
    init(var socket: GCDAsyncSocket) {
        self.socket = socket
    }
    func setCode(var responseCode: Code) {
        self.responseCode = responseCode
    }
    func addHeader(var header: String, var value: String) {
        headers[header] = value
    }
    
    func set(var #data:NSData?) {
        self.data = data
    }
    
    func generateResponse() {
        
        var headerString = "HTTP/1.1 " + responseCode.code() + " " + responseCode.description() + "\r\n"
        
        for (header, value) in headers {
            headerString +=  "\(header): \(value)\r\n"
        }
        
        headerString += "\r\n"
        
        var responseData: NSMutableData = NSMutableData()
        if let header = headerString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
            responseData.appendData(header)
        }
        if let d = data {
            responseData.appendData(d)
        }
        
        socket.writeData(responseData, withTimeout: 10, tag: 110)
    }
}