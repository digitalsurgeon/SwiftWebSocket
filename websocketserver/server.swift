//
//  Server.swift
//  websocketserver
//
//  Created by Ahmad Mushtaq on 14/05/15.
//  Copyright (c) 2015 Ahmad Mushtaq. All rights reserved.
//

import Foundation

class Server : NSObject, GCDAsyncSocketDelegate {
    
    private var listenSocket    : GCDAsyncSocket             = GCDAsyncSocket()
    private var handlers        : [String: Handler]          = [:]
    private var sockets         : [GCDAsyncSocket] = []
    private var defaultHandler  : DefaultHttpHandler         = DefaultHttpHandler()
    
    func addHandler(var path:String, var handler: Handler) {
        handlers[path] = handler
    }
    
    func getHandler(var path:String) -> Handler? {
        let (p:String, h:Handler ) = filter(self.handlers, {
            path.hasPrefix( $0.0 )
        }).first!
        return h
    }
    


    
    func start(var port:UInt16) {
        listenSocket.setDelegate(self, delegateQueue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
        
        var err: NSError?
        if listenSocket.acceptOnInterface(nil, port: port, error: &err) {
            Swell.info ("Starting server on port \(port)")
        }
        else if err != nil {
            Swell.info("Error when trying to start server: \(err!.localizedDescription)")
        }
        
        NSRunLoop.mainRunLoop().run()
    }
    
    func stop() {
        listenSocket.disconnect()
    }
    
    func clientSocketDisconnected(socket: GCDAsyncSocket) {
    //    sockets.removeValueForKey(socket)
    }
    
    // GCDAsyncSocketDelegate methods
    func socket(socket: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket){
        Swell.info("Server - accepted new socket")
        sockets.append(newSocket)
        //sockets[newSocket] = defaultHandler
        newSocket.readDataWithTimeout(10, tag: 0)
    }
    
    func socket(socket: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        Swell.info("Server - read some data \(data.length) bytes")
        
        let request = Request(data: data)
        Swell.info("Server - \(request.path)")

        if let handler = getHandler(request.path) {
            //sockets[socket] = handler
            handler.handle(request, socket: socket)
        } else {
            defaultHandler.handle(request, socket: socket)
        }
        
    }
    
    func socket(socket:GCDAsyncSocket, didWriteDataWithTag: Int) {
        Swell.info("Server - did write data")
    }
    
    func socketDidDisconnect(sock: GCDAsyncSocket, withError err: NSError){
        Swell.info("Server - disconnected")
    }
    // GCDAsyncSocketDelegate methods
    
    class func getIFAddresses() -> [String] {
        var addresses = [String]()
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {
            
            // For each interface ...
            for (var ptr = ifaddr; ptr != nil; ptr = ptr.memory.ifa_next) {
                let flags = Int32(ptr.memory.ifa_flags)
                var addr = ptr.memory.ifa_addr.memory
                
                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                        
                        // Convert interface address to a human readable string:
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                                if let address = String.fromCString(hostname) {
                                    addresses.append(address)
                                }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return addresses
    }
}