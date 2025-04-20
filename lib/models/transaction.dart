import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final double amount;
  final String bankName;
  final String accountNumber;
  final String senderInfo;
  final String description;
  final DateTime timestamp;
  final bool isVerified;
  final String rawNotificationText;

  Transaction({
    required this.id,
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    required this.senderInfo,
    required this.description,
    required this.timestamp,
    this.isVerified = false,
    required this.rawNotificationText,
  });

  // Create from notification message
  factory Transaction.fromNotification(String notificationText, String bankName) {
    // Pattern matching for different banks would be implemented here
    // This is a simplified version for demo purpose
    
    // Example for a mock transaction
    return Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: _extractAmountFromNotification(notificationText),
      bankName: bankName,
      accountNumber: _extractAccountNumberFromNotification(notificationText, bankName),
      senderInfo: _extractSenderInfoFromNotification(notificationText, bankName),
      description: _extractDescriptionFromNotification(notificationText, bankName),
      timestamp: DateTime.now(),
      rawNotificationText: notificationText,
    );
  }

  // Create from Firestore document
  factory Transaction.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Transaction(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      bankName: data['bankName'] ?? '',
      accountNumber: data['accountNumber'] ?? '',
      senderInfo: data['senderInfo'] ?? '',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isVerified: data['isVerified'] ?? false,
      rawNotificationText: data['rawNotificationText'] ?? '',
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'senderInfo': senderInfo,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'isVerified': isVerified,
      'rawNotificationText': rawNotificationText,
    };
  }

  // Helper methods for extracting info from notification texts
  static double _extractAmountFromNotification(String text) {
    // Simplified implementation - pattern matching would be more complex in production
    RegExp regExp = RegExp(r'(?:รับเงิน|โอนเงิน|จำนวน)\s*([0-9,.]+)(?:\s*บาท)?', caseSensitive: false);
    var match = regExp.firstMatch(text);
    
    if (match != null) {
      String amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
      return double.tryParse(amountStr) ?? 0.0;
    }
    return 0.0;
  }

  static String _extractAccountNumberFromNotification(String text, String bankName) {
    // Implementation would vary by bank
    // This is a simplified version
    RegExp regExp = RegExp(r'(?:บัญชี|เลขที่|account)[\s:]*([xX*\d]{4,})', caseSensitive: false);
    var match = regExp.firstMatch(text);
    return match?.group(1) ?? 'Unknown';
  }

  static String _extractSenderInfoFromNotification(String text, String bankName) {
    // Implementation would vary by bank
    // This is a simplified version
    RegExp regExp = RegExp(r'(?:จาก|from)[\s:]*([^\n.,]+)', caseSensitive: false);
    var match = regExp.firstMatch(text);
    return match?.group(1)?.trim() ?? 'Unknown';
  }

  static String _extractDescriptionFromNotification(String text, String bankName) {
    // For SCB usually contains "รายละเอียด: XXX" or similar pattern
    RegExp regExp = RegExp(r'(?:รายละเอียด|ข้อความ|description)[\s:]*([^\n]+)', caseSensitive: false);
    var match = regExp.firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }
}