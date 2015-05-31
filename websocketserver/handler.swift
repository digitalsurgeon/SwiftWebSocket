//
//  handler.swift
//  websocketserver
//
//  Created by Ahmad Mushtaq on 17/05/15.
//  Copyright (c) 2015 Ahmad Mushtaq. All rights reserved.
//

import Foundation

@objc(Handler)
class Handler : GCDAsyncSocketDelegate {
    var socket: GCDAsyncSocket? = nil
    func handle(var request:Request, var socket: GCDAsyncSocket) {
        self.socket = socket;
        socket.synchronouslySetDelegate(self)
    }
    func disconnect() {
        socket?.disconnect()
    }
}

@objc(HttpHandler)
class HttpHandler : Handler {
    
    let folderPath  : String
    let webRoot     : String
    
    init (webRoot: String, folderPath: String) {
        self.webRoot = webRoot
        self.folderPath = folderPath
    }
    
    override func handle(var request:Request, var socket: GCDAsyncSocket)
    {
        super.handle(request, socket: socket)
        Swell.info("Http request for " + request.path)
        request.path.removeRange(webRoot.startIndex...webRoot.endIndex.predecessor())
        if request.path.isEmpty {
            request.path = "index.html"
        }
        let filePath = folderPath + request.path
        let fileExists = NSFileManager.defaultManager()
            .fileExistsAtPath(filePath)
        
        var response = Response(socket: socket)
        response.setCode( fileExists ? .Ok : .NotFound )
        if fileExists {
            
            response.setCode(.Ok)
            if request.path == "index.html" {
                
                var err: NSError
                if let data = NSMutableString(contentsOfFile: filePath, encoding: NSUTF8StringEncoding, error: nil) {
                    
                    data.replaceOccurrencesOfString("$IP", withString: Server.getIFAddresses().first!, options: NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, data.length))
                    
                    response.set(data: data.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false))
                }
            } else {
                response.set(data:NSData(contentsOfFile: filePath))
            }
            
            
        } else {
            response.setCode(.NotFound)
        }
        response.generateResponse()
        disconnect()
    }
}

@objc(DefaultHttpHandler)
class DefaultHttpHandler:HttpHandler {
    init () {
        super.init(webRoot: "", folderPath: "")
    }
    
    override func handle(request: Request, socket: GCDAsyncSocket) {
        Swell.info("DefaultHttpHandler - handle")
        let response = Response(socket:socket)
        response.setCode(.NotFound)
        response.generateResponse()
        disconnect()
    }
}