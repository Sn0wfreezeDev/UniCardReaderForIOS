/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The view controller that scans and displays NDEF messages.
*/

import UIKit
import CoreNFC

/// - Tag: ndefReading_1
@available(iOS 13.0, *)
class MessagesTableViewController: UITableViewController, NFCNDEFReaderSessionDelegate {
    // MARK: - Properties

    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCTagReaderSession?
    var numberFormatter: NumberFormatter!

    // MARK: - Actions
    
    /// - Tag: beginScanning
    @IBAction func beginScanning(_ sender: Any) {
        self.numberFormatter = NumberFormatter()
        self.numberFormatter.currencyCode = Locale.current.currencyCode
        self.numberFormatter.currencySymbol = Locale.current.currencySymbol
        self.numberFormatter.minimumFractionDigits = 2
        self.numberFormatter.numberStyle = .currency
        
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.begin()
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Process detected NFCNDEFMessage objects
        detectedMessages.append(contentsOf: messages)
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // Check invalidation reason from the returned error. A new session instance is required to read new tags.
        if let readerError = error as? NFCReaderError {
            // Show alert dialog box when the invalidation reason is not because of a read success from the single tag read mode,
            // or user cancelled a multi-tag read mode session from the UI or programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                let alertController = UIAlertController(title: "Session Invalidated", message: error.localizedDescription, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    func showCurrentAmount(value: Double, lastTransaction: Double) {
        let valueString = numberFormatter.string(from: NSNumber(value: value))
        let lastString = numberFormatter.string(from: NSNumber(value: lastTransaction))
        
        let title = NSLocalizedString("Current Mensa card value", comment: "")
        let message = String(format: NSLocalizedString("The current value on your card is %@.\n\n Your last transaction was %@", comment: ""), valueString!, lastString!)
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Okay", comment: ""), style: .default, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
}

extension MessagesTableViewController:  NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("Session did become active")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("Session invalidated with error \(error)")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("Detected tags \(tags)")
        
        switch tags.first! {
        case let .miFare(tag):
            //1. Connect to the TAG
            session.connect(to: tags.first!) { (error) in
                guard error == nil else {
                    print("Error connecting to tag \(error!)")
                    return
                }
                print("Connected to tag")
                
                //Start in the right app
                self.selectApp(0x5F8415, onTag: tag, {
                    self.getFileSettings(onTag: tag) { lastTransaction in
                        self.readValue(ofTag: tag) { value in
                            let decimalTransaction = Double(lastTransaction) / Double(1000)
                            let decimalValue = Double(value) / Double(1000)
                            
                            self.session?.invalidate()
                            
                            DispatchQueue.main.async {
                                self.showCurrentAmount(value: decimalValue, lastTransaction: decimalTransaction)
                            }
                            
                            
                        }
                    }
                })
                
            }
            
        default:
            break
        }
        

        
        
        
        //2. send request to select App
//        appId = 0
//        byte[] appIdBuff = new byte[3];
//        appIdBuff[0] = (byte) ((appId & 0xFF0000) >> 16);
//        appIdBuff[1] = (byte) ((appId & 0xFF00) >> 8);
//        appIdBuff[2] = (byte) (appId & 0xFF);
//
//        sendRequest(0x5A, appIdBuff);
    }
    
    func selectApp(_ appId: Int, onTag tag: NFCMiFareTag, _ callback:@escaping ()->()) {
        
        
        var appIdBuff = Data()
        appIdBuff.append(contentsOf: [UInt8((appId & 0xFF0000) >> 16)])
        appIdBuff.append(contentsOf: [UInt8(((appId & 0xFF00) >> 8))])
        appIdBuff.append(contentsOf: [UInt8(appId & 0xFF)])
        
        sendCommand(withCommand: .SELECT_APPLICATION, andParameters: appIdBuff, toTag: tag) { (data, err) in
            print(data?.toByteArray())
            print("Error: \(err)")
            callback()
        }
    }
    
    func getFileSettings(onTag tag: NFCMiFareTag,_ callback: @escaping (Int)->()) {

        var params = Data()
        params.append(1)
        
        sendCommand(withCommand: .GET_FILE_SETTINGS, andParameters: params, toTag: tag) { (data, err) in
            print(data?.toByteArray())
            print("Error: \(err)")
            
            //Parse bytes
            if let d = data,
                let parsed = ValueFileSettings(data: d) {
                callback(Int(parsed.value))
            }else {
                self.session?.invalidate(errorMessage: "Failed while reading last transaction")
            }
            
        }
        
    }
    
