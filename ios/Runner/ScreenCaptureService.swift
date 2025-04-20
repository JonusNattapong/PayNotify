import Foundation
import ReplayKit
import Vision
import UIKit

class ScreenCaptureService: NSObject {
    static let shared = ScreenCaptureService()
    
    private let recorder = RPScreenRecorder.shared()
    private let ocrProcessor = OCRProcessor.shared
    private var isRecording = false
    private var processingInterval: TimeInterval = 1.0 // Check every second
    private var lastProcessingTime: Date?
    
    private let bankAppBundles = [
        "com.scb.retail.ios",          // SCB Easy
        "com.kasikorn.kplus",          // K PLUS
        "com.ktb.next",               // Krungthai NEXT
        "com.bbl.mobilebanking",      // Bangkok Bank Mobile
        "com.ttb.oneapp",             // ttb touch
        "com.krungsri.kma",           // Krungsri Mobile
        // Add more banking apps
    ]
    
    override init() {
        super.init()
        setupRecorder()
    }
    
    private func setupRecorder() {
        recorder.isMicrophoneEnabled = false
        recorder.isAppAudioEnabled = false
    }
    
    func startCapturing() {
        guard !isRecording else { return }
        
        recorder.startCapture { [weak self] (buffer, bufferType, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Screen capture error: \(error.localizedDescription)")
                return
            }
            
            // Check if enough time has passed since last processing
            if let lastTime = self.lastProcessingTime,
               Date().timeIntervalSince(lastTime) < self.processingInterval {
                return
            }
            
            // Process only if active app is a banking app
            if self.isBankingAppActive() {
                self.processScreenBuffer(buffer)
            }
            
            self.lastProcessingTime = Date()
        } completionHandler: { [weak self] error in
            if let error = error {
                print("Failed to start screen capture: \(error.localizedDescription)")
            } else {
                self?.isRecording = true
                print("Screen capture started successfully")
            }
        }
    }
    
    func stopCapturing() {
        guard isRecording else { return }
        
        recorder.stopCapture { [weak self] error in
            if let error = error {
                print("Failed to stop screen capture: \(error.localizedDescription)")
            } else {
                self?.isRecording = false
                print("Screen capture stopped successfully")
            }
        }
    }
    
    private func processScreenBuffer(_ buffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let image = UIImage(cgImage: cgImage)
        
        // Process with OCR
        ocrProcessor.processTransferImage(image) { [weak self] result, error in
            if let error = error {
                print("OCR processing error: \(error.localizedDescription)")
                return
            }
            
            if let result = result,
               let amount = result["amount"] as? Double,
               amount > 0 {
                // Found valid transaction data
                self?.notifyTransactionDetected(result)
            }
        }
    }
    
    private func isBankingAppActive() -> Bool {
        guard let activeAppBundle = getActiveAppBundle() else { return false }
        return bankAppBundles.contains(activeAppBundle)
    }
    
    private func getActiveAppBundle() -> String? {
        // This is a placeholder - actual implementation would depend on iOS version and permissions
        // You might need to use private APIs or alternative methods to detect active app
        return nil
    }
    
    private func notifyTransactionDetected(_ data: [String: Any]) {
        // Send to Flutter through method channel
        DispatchQueue.main.async {
            guard let controller = UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController else {
                return
            }
            
            let channel = FlutterMethodChannel(
                name: "com.paynotify/screen_capture",
                binaryMessenger: controller.binaryMessenger)
            
            channel.invokeMethod("onTransactionDetected", arguments: data)
        }
    }
    
    // Permission handling
    func requestScreenRecordingPermission(completion: @escaping (Bool) -> Void) {
        RPScreenRecorder.shared().isMicrophoneEnabled = false
        RPScreenRecorder.shared().isAppAudioEnabled = false
        
        switch recorder.recordingAvailable {
        case true:
            completion(true)
        case false:
            print("Screen recording is not available on this device")
            completion(false)
        }
    }
}