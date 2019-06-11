//
//  NFCMiFareTag.swift
//  NFCTagReader
//
//  Created by Alexander Heinrich on 10.06.19.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit
import CoreNFC

extension NFCMiFareTag {
    func selectApp(_ appId: Int, _ callback:@escaping ()->()) {
        
        
        var appIdBuff = Data()
        appIdBuff.append(contentsOf: [UInt8((appId & 0xFF0000) >> 16)])
        appIdBuff.append(contentsOf: [UInt8(((appId & 0xFF00) >> 8))])
        appIdBuff.append(contentsOf: [UInt8(appId & 0xFF)])
        
        sendCommand(withCommand: .SELECT_APPLICATION, andParameters: appIdBuff) { (data, err) in
            callback()
        }
    }
    
    
    func sendCommand(withMessage message: MiFareMessage, _ completion: @escaping (Data?, Error?)->()) {
        self.sendMiFareCommand(commandPacket: message.packet(), completionHandler: completion)
    }
    
    func sendCommand(withCommand cmd: MiFareCommand, andParameters params: Data?, _ completion: @escaping (Data?, Error?)->()) {
        let message = MiFareMessage(command: cmd.rawValue, parameters: params)
        sendCommand(withMessage: message, completion)
    }
    
    func getFileSettings(_ callback: @escaping (Int)->()) {
        
        var params = Data()
        params.append(1)
        
        sendCommand(withCommand: .GET_FILE_SETTINGS, andParameters: params) { (data, err) in
            //Parse bytes
            if let d = data,
                let parsed = ValueFileSettings(data: d) {
                callback(Int(parsed.value))
            }else {
                self.session?.invalidate(errorMessage: "Failed while reading last transaction")
            }
            
        }
        
    }
    
    
    func readValue(_ callback: @escaping (Int)->()) {
        var params = Data()
        params.append(1)
        
        sendCommand(withCommand: .readValue, andParameters: params) { (data, err) in
            
            if let d = data,
                d.count == 6 {
                //Reverse the data
                let valueData = d[0...4]
                //Get Int out of it
                let value = valueData.uint32
                callback(Int(value))
            }else {
                self.session?.invalidate(errorMessage: "Failed while reading value")
            }
        }
    }
    
}
