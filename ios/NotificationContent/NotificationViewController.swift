import UIKit
import UserNotifications
import UserNotificationsUI

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    
    @IBOutlet private weak var bankNameLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var senderLabel: UILabel!
    @IBOutlet private weak var timestampLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Setup view customization
        setupViews()
    }
    
    private func setupViews() {
        // Configure labels
        bankNameLabel.font = .systemFont(ofSize: 16, weight: .medium)
        amountLabel.font = .systemFont(ofSize: 20, weight: .bold)
        senderLabel.font = .systemFont(ofSize: 14, weight: .regular)
        timestampLabel.font = .systemFont(ofSize: 12, weight: .regular)
        
        // Add shadow to make text more readable
        [bankNameLabel, amountLabel, senderLabel, timestampLabel].forEach { label in
            label?.layer.shadowColor = UIColor.black.cgColor
            label?.layer.shadowRadius = 1.0
            label?.layer.shadowOpacity = 0.2
            label?.layer.shadowOffset = CGSize(width: 0, height: 1)
        }
    }
    
    func didReceive(_ notification: UNNotification) {
        // Extract transaction details from notification
        let content = notification.request.content
        guard let bankInfo = content.userInfo["bankInfo"] as? [String: Any] else { return }
        
        // Update UI with transaction details
        if let bankName = bankInfo["bankName"] as? String {
            bankNameLabel.text = bankName
        }
        
        if let amount = bankInfo["amount"] as? Double {
            amountLabel.text = formatAmount(amount)
        }
        
        if let sender = bankInfo["senderInfo"] as? String {
            senderLabel.text = "จาก: \(sender)"
        }
        
        if let timestamp = bankInfo["timestamp"] as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            timestampLabel.text = formatDate(date)
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amountStr = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "฿\(amountStr)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "th_TH")
        return formatter.string(from: date)
    }
}