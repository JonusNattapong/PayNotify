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
    // Try multiple patterns to improve accuracy
    final patterns = [
      // Pattern 1: Amount with currency symbol/word after
      RegExp(r'(?:จำนวน|รับเงิน|โอนเงิน|เงินเข้า)\s*([0-9,]+\.?\d*)\s*(?:บาท|THB|฿)', caseSensitive: false),
      // Pattern 2: Currency symbol/word before amount
      RegExp(r'(?:บาท|THB|฿)\s*([0-9,]+\.?\d*)', caseSensitive: false),
      // Pattern 3: Just numbers with optional decimals
      RegExp(r'(?:^|\s)([0-9,]+\.?\d*)(?:\s|$)'),
      // Pattern 4: Amount in parentheses
      RegExp(r'\(([0-9,]+\.?\d*)\s*(?:บาท|THB|฿)?\)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        String amountStr = match.group(1)!.replaceAll(',', '');
        double? amount = double.tryParse(amountStr);
        if (amount != null && amount > 0) {
          return amount;
        }
      }
    }

    // If no amount found, try more aggressive pattern matching
    final numberPattern = RegExp(r'([0-9,]+\.?\d*)');
    var matches = numberPattern.allMatches(text);
    for (var match in matches) {
      String amountStr = match.group(1)!.replaceAll(',', '');
      double? amount = double.tryParse(amountStr);
      if (amount != null && amount > 0) {
        // Verify this looks like a reasonable transaction amount
        if (amount > 0.5 && amount < 1000000) {
          return amount;
        }
      }
    }

    return 0.0;
  }

  static String _extractAccountNumberFromNotification(String text, String bankName) {
    // Bank-specific patterns
    final bankPatterns = {
      'SCB': RegExp(r'(?:บัญชี|เลขที่|a/c|account)[\s:]*(?:[xX*]{0,10})(\d{3,4}[-\s]?\d{4})(?:\s|$)', caseSensitive: false),
      'KBANK': RegExp(r'(?:บัญชี|เลขที่|account)[\s:]*(?:[xX*]{0,8})(\d{3,4}[-\s]?\d{4})(?:\s|$)', caseSensitive: false),
      'KTB': RegExp(r'(?:บัญชี|เลขที่|account)[\s:]*(?:xxx[-\s]xxx[-\s]x*)?(\d{3,4})(?:\s|$)', caseSensitive: false),
      'BBL': RegExp(r'(?:บัญชี|account)[\s:]*(?:[xX*]{0,8})(\d{3,4}[-\s]?\d{4})(?:\s|$)', caseSensitive: false),
    };

    // Try bank-specific pattern first
    if (bankPatterns.containsKey(bankName)) {
      var match = bankPatterns[bankName]!.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
      }
    }

    // Fallback patterns
    final fallbackPatterns = [
      // Pattern 1: Account number with x/X masking
      RegExp(r'(?:บัญชี|เลขที่|a/c|account)[\s:]*(?:[xX*]{0,10})(\d{3,4}[-\s]?\d{4})(?:\s|$)', caseSensitive: false),
      // Pattern 2: Last 4-6 digits only
      RegExp(r'(?:บัญชี|เลขที่|account)[\s:]*(?:[xX*\d][-\s]?)*((?:\d[-\s]?){4,6})(?:\s|$)', caseSensitive: false),
      // Pattern 3: Any sequence of 4-6 digits that might be account number
      RegExp(r'(?:\d[-\s]?){4,6}(?:\s|$)'),
    ];

    for (var pattern in fallbackPatterns) {
      var match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
      }
    }

    return 'Unknown';
  }

  static String _extractSenderInfoFromNotification(String text, String bankName) {
    // Bank-specific patterns
    final bankPatterns = {
      'SCB': [
        RegExp(r'(?:จาก|from|by|โดย)[\s:]*([ก-์A-Za-z0-9\s\.]+)(?:\s|$)', caseSensitive: false),
        RegExp(r'(?<=\n)([ก-์A-Za-z0-9\s\.]+)(?=\s*โอนเงิน)', caseSensitive: false),
      ],
      'KBANK': [
        RegExp(r'(?:จาก|from|by|โดย)[\s:]*([ก-์A-Za-z0-9\s\.]+)(?:\s|$)', caseSensitive: false),
        RegExp(r'(?<=\n)([ก-์A-Za-z0-9\s\.]+)(?=\s*โอนให้)', caseSensitive: false),
      ],
      'KTB': [
        RegExp(r'(?:จาก|from|by|โดย)[\s:]*([ก-์A-Za-z0-9\s\.]+)(?:\s|$)', caseSensitive: false),
      ],
      'BBL': [
        RegExp(r'(?:จาก|from|by|โดย)[\s:]*([ก-์A-Za-z0-9\s\.]+)(?:\s|$)', caseSensitive: false),
      ],
    };

    // Try bank-specific patterns first
    if (bankPatterns.containsKey(bankName)) {
      for (var pattern in bankPatterns[bankName]!) {
        var match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          String sender = match.group(1)!.trim();
          // Remove common prefixes/suffixes
          sender = sender.replaceAll(RegExp(r'^(นาย|นาง|นางสาว|คุณ|mr\.|mrs\.|ms\.)\s*', caseSensitive: false), '');
          return sender;
        }
      }
    }

    // Fallback patterns
    final fallbackPatterns = [
      RegExp(r'(?:จาก|from|by|โดย)[\s:]*([ก-์A-Za-z0-9\s\.]+)(?:\s|$)', caseSensitive: false),
      RegExp(r'(?:โอนโดย|transferred by|sender)[\s:]*([ก-์A-Za-z0-9\s\.]+)(?:\s|$)', caseSensitive: false),
      RegExp(r'(?<=\n)([ก-์A-Za-z0-9\s\.]+)(?=\s*(?:โอนเงิน|โอนให้|transfer))', caseSensitive: false),
    ];

    for (var pattern in fallbackPatterns) {
      var match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        String sender = match.group(1)!.trim();
        // Remove common prefixes/suffixes
        sender = sender.replaceAll(RegExp(r'^(นาย|นาง|นางสาว|คุณ|mr\.|mrs\.|ms\.)\s*', caseSensitive: false), '');
        if (sender.length > 2 && !sender.contains(RegExp(r'บาท|THB|[0-9,]+'))) {
          return sender;
        }
      }
    }

    return 'Unknown';
  }

  static String _extractDescriptionFromNotification(String text, String bankName) {
    // Bank-specific patterns
    final bankPatterns = {
      'SCB': [
        RegExp(r'(?:รายละเอียด|ข้อความ|message|description|ref)[\s:]*([^\n.,]+)', caseSensitive: false),
        RegExp(r'(?:หมายเหตุ|note)[\s:]*([^\n.,]+)', caseSensitive: false),
      ],
      'KBANK': [
        RegExp(r'(?:รายละเอียด|ข้อความ|message|memo)[\s:]*([^\n.,]+)', caseSensitive: false),
      ],
      'KTB': [
        RegExp(r'(?:รายละเอียด|ข้อความ|ref)[\s:]*([^\n.,]+)', caseSensitive: false),
      ],
      'BBL': [
        RegExp(r'(?:รายละเอียด|ข้อความ|description)[\s:]*([^\n.,]+)', caseSensitive: false),
      ],
    };

    // Try bank-specific patterns first
    if (bankPatterns.containsKey(bankName)) {
      for (var pattern in bankPatterns[bankName]!) {
        var match = pattern.firstMatch(text);
        if (match != null && match.group(1) != null) {
          String desc = match.group(1)!.trim();
          if (_isValidDescription(desc)) {
            return desc;
          }
        }
      }
    }

    // Fallback patterns
    final fallbackPatterns = [
      RegExp(r'(?:รายละเอียด|ข้อความ|message|description|ref|memo)[\s:]*([^\n.,]+)', caseSensitive: false),
      RegExp(r'(?:หมายเหตุ|note)[\s:]*([^\n.,]+)', caseSensitive: false),
      // Try to find any meaningful text that's not part of the standard notification
      RegExp(r'(?<=\n)([ก-์A-Za-z0-9\s\.\-_]+)(?=\n|$)'),
    ];

    for (var pattern in fallbackPatterns) {
      var match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        String desc = match.group(1)!.trim();
        if (_isValidDescription(desc)) {
          return desc;
        }
      }
    }

    return '';
  }

  // Helper method to validate description
  static bool _isValidDescription(String desc) {
    if (desc.isEmpty || desc.length < 3) return false;

    // Check if description contains common transaction elements that we don't want
    final invalidPatterns = [
      RegExp(r'บาท|THB|฿'),
      RegExp(r'\d{4,}'),
      RegExp(r'(?:เงินเข้า|โอนเงิน|รับเงิน)'),
      RegExp(r'(?:account|บัญชี|จาก|from)'),
    ];

    for (var pattern in invalidPatterns) {
      if (pattern.hasMatch(desc)) return false;
    }

    return true;
  }
}