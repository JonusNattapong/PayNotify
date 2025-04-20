import UIKit
import Flutter
import UserNotifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register for push notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      
      // Define notification actions
      let viewAction = UNNotificationAction(
        identifier: "VIEW_ACTION",
        title: "ดูรายละเอียด",
        options: .foreground
      )
      
      let archiveAction = UNNotificationAction(
        identifier: "ARCHIVE_ACTION",
        title: "จัดเก็บ",
        options: .destructive
      )
      
      // Create notification category for bank transactions
      let bankCategory = UNNotificationCategory(
        identifier: "BANK_TRANSACTION",
        actions: [viewAction, archiveAction],
        intentIdentifiers: [],
        options: []
      )
      
      // Register the category
      UNUserNotificationCenter.current().setNotificationCategories([bankCategory])
      
      // Request authorization
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if granted {
            print("Notification authorization granted")
          } else if let error = error {
            print("Failed to get notification authorization: \(error)")
          }
        }
      )
    } else {
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    // Setup method channels for image processing
    let controller = window?.rootViewController as! FlutterViewController
    let imageProcessingChannel = FlutterMethodChannel(
      name: "com.paynotify/image_processing",
      binaryMessenger: controller.binaryMessenger
    )
    
    imageProcessingChannel.setMethodCallHandler({ [weak self] (call, result) in
      guard let strongSelf = self else { return }
      
      if call.method == "processTransferImage" {
        if let imagePath = call.arguments as? String {
          strongSelf.processTransferImage(imagePath: imagePath, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Image path is required", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    // Setup background audio session
    setupBackgroundAudio()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupBackgroundAudio() {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to set up background audio session: \(error)")
    }
  }
  
  private func processTransferImage(imagePath: String, result: @escaping FlutterResult) {
    // Initialize Vision framework for OCR text recognition
    guard let image = UIImage(contentsOfFile: imagePath) else {
      result(FlutterError(code: "INVALID_IMAGE", message: "Could not load image", details: nil))
      return
    }
    
    // Use Vision framework to extract text (simplified version)
    if #available(iOS 13.0, *) {
      let textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
        guard error == nil else {
          result(FlutterError(code: "OCR_ERROR", message: error!.localizedDescription, details: nil))
          return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
          result([String]())
          return
        }
        
        let recognizedTexts = observations.compactMap { observation in
          observation.topCandidates(1).first?.string
        }
        
        // Process the recognized text to extract bank transfer information
        self.extractBankTransferInfo(from: recognizedTexts, result: result)
      }
      
      textRecognitionRequest.recognitionLevel = .accurate
      textRecognitionRequest.usesLanguageCorrection = true
      
      let requestHandler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try requestHandler.perform([textRecognitionRequest])
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "OCR_PROCESS_ERROR", message: error.localizedDescription, details: nil))
          }
        }
      }
    } else {
      // For older iOS versions, provide a message
      result(FlutterError(code: "UNSUPPORTED_IOS_VERSION", message: "OCR requires iOS 13.0 or later", details: nil))
    }
  }
  
  private func extractBankTransferInfo(from textLines: [String], result: @escaping FlutterResult) {
    var transactionInfo: [String: Any] = [:]
    
    // Extract amount (look for currency patterns)
    for line in textLines {
      // Look for Thai Baht amount pattern (e.g. "฿1,234.56" or "1,234.56 บาท")
      if let amount = self.extractAmount(from: line) {
        transactionInfo["amount"] = amount
      }
      
      // Check for bank name
      for bank in ["SCB", "KBANK", "KTB", "BBL", "TMB", "TTB", "UOB", "ธนาคารไทยพาณิชย์", "กสิกรไทย", "กรุงไทย", "กรุงเทพ"] {
        if line.contains(bank) {
          transactionInfo["bankName"] = bank
          break
        }
      }
      
      // Look for account numbers (e.g. XXX-X-XXXXX-X)
      if let accountNumber = self.extractAccountNumber(from: line) {
        transactionInfo["accountNumber"] = accountNumber
      }
      
      // Look for timestamps
      if let timestamp = self.extractTimestamp(from: line) {
        transactionInfo["timestamp"] = timestamp
      }
    }
    
    // Convert raw text to single string for further processing
    let rawText = textLines.joined(separator: "\n")
    transactionInfo["rawNotificationText"] = rawText
    
    result(transactionInfo)
  }
  
  private func extractAmount(from text: String) -> Double? {
    // Regular expression for Thai Baht amount patterns
    let patterns = [
      "฿\\s*([0-9,.]+)",                          // ฿1,234.56
      "([0-9,.]+)\\s*บาท",                        // 1,234.56 บาท
      "จำนวนเงิน[\\s:]*([0-9,.]+)",                // จำนวนเงิน: 1,234.56
      "เงิน[\\s:]*([0-9,.]+)",                     // เงิน: 1,234.56
      "โอนเงิน[\\s:]*(\\d[0-9,.]+)",               // โอนเงิน 1,234.56
      "([0-9,.]+)"                                // Fallback to just numbers
    ]
    
    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        
        if let match = matches.first, match.numberOfRanges > 1 {
          let matchRange = match.range(at: 1)
          
          if let range = Range(matchRange, in: text) {
            let amountStr = text[range]
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
            
            return Double(amountStr)
          }
        }
      }
    }
    
    return nil
  }
  
  private func extractAccountNumber(from text: String) -> String? {
    // Look for common account number patterns
    let patterns = [
      "\\d{3}-\\d-\\d{5}-\\d",      // XXX-X-XXXXX-X
      "\\d{3}-\\d{6}-\\d",          // XXX-XXXXXX-X
      "\\d{10}",                    // XXXXXXXXXX
      "\\d{3}-\\d{3}-\\d{4}"        // XXX-XXX-XXXX
    ]
    
    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        
        if let match = matches.first {
          let matchRange = match.range
          
          if let range = Range(matchRange, in: text) {
            return String(text[range])
          }
        }
      }
    }
    
    return nil
  }
  
  private func extractTimestamp(from text: String) -> String? {
    // Look for date/time patterns
    let patterns = [
      "\\d{2}/\\d{2}/\\d{4} \\d{2}:\\d{2}",            // DD/MM/YYYY HH:MM
      "\\d{2}-\\d{2}-\\d{4} \\d{2}:\\d{2}",            // DD-MM-YYYY HH:MM
      "\\d{2} [ก-๙]+ \\d{4} \\d{2}:\\d{2}(:\\d{2})?"   // DD Month YYYY HH:MM(:SS) (Thai)
    ]
    
    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern) {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)
        
        if let match = matches.first {
          let matchRange = match.range
          
          if let range = Range(matchRange, in: text) {
            return String(text[range])
          }
        }
      }
    }
    
    return nil
  }
  
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Convert token to string
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    
    // Send token to Flutter side
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "com.paynotify/device_token", binaryMessenger: controller.binaryMessenger)
    channel.invokeMethod("updateDeviceToken", arguments: token)
    
    print("Device Token: \(token)")
  }
  
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
  }
  
  // Handle notification display when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    // Check if it's a bank notification
    if let bankInfo = userInfo["bankInfo"] as? [String: Any] {
      // Process bank notification
      processBankNotification(bankInfo)
      
      // Show notification with sound
      if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound, .badge, .list])
      } else {
        completionHandler([.alert, .sound, .badge])
      }
    } else {
      // For other notifications, use default presentation
      completionHandler([.alert, .sound])
    }
  }
  
  // Handle notification response
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    // Handle different actions
    switch response.actionIdentifier {
    case "VIEW_ACTION":
      if let bankInfo = userInfo["bankInfo"] as? [String: Any] {
        // Send to Flutter side to show transaction details
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
          name: "com.paynotify/notification_action",
          binaryMessenger: controller.binaryMessenger
        )
        channel.invokeMethod("viewTransaction", arguments: bankInfo)
      }
    case "ARCHIVE_ACTION":
      if let bankInfo = userInfo["bankInfo"] as? [String: Any] {
        // Send to Flutter side to archive transaction
        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
          name: "com.paynotify/notification_action",
          binaryMessenger: controller.binaryMessenger
        )
        channel.invokeMethod("archiveTransaction", arguments: bankInfo)
      }
    default:
      break
    }
    
    completionHandler()
  }
  
  private func processBankNotification(_ bankInfo: [String: Any]) {
    // Convert to Transaction object on Flutter side
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(
      name: "com.paynotify/notification_processing",
      binaryMessenger: controller.binaryMessenger
    )
    channel.invokeMethod("processBankNotification", arguments: bankInfo)
  }
}

// Necessary import for Vision framework
import Vision
import AVFoundation