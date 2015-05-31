//
//  main.swift
//  websocketserver
//
//  Created by Ahmad Mushtaq on 14/05/15.
//  Copyright (c) 2015 Ahmad Mushtaq. All rights reserved.
//

import Foundation


var s:Server = Server()
var w:WebSocketHandler = WebSocketHandler()
s.addHandler("/webSocket", handler: w)
s.addHandler("/", handler: HttpHandler(webRoot:"/", folderPath: "/Volumes/MacDisk/work/websocketkeyboard/"))
s.start(8080)