    func readValue(ofTag tag: NFCMiFareTag,_ callback: @escaping (Int)->()) {
        var params = Data()
        params.append(1)
        
        sendCommand(withCommand: .readValue, andParameters: params, toTag: tag) { (data, err) in
            
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
    
    func sendCommand(withMessage message: MiFareMessage, toTag tag: NFCMiFareTag, _ completion: @escaping (Data?, Error?)->()) {
        tag.sendMiFareCommand(commandPacket: message.packet(), completionHandler: completion)
    }
    
    func sendCommand(withCommand cmd: MiFareCommand, andParameters params: Data?,toTag tag: NFCMiFareTag, _ completion: @escaping (Data?, Error?)->()) {
        let message = MiFareMessage(command: cmd.rawValue, parameters: params)
        sendCommand(withMessage: message, toTag: tag, completion)
    }
    
}

struct MiFareMessage {
    let command: UInt8
    let parameters: Data?
    
    func packet() -> Data {
        var packet = Data()
        packet.append(0x90)
        packet.append(command)
        packet.append(0x00)
        packet.append(0x00)
        
        if let parameters = self.parameters {
            packet.append(UInt8(parameters.count))
            packet.append(parameters)
        }
        packet.append(0x00)
        return packet
    }
}

enum MiFareCommand: UInt8 {
    case GET_MANUFACTURING_DATA = 0x60
    case GET_APPLICATION_DIRECTORY = 0x6A
    case GET_ADDITIONAL_FRAME = 0xAF
    case SELECT_APPLICATION = 0x5A
    case GET_FILES = 0x6F
    case GET_FILE_SETTINGS = 0xF5
    case readValue = 0x6C
}

enum MiFareStatusCodes: UInt8 {
    case operationOK = 0x00
    case permissionDenied = 0x9D
    case additionalFrame = 0xAF
}

extension Data {
    func toByteArray() -> [UInt8] {
        // create an array of Uint8
        var byteArray = [UInt8](repeating: 0, count: self.count)
        // copy bytes into array
        self.copyBytes(to: &byteArray, count: count)
        return byteArray
    }
    
    var uint32: UInt32 {
        get {
            let i32array = self.withUnsafeBytes {
                UnsafeBufferPointer<UInt32>(start: $0, count: self.count/2).map(UInt32.init(littleEndian:))
            }
            return i32array[0]
        }
    }
}

class MiFareFileSettings {
    enum FileType: UInt8 {
        case standardData = 0x00
        case backupData = 0x01
        case valueFile = 0x02
        case linearRecordFile = 0x03
        case cyclicRecordFile = 0x04
    }
    let fileType: FileType
    let commSettings: UInt8
    let accessRights: [UInt8]
    var currentReadIndex = 0
    
    init?(data: Data) {
        guard data.count > 3,
            let type = FileType(rawValue: data[0]) else {return nil}
        currentReadIndex += 1

        self.fileType = type
        self.commSettings = data[1]
        currentReadIndex += 1
        self.accessRights = data[2...3].toByteArray()
        currentReadIndex += 2
    }
}

class ValueFileSettings: MiFareFileSettings {
    var lowerLimit: UInt32 = 0
    var upperLimit: UInt32 = 0
    var value: UInt32 = 0
    var limitedCreditEnabled: UInt8 = 0
    
    override init?(data: Data) {
        super.init(data: data)
        
        
        guard currentReadIndex + 4 < data.count else {return nil}
        let lowerLimitData = data[currentReadIndex...currentReadIndex+4]
        currentReadIndex += 4
        self.lowerLimit = lowerLimitData.uint32
        
//        self.lowerLimit = UInt32(bigEndian: lowerLimitData.withUnsafeBytes({$0.baseAddress}))
        guard currentReadIndex + 4 < data.count else {return nil}
        let upperLimitData = data[currentReadIndex...currentReadIndex+4]
        currentReadIndex += 4
        self.upperLimit = upperLimitData.uint32
        
        guard currentReadIndex + 4 < data.count else {return nil}
        let valueData = data[currentReadIndex...currentReadIndex+4]
        currentReadIndex += 4
        self.value = valueData.uint32
        
        guard currentReadIndex < data.count else {return nil}
        self.limitedCreditEnabled = data[currentReadIndex]
        
    }
    
}

