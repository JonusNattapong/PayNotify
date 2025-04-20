import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class NotificationListenerService {
  static final NotificationListenerService _instance = NotificationListenerService._internal();
  factory NotificationListenerService() => _instance;
  
  NotificationListenerService._internal();

  static const MethodChannel _channel = MethodChannel('com.paynotify.app/notification_listener');
  static const EventChannel _eventChannel = EventChannel('com.paynotify.app/notification_events');
  
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService.instance;
  
  bool _isInitialized = false;
  bool _isEnabled = false;
  StreamSubscription? _notificationSubscription;

  // Enhanced regex patterns for Thai bank notifications
  final _moneyReceivedPatterns = [
    RegExp(r'(?:เงินเข้า|รับโอนเงิน|รับเงิน|ได้รับเงิน|โอนเข้า|โอนเงินเข้า|credit|เครดิต).*?(\d[\d,.]+)(?:\s*บาท|\s*THB|\s*฿)?', caseSensitive: false),
    RegExp(r'(?:จำนวนเงิน|amount).*?(\d[\d,.]+)(?:\s*บาท|\s*THB|\s*฿)?', caseSensitive: false),
    RegExp(r'(?:\+|\＋)\s*(\d[\d,.]+)(?:\s*บาท|\s*THB|\s*฿)?', caseSensitive: false),
  ];

  final _senderPattern = RegExp(r'(?:จาก|โอนจาก|from)\s+([^\d\n\r]+?)(?:\s|$)', caseSensitive: false);
  final _bankNamePattern = RegExp(r'(?:ธนาคาร|bank)[\s:]*([^\d\n\r]+?)(?:\s|$|\.|\,)', caseSensitive: false);
  final _accountNumberPattern = RegExp(r'(?:บัญชี|เลขบัญชี|acc|account)[\s.:]*(\d[\d\-x]+)', caseSensitive: false);

  // Bank identification patterns
  final Map<String, Map<String, dynamic>> _bankPatterns = {
    'scb': {
      'name': 'SCB',
      'fullName': 'ธนาคารไทยพาณิชย์',
      'patterns': [
        RegExp(r'(?:scb|ไทยพาณิชย์|siam commercial)', caseSensitive: false),
      ],
    },
    'kbank': {
      'name': 'KBANK',
      'fullName': 'ธนาคารกสิกรไทย',
      'patterns': [
        RegExp(r'(?:kbank|กสิกร|kasikorn)', caseSensitive: false),
      ],
    },
    'ktb': {
      'name': 'KTB',
      'fullName': 'ธนาคารกรุงไทย',
      'patterns': [
        RegExp(r'(?:ktb|krungthai|กรุงไทย)', caseSensitive: false),
      ],
    },
    'bbl': {
      'name': 'BBL',
      'fullName': 'ธนาคารกรุงเทพ',
      'patterns': [
        RegExp(r'(?:bbl|bangkok bank|กรุงเทพ)', caseSensitive: false),
      ],
    },
    'ttb': {
      'name': 'TTB',
      'fullName': 'ธนาคารทหารไทยธนชาต',
      'patterns': [
        RegExp(r'(?:ttb|tmb|thanachart|ทหารไทย|ธนชาต)', caseSensitive: false),
      ],
    },
    'uob': {
      'name': 'UOB',
      'fullName': 'ธนาคารยูโอบี',
      'patterns': [
        RegExp(r'(?:uob|ยูโอบี)', caseSensitive: false),
      ],
    },
    'bay': {
      'name': 'BAY',
      'fullName': 'ธนาคารกรุงศรีอยุธยา',
      'patterns': [
        RegExp(r'(?:bay|krungsri|กรุงศรี|อยุธยา)', caseSensitive: false),
      ],
    },
    'gsb': {
      'name': 'GSB',
      'fullName': 'ธนาคารออมสิน',
      'patterns': [
        RegExp(r'(?:gsb|ออมสิน)', caseSensitive: false),
      ],
    },
    'baac': {
      'name': 'BAAC',
      'fullName': 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร',
      'patterns': [
        RegExp(r'(?:baac|ธกส|เพื่อการเกษตร)', caseSensitive: false),
      ],
    },
  };

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      try {
        // Setup the notification listener
        await _channel.invokeMethod('initialize');
        
        // Check if notification access is granted
        _isEnabled = await checkNotificationPermission();
        
        // Listen for notification events
        _notificationSubscription = _eventChannel
            .receiveBroadcastStream()
            .listen(_onNotificationEvent, onError: _onNotificationError);
        
        _isInitialized = true;
      } catch (e) {
        debugPrint('Error initializing notification listener: $e');
        _isInitialized = false;
      }
    } else {
      // For iOS, we use screenshot OCR instead of notification listener
      _isInitialized = true;
      _isEnabled = true;
    }
  }

  // Check if notification access is granted
  Future<bool> checkNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      return await _channel.invokeMethod('checkPermission');
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return false;
    }
  }

  // Request notification access
  Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  // Process notification events
  void _onNotificationEvent(dynamic event) async {
    try {
      if (event == null) return;
      
      Map<String, dynamic> notificationData;
      if (event is String) {
        notificationData = json.decode(event);
      } else if (event is Map) {
        notificationData = Map<String, dynamic>.from(event);
      } else {
        return;
      }
      
      final String packageName = notificationData['packageName'] ?? '';
      final String title = notificationData['title'] ?? '';
      final String content = notificationData['content'] ?? '';
      final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(
          (notificationData['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('Received notification from package: $packageName');
      debugPrint('Title: $title');
      debugPrint('Content: $content');
      
      final fullText = '$title $content';
      
      // Process the notification text to extract transaction data
      final transaction = _parseTransactionData(fullText, packageName);
      if (transaction != null) {
        // Save the transaction to database
        await _saveTransaction(transaction);
        
        // Show notification to user
        await _notificationService.showTransactionNotification(
          title: 'ได้รับเงิน ${transaction.amount.toString()} บาท',
          body: 'จาก: ${transaction.senderInfo}, ธนาคาร: ${transaction.bankName}',
        );
      }
    } catch (e) {
      debugPrint('Error processing notification event: $e');
    }
  }

  void _onNotificationError(Object error) {
    debugPrint('Error from notification event stream: $error');
  }

  // Parse notification text to extract transaction data
  Transaction? _parseTransactionData(String text, String packageName) {
    try {
      // Initialize variables
      double? amount;
      String? sender;
      String? bankName;
      String? accountNumber;
      
      // Extract the amount
      for (final pattern in _moneyReceivedPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
          amount = double.tryParse(amountStr);
          break;
        }
      }
      
      // If no amount found, this is not a valid transaction notification
      if (amount == null) {
        return null;
      }
      
      // Determine bank name based on package name or notification content
      bankName = _detectBankName(packageName, text);
      
      // Extract sender info
      final senderMatch = _senderPattern.firstMatch(text);
      if (senderMatch != null) {
        sender = senderMatch.group(1)?.trim();
      }
      
      // Extract account number if available
      final accountMatch = _accountNumberPattern.firstMatch(text);
      if (accountMatch != null) {
        accountNumber = accountMatch.group(1)?.trim();
      }
      
      // Create and return the transaction
      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber ?? '',
        senderInfo: sender ?? 'ไม่ระบุ',
        description: 'รับเงินจากการแจ้งเตือน',
        timestamp: DateTime.now(),
        isVerified: true,
        rawNotificationText: text,
      );
    } catch (e) {
      debugPrint('Error parsing transaction data: $e');
      return null;
    }
  }

  // Detect bank name from package name or notification content
  String _detectBankName(String packageName, String text) {
    final lowerPackage = packageName.toLowerCase();
    final lowerText = text.toLowerCase();
    
    // First try to detect from package name
    if (lowerPackage.contains('scb')) {
      return 'ธนาคารไทยพาณิชย์ (SCB)';
    } else if (lowerPackage.contains('k') && lowerPackage.contains('bank')) {
      return 'ธนาคารกสิกรไทย (KBANK)';
    } else if (lowerPackage.contains('ktb') || lowerPackage.contains('krungthai')) {
      return 'ธนาคารกรุงไทย (KTB)';
    } else if (lowerPackage.contains('bbl') || lowerPackage.contains('bangkok')) {
      return 'ธนาคารกรุงเทพ (BBL)';
    } else if (lowerPackage.contains('ttb') || lowerPackage.contains('tmb') || lowerPackage.contains('thanachart')) {
      return 'ธนาคารทหารไทยธนชาต (TTB)';
    } else if (lowerPackage.contains('uob')) {
      return 'ธนาคารยูโอบี (UOB)';
    } else if (lowerPackage.contains('bay') || lowerPackage.contains('krungsri')) {
      return 'ธนาคารกรุงศรีอยุธยา (BAY)';
    } else if (lowerPackage.contains('gsb')) {
      return 'ธนาคารออมสิน (GSB)';
    } else if (lowerPackage.contains('baac')) {
      return 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร (BAAC)';
    }
    
    // Then try to detect from notification content
    for (var entry in _bankPatterns.entries) {
      final bank = entry.value;
      final namePattern = bank['patterns'][0];
      
      if (namePattern.hasMatch(lowerText)) {
        return bank['fullName'];
      }
    }
    
    // Check for explicit bank name in text
    final bankMatch = _bankNamePattern.firstMatch(text);
    if (bankMatch != null) {
      return bankMatch.group(1)?.trim() ?? 'ไม่ระบุธนาคาร';
    }
    
    // If all detection methods fail, check if it's a SMS message
    if (packageName.contains('messaging')) {
      return 'SMS แจ้งเตือนจากธนาคาร';
    }
    
    // Default value
    return 'ไม่ระบุธนาคาร';
  }

  // Save transaction to database
  Future<void> _saveTransaction(Transaction transaction) async {
    try {
      // Save to local database
      await _databaseService.insertTransaction(transaction);
      
      // Try to save to Supabase if connected
      try {
        await SupabaseService.instance.addTransaction(transaction);
      } catch (e) {
        debugPrint('Failed to save to Supabase: $e');
      }
      
      // Play notification sound
      _notificationService.playNotificationSound();
      
      // Update last transaction timestamp
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_transaction_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving transaction: $e');
    }
  }

  // Dispose resources
  void dispose() {
    _notificationSubscription?.cancel();
    _isInitialized = false;
  }
}