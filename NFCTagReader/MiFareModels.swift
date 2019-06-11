import Foundation

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
