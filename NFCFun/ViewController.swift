//
//  ViewController.swift
//  NFCFun
//
//  Created by Steven Berard on 10/28/19.
//  Copyright © 2019 Steven Berard. All rights reserved.
//

import UIKit
import CoreNFC

class ViewController: UIViewController {

    @IBOutlet weak var tagIdLabel: UILabel!
    @IBOutlet weak var writeToTagTextField: UITextField!

    var readSession: NFCNDEFReaderSession?
    var writeSession: NFCNDEFReaderSession?

    @IBAction func userTappedBackground(_ sender: Any) {
        view.endEditing(true)
    }

    @IBAction func userTappedStartScan(_ sender: Any) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(title: "Scanning Not Supported", message: "This device doesn't support tag scanning.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        readSession = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        readSession?.alertMessage = "Tap the top of your phone to a tag to read it's payload!"
        
        readSession?.begin()
    }

    @IBAction func userTappedWriteToTag(_ sender: Any) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(title: "Scanning Not Supported", message: "This device doesn't support tag scanning.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }

        writeSession = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        writeSession?.alertMessage = "Tap the top of your phone to a tag to write to it's payload!"

        writeSession?.begin()
    }

    private func readTag(_ session: NFCNDEFReaderSession, tag: NFCNDEFTag) {
        tag.readNDEF { (message, error) in
            guard error == nil else {
                session.invalidate()
                return
            }

            guard let record = message?.records.first else {
                session.invalidate()
                return
            }

            let firstChar = String(data: record.payload, encoding: .utf8)?.first
            let payload: String

            if firstChar == "\u{02}" {
                payload = "\(String(data: record.payload, encoding: .utf8)?.dropFirst(3) ?? "<UNK>")"
            }
            else {
                payload = "\(String(data: record.payload, encoding: .utf8)?.dropFirst(1) ?? "<UNK>")"
            }

            print("\"\(payload)\"")
            self.tagIdLabel.text = payload
            session.alertMessage = payload
            session.invalidate()
        }
    }

    private func writeTag(_ session: NFCNDEFReaderSession, tag: NFCNDEFTag) {
        tag.queryNDEFStatus { (status, capacity, error) in
            guard error == nil else {
                print(error!)
                session.invalidate()
                return
            }

            print("Capacity: \(capacity) Bytes")

            switch status {
            case .readWrite:
                print("This tag is read/write compatible!  :D")

                // The characters "\u{02}", "e", and "n" are prefixed on strings that are formatted for english
                // There are other prefixes for other language formats.
                guard let payload = "\u{02}en\(self.writeToTagTextField.text ?? "")".data(using: .utf8) else {
                    session.invalidate()
                    return
                }

                let record = NFCNDEFPayload(format: .nfcWellKnown, type: Data(), identifier: Data(), payload: payload)

                // Not sure why NFCNDEFPayload.wellKnownTypeTextPayload() doesn't work...
//                guard let record = NFCNDEFPayload.wellKnownTypeTextPayload(string: "This is a test", locale: .autoupdatingCurrent) else {
//                    session.invalidate()
//                    return
//                }

                let myMessage = NFCNDEFMessage.init(records: [record])

                tag.writeNDEF(myMessage) { (error) in
                    if let error = error {
                        session.alertMessage = "Write NDEF message fail: \(error)"
                    }
                    else {
                        session.alertMessage = "Write NDEF message successful!"
                    }

                    session.invalidate()
                }
            case .readOnly:
                print("This tag can only be read.  :)")
                session.invalidate()
            case .notSupported:
                print("This tag is not supported.  :(")
                session.invalidate()
            @unknown default:
                print("I have no idea what just happened. 8O")
                session.invalidate()
            }
        }
    }
}

extension ViewController: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // No-op
        // Function overridden by readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag])
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        print("\(#function): \(error)")
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        print("\(#function)")
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        print("\(#function): \(tags)")

        guard let tag = tags.first else {
            return
        }

        session.connect(to: tag) { (error) in
            guard error == nil else {
                session.invalidate()
                return
            }

            switch session {
            case self.readSession:
                self.readTag(session, tag: tag)
            case self.writeSession:
                self.writeTag(session, tag: tag)
            default:
                session.invalidate()
            }
        }
    }
}
