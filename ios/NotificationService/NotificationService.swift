import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            // Extract notification data
            let userInfo = bestAttemptContent.userInfo
            
            // Process bank notification
            if let bankInfo = userInfo["bankInfo"] as? [String: Any] {
                processBankNotification(content: bestAttemptContent, bankInfo: bankInfo)
            }
            
            // Deliver the notification
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
    
    private func processBankNotification(content: UNMutableNotificationContent, bankInfo: [String: Any]) {
        // Extract bank transaction information
        if let amount = bankInfo["amount"] as? Double,
           let bankName = bankInfo["bankName"] as? String,
           let sender = bankInfo["senderInfo"] as? String {
            
            // Format the notification title and body
            content.title = "รับเงินเข้าบัญชี \(bankName)"
            content.body = "จำนวน \(formatAmount(amount)) บาท จาก \(sender)"
            
            // Add category identifier for rich notification
            content.categoryIdentifier = "BANK_TRANSACTION"
            
            // Add sound
            content.sound = UNNotificationSound(named: UNNotificationSoundName("cash_register.wav"))
            
            // Store the full transaction details in userInfo for later access
            var updatedUserInfo = content.userInfo
            updatedUserInfo["processedTransaction"] = true
            content.userInfo = updatedUserInfo
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}