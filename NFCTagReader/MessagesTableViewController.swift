/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The view controller that scans and displays NDEF messages.
*/

import UIKit
import CoreNFC

/// - Tag: ndefReading_1
@available(iOS 13.0, *)
class MessagesTableViewController: UITableViewController {
    // MARK: - Properties

    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCTagReaderSession?
    var numberFormatter: NumberFormatter!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.beginScanning(self)
        }
    }

    // MARK: - Actions
    
    /// - Tag: beginScanning
    @IBAction func beginScanning(_ sender: Any) {
        self.numberFormatter = NumberFormatter()
        self.numberFormatter.currencyCode = Locale.current.currencyCode
        self.numberFormatter.currencySymbol = Locale.current.currencySymbol
        self.numberFormatter.minimumFractionDigits = 2
        self.numberFormatter.numberStyle = .currency
        
        session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        if NFCTagReaderSession.readingAvailable {
            session?.begin()
        }else {
            self.showSessionError(SessionError.notAvialble)
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
    
    func showSessionError(_ error: Error) {
        let title = NSLocalizedString("Session error", comment: "")
        
        var message = NSLocalizedString("The reading session has failed", comment: "")
        
        if let sessionError = error as? SessionError {
            switch sessionError {
            case .notAvialble:
                message = NSLocalizedString("NFC reading is not available on this phone", comment: "")
            case .unknown:
                message = NSLocalizedString("Unknown session error", comment: "")
            }
        }else {
            message = String(format: NSLocalizedString("Error occurred %@", comment: "Error"), error.localizedDescription)
        }

    
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
//        DispatchQueue.main.async {
////            self.showSessionError(error)
//        }
        
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("Detected tags \(tags)")
        
        switch tags.first! {
        case let .miFare(tag):
            self.scanMiFareTag(tag, discoveredTag: tags.first!, session: session)
            
        default:
            break
        }

        
    }
    
    
    /// Scan a MiFare Tag for the current value and the last transaction
    /// - Parameter tag: Just discovered NFCMiFareTag
    /// - Parameter discoveredTag: The NFCTag that has been on the tag list. Because a session cannot connection to a NFCMiFareTag directy. Should refer to the same as tag
    /// - Parameter session:the current session  
    func scanMiFareTag(_ tag: NFCMiFareTag, discoveredTag:NFCTag, session: NFCTagReaderSession) {
        //1. Connect to the TAG. Connecting to mifaretag not possible
        session.connect(to: discoveredTag) { (error) in
            guard error == nil else {
                print("Error connecting to tag \(error!)")
                return
            }
            print("Connected to tag")
            
            //Start in the right app
            tag.selectApp(0x5F8415, {
                tag.getFileSettings { lastTransaction in
                    tag.readValue { value in
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
    }
    
    
}

enum SessionError: Error {
    case notAvialble
    case unknown
}
