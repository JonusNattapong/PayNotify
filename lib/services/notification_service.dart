import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pay_notify/models/transaction.dart';
import 'package:pay_notify/services/database_service.dart';
import 'package:pay_notify/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'package:vibration/vibration.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Notification sound settings
  bool _soundEnabled = true;
  String _selectedSoundPath = 'assets/sounds/cash_register.mp3';
  double _soundVolume = 0.5;
  
  bool get soundEnabled => _soundEnabled;
  String get selectedSoundPath => _selectedSoundPath;
  double get soundVolume => _soundVolume;
  
  // Enhanced pattern recognition settings
  bool _enhancedRecognitionEnabled = true;
  bool get enhancedRecognitionEnabled => _enhancedRecognitionEnabled;
  
  // Offline mode flag
  bool _offlineMode = false;
  bool get offlineMode => _offlineMode;
  set offlineMode(bool value) {
    _offlineMode = value;
  }
  
  // Pending transactions queue for offline mode
  final List<Transaction> _pendingTransactions = [];
  List<Transaction> get pendingTransactions => _pendingTransactions;
  
  NotificationService._internal();
  
  Future<void> init() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const DarwinInitializationSettings iosInitializationSettings = 
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    await _loadSettings();
    await _preloadSounds();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _selectedSoundPath = prefs.getString('selected_sound_path') ?? 'assets/sounds/cash_register.mp3';
    _soundVolume = prefs.getDouble('sound_volume') ?? 0.5;
    _enhancedRecognitionEnabled = prefs.getBool('enhanced_recognition_enabled') ?? true;
  }
  
  Future<void> saveSoundPreferences({
    bool? enabled,
    String? soundPath,
    double? volume,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (enabled != null) {
      _soundEnabled = enabled;
      await prefs.setBool('sound_enabled', enabled);
    }
    
    if (soundPath != null) {
      _selectedSoundPath = soundPath;
      await prefs.setString('selected_sound_path', soundPath);
    }
    
    if (volume != null) {
      _soundVolume = volume;
      await prefs.setDouble('sound_volume', volume);
    }
  }
  
  Future<void> saveRecognitionSettings({
    bool? enhancedRecognitionEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (enhancedRecognitionEnabled != null) {
      _enhancedRecognitionEnabled = enhancedRecognitionEnabled;
      await prefs.setBool('enhanced_recognition_enabled', enhancedRecognitionEnabled);
    }
  }
  
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigate to transaction details page
    if (response.payload != null) {
      final data = json.decode(response.payload!);
      // Navigation would be handled here
      print('Notification tapped: $data');
    }
  }
  
  Future<void> playNotificationSound() async {
    if (!_soundEnabled) return;
    
    try {
      await _audioPlayer.setVolume(_soundVolume);
      await _audioPlayer.setReleaseMode(ReleaseMode.stop); // Stop on completion
      await _audioPlayer.play(AssetSource(_selectedSoundPath));
    } catch (e) {
      print('Error playing notification sound: $e');
    }
  }
  
  Future<void> showTransactionNotification(Transaction transaction) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'transaction_channel',
      'Transaction Notifications',
      channelDescription: 'Notifications for incoming transactions',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: false, // We'll handle sound manually for more control
    );
    
    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false, // We'll handle sound manually
    );
    
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );
    
    final String title = 'รับเงินเข้าบัญชี ${transaction.bankName}';
    final String body = '${transaction.amount.toStringAsFixed(2)} บาท จาก ${transaction.senderInfo}\n${transaction.description}';
    
    await _flutterLocalNotificationsPlugin.show(
      transaction.id.hashCode,
      title,
      body,
      notificationDetails,
      payload: json.encode(transaction.toMap()),
    );
    
    // Play notification sound
    await playNotificationSound();
  }
  
  // Process bank notification text and create transaction
  Future<void> processPaymentNotification(
    String notificationText,
    String packageName,
  ) async {
    // Map package name to bank name
    String bankName = _mapPackageToBankName(packageName);
    
    // Check if this is a payment notification
    if (_isPaymentNotification(notificationText, bankName)) {
      // Parse transaction details using enhanced recognition if enabled
      final transaction = _enhancedRecognitionEnabled
          ? _enhancedTransactionParsing(notificationText, bankName)
          : Transaction.fromNotification(notificationText, bankName);
      
      // Save to local database
      await DatabaseService.instance.saveTransaction(transaction);
      
      // Upload to Supabase if online, otherwise queue for later
      if (!_offlineMode) {
        try {
          await SupabaseService.instance.saveTransaction(transaction);
        } catch (e) {
          print('Error saving to Supabase (offline?): $e');
          _offlineMode = true;
          _pendingTransactions.add(transaction);
        }
      } else {
        _pendingTransactions.add(transaction);
      }
      
      // Show local notification with sound
      await showTransactionNotification(transaction);
    }
  }
  
  // Attempt to sync pending transactions when coming back online
  Future<void> syncPendingTransactions() async {
    if (_pendingTransactions.isEmpty) return;
    
    _offlineMode = false;
    
    final List<Transaction> failedTransactions = [];
    
    for (final transaction in _pendingTransactions) {
      try {
        await SupabaseService.instance.saveTransaction(transaction);
      } catch (e) {
        print('Failed to sync transaction: $e');
        failedTransactions.add(transaction);
        _offlineMode = true;
      }
    }
    
    // Keep only failed transactions in the queue
    _pendingTransactions.clear();
    _pendingTransactions.addAll(failedTransactions);
  }
  
  String _mapPackageToBankName(String packageName) {
    // Map common Thai bank application package names to bank names
    final Map<String, String> bankPackages = {
      'com.scb.phone': 'SCB',
      'com.kasikorn.retail.mbanking.wap': 'Kasikorn',
      'com.ktb.netbank': 'Krungthai',
      'com.bbl.mobilebanking': 'Bangkok Bank',
      'com.tmb.droid.mybiz': 'TMB',
      'th.co.uob.uobmbk': 'UOB',
      'com.tmbbank.tmb.retail.ios': 'TMB',
      'com.bay.mobilebanking.android': 'Krungsri',
      'com.cimb.clicks.th.uat': 'CIMB',
      'com.gsb.mymo': 'GSB',
      'com.baac.mbanking': 'BAAC',
      'th.co.truemoney.wallet': 'TrueMoney',
      'asia.scb.paynow': 'SCB Easy',
      'com.krungthai.next': 'Krungthai NEXT',
      'th.co.bankofayudhya.kma': 'Krungsri Mobile',
      'com.ttbbank.oneapp': 'ttb touch',
      // Add other banks as needed
    };
    
    return bankPackages[packageName] ?? 'Unknown Bank';
  }
  
  bool _isPaymentNotification(String notificationText, String bankName) {
    // Different patterns for different banks
    final Map<String, List<String>> paymentKeywords = {
      'SCB': ['รับเงิน', 'โอนเงิน', 'รายการเงินเข้า', 'เงินเข้าบัญชี', 'ได้รับเงิน'],
      'SCB Easy': ['รับเงิน', 'โอนเงิน', 'รายการเงินเข้า', 'เงินเข้าบัญชี', 'ได้รับเงิน'],
      'Kasikorn': ['รับโอน', 'เงินเข้าบัญชี', 'ได้รับเงิน', 'รับเงิน', 'โอนเงินเข้า'],
      'Krungthai': ['รับโอน', 'เงินเข้า', 'รายการโอนเงิน', 'เงินเข้าบัญชี'],
      'Krungthai NEXT': ['รับโอน', 'เงินเข้า', 'รายการโอนเงิน', 'เงินเข้าบัญชี'],
      'Bangkok Bank': ['เงินเข้าบัญชี', 'รับโอนเงิน', 'ได้รับโอนเงิน'],
      'TMB': ['เงินเข้า', 'รับโอน', 'เงินเข้าบัญชี'],
      'ttb touch': ['เงินเข้า', 'รับโอน', 'เงินเข้าบัญชี'],
      'Krungsri': ['เงินเข้าบัญชี', 'รับโอน', 'ได้รับเงิน'],
      'Krungsri Mobile': ['เงินเข้าบัญชี', 'รับโอน', 'ได้รับเงิน'],
      'UOB': ['เงินเข้า', 'รับโอน', 'โอนเงิน'],
      'CIMB': ['เงินเข้าบัญชี', 'รับเงิน', 'โอนเงิน'],
      'GSB': ['เงินเข้า', 'รับโอนเงิน', 'โอนเงิน'],
      'BAAC': ['รับเงิน', 'เงินเข้า', 'โอนเงินเข้า'],
      'TrueMoney': ['รับเงิน', 'เติมเงินเข้า', 'ได้รับเงิน'],
      'Default': ['รับเงิน', 'โอนเงิน', 'เงินเข้า', 'ได้รับเงิน', 'บัญชี', 'โอน'],
    };
    
    final keywords = paymentKeywords[bankName] ?? paymentKeywords['Default']!;
    
    // Check for exclusion words that indicate it's not a payment notification
    final List<String> exclusionKeywords = [
      'ถอนเงิน', 'เงินออก', 'ชำระเงิน', 'จ่าย', 'หักบัญชี',
      'withdrawal', 'payment', 'paid', 'bill', 'subscription'
    ];
    
    for (final exclusion in exclusionKeywords) {
      if (notificationText.toLowerCase().contains(exclusion.toLowerCase())) {
        return false; // This is likely not an incoming payment notification
      }
    }
    
    for (final keyword in keywords) {
      if (notificationText.toLowerCase().contains(keyword.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }
  
  // Enhanced transaction parsing with improved accuracy
  Transaction _enhancedTransactionParsing(String notificationText, String bankName) {
    // Default values
    String id = DateTime.now().millisecondsSinceEpoch.toString();
    double amount = 0.0;
    String accountNumber = '';
    String senderInfo = '';
    String description = '';
    DateTime timestamp = DateTime.now();
    bool isVerified = true;
    
    try {
      // Extract amount using regex to find money patterns
      final RegExp amountRegex = RegExp(r'(?:(?:THB|฿|บาท)\s*)([\d,]+\.?\d*)|([\d,]+\.?\d*)(?:\s*(?:THB|฿|บาท))');
      final amountMatch = amountRegex.firstMatch(notificationText);
      if (amountMatch != null) {
        String amountStr = (amountMatch.group(1) ?? amountMatch.group(2))!;
        amountStr = amountStr.replaceAll(',', '');
        amount = double.tryParse(amountStr) ?? 0.0;
      }
      
      // Extract account number (last 4 digits pattern usually)
      final RegExp accountRegex = RegExp(r'[xX*]{0,8}(\d{4})(?:\s|$|จาก|ไป)');
      final accountMatch = accountRegex.firstMatch(notificationText);
      if (accountMatch != null) {
        accountNumber = 'XXXX-XXX-XXX-' + accountMatch.group(1)!;
      }
      
      // Extract sender info based on bank's notification pattern
      senderInfo = _extractSenderInfo(notificationText, bankName);
      
      // Extract any description or reference
      description = _extractDescription(notificationText, bankName);
      
      // Try to parse date/time from notification if available
      timestamp = _extractTimestamp(notificationText) ?? DateTime.now();
    } catch (e) {
      print('Error in enhanced parsing: $e');
      // Fallback to simple parsing if enhanced parsing fails
      return Transaction.fromNotification(notificationText, bankName);
    }
    
    return Transaction(
      id: id,
      amount: amount,
      bankName: bankName,
      accountNumber: accountNumber,
      senderInfo: senderInfo,
      description: description,
      timestamp: timestamp,
      isVerified: isVerified,
      rawNotificationText: notificationText,
    );
  }
  
  String _extractSenderInfo(String text, String bankName) {
    // Bank-specific patterns for sender information
    switch (bankName) {
      case 'SCB':
      case 'SCB Easy':
        // Example: "รับเงินจาก สมชาย ใจดี"
        final regexFrom = RegExp(r'(?:จาก|from)\s+([^\s\d](?:[^\d]+[^\s\d])?)(?:\s|$)');
        final matchFrom = regexFrom.firstMatch(text);
        if (matchFrom != null) {
          return matchFrom.group(1)!.trim();
        }
        break;
        
      case 'Kasikorn':
        // Example: "เงินเข้าบัญชีจาก วิชัย รักเงิน"
        final regexFrom = RegExp(r'(?:จาก|from)\s+([^\s\d](?:[^\d]+[^\s\d])?)(?:\s|$)');
        final matchFrom = regexFrom.firstMatch(text);
        if (matchFrom != null) {
          return matchFrom.group(1)!.trim();
        }
        break;
        
      default:
        // Generic approach: Try to find "from" patterns in Thai and English
        final possiblePatterns = [
          RegExp(r'(?:จาก|from)\s+([^\s\d](?:[^\d]+[^\s\d])?)(?:\s|$)'),
          RegExp(r'(?<=โดย\s)([^\s\d][^\d]+[^\s\d])'),
          RegExp(r'(?:โอนจาก|transferred from)\s+([^\s\d][^\d]+[^\s\d])'),
        ];
        
        for (final pattern in possiblePatterns) {
          final match = pattern.firstMatch(text);
          if (match != null && match.group(1) != null) {
            return match.group(1)!.trim();
          }
        }
        
        // If no pattern matched, try to find a name-like part (not containing digits)
        final words = text.split(RegExp(r'\s+'));
        for (final word in words) {
          if (word.length > 3 && !word.contains(RegExp(r'\d')) && 
              !['บาท', 'THB', 'เงิน', 'โอน', 'รับ', 'จาก', 'ถึง', 'บัญชี'].contains(word)) {
            return word.trim();
          }
        }
    }
    
    return 'Unknown';
  }
  
  String _extractDescription(String text, String bankName) {
    // Try to find reference or description patterns based on bank name
    switch (bankName) {
      case 'SCB':
      case 'SCB Easy':
        // Find reference after "ข้อความ" or "รายละเอียด"
        final regexMsg = RegExp(r'(?:ข้อความ|รายละเอียด|ref)[:\s]+([^\.]+)');
        final matchMsg = regexMsg.firstMatch(text);
        if (matchMsg != null) {
          return matchMsg.group(1)!.trim();
        }
        break;
        
      case 'Kasikorn':
        // Find reference after "รายละเอียด" or "รายการ"
        final regexMsg = RegExp(r'(?:รายละเอียด|รายการ|ref)[:\s]+([^\.]+)');
        final matchMsg = regexMsg.firstMatch(text);
        if (matchMsg != null) {
          return matchMsg.group(1)!.trim();
        }
        break;
        
      default:
        // Generic approach to find reference
        final possiblePatterns = [
          RegExp(r'(?:ข้อความ|รายละเอียด|ref|รายการ|หมายเหตุ|message)[:\s]+([^\.]+)'),
          RegExp(r'(?<=\n)([^:]+)(?:\n|$)'),  // Line containing no colon
        ];
        
        for (final pattern in possiblePatterns) {
          final match = pattern.firstMatch(text);
          if (match != null && match.group(1) != null) {
            final desc = match.group(1)!.trim();
            // Filter out common non-description phrases
            if (desc.length > 2 && 
                !desc.contains('บาท') && 
                !desc.contains('THB') &&
                !desc.contains('บัญชี')) {
              return desc;
            }
          }
        }
    }
    
    return '';
  }
  
  DateTime? _extractTimestamp(String text) {
    // Try to find date and time patterns
    try {
      // Common date-time formats in Thai bank notifications
      final dateTimePatterns = [
        // DD/MM/YY HH:mm
        RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})\s+(\d{1,2}):(\d{2})'),
        // HH:mm DD/MM/YY
        RegExp(r'(\d{1,2}):(\d{2})\s+(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})'),
        // Thai date format
        RegExp(r'(\d{1,2})\s+(ม\.?ค\.?|ก\.?พ\.?|มี\.?ค\.?|เม\.?ย\.?|พ\.?ค\.?|มิ\.?ย\.?|ก\.?ค\.?|ส\.?ค\.?|ก\.?ย\.?|ต\.?ค\.?|พ\.?ย\.?|ธ\.?ค\.?)\s+(\d{2,4})\s+(\d{1,2}):(\d{2})'),
      ];
      
      for (final pattern in dateTimePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          if (match.groupCount == 5 && match.pattern.toString().startsWith(r'(\d{1,2})[/.-]')) {
            // Format: DD/MM/YY HH:mm
            final day = int.parse(match.group(1)!);
            final month = int.parse(match.group(2)!);
            int year = int.parse(match.group(3)!);
            if (year < 100) year += 2000; // Adjust 2-digit year
            final hour = int.parse(match.group(4)!);
            final minute = int.parse(match.group(5)!);
            
            return DateTime(year, month, day, hour, minute);
          } else if (match.groupCount == 5 && match.pattern.toString().startsWith(r'(\d{1,2}):')) {
            // Format: HH:mm DD/MM/YY
            final hour = int.parse(match.group(1)!);
            final minute = int.parse(match.group(2)!);
            final day = int.parse(match.group(3)!);
            final month = int.parse(match.group(4)!);
            int year = int.parse(match.group(5)!);
            if (year < 100) year += 2000; // Adjust 2-digit year
            
            return DateTime(year, month, day, hour, minute);
          } else if (match.groupCount == 5 && match.group(2)!.contains('.')) {
            // Thai month abbreviation format
            final day = int.parse(match.group(1)!);
            int month = _getThaiMonth(match.group(2)!);
            int year = int.parse(match.group(3)!);
            if (year < 100) year += 2000; // Adjust 2-digit year
            final hour = int.parse(match.group(4)!);
            final minute = int.parse(match.group(5)!);
            
            return DateTime(year, month, day, hour, minute);
          }
        }
      }
      
      // If no explicit date/time, check if there's a relative time reference
      final now = DateTime.now();
      if (text.toLowerCase().contains('ขณะนี้') || 
          text.toLowerCase().contains('เมื่อสักครู่') || 
          text.toLowerCase().contains('just now')) {
        return now;
      } else if (text.toLowerCase().contains('วันนี้') || text.toLowerCase().contains('today')) {
        // Today with possible time
        final timePattern = RegExp(r'(\d{1,2}):(\d{2})');
        final timeMatch = timePattern.firstMatch(text);
        if (timeMatch != null) {
          final hour = int.parse(timeMatch.group(1)!);
          final minute = int.parse(timeMatch.group(2)!);
          return DateTime(now.year, now.month, now.day, hour, minute);
        }
        return DateTime(now.year, now.month, now.day);
      } else if (text.toLowerCase().contains('เมื่อวาน') || text.toLowerCase().contains('yesterday')) {
        // Yesterday with possible time
        final yesterday = now.subtract(const Duration(days: 1));
        final timePattern = RegExp(r'(\d{1,2}):(\d{2})');
        final timeMatch = timePattern.firstMatch(text);
        if (timeMatch != null) {
          final hour = int.parse(timeMatch.group(1)!);
          final minute = int.parse(timeMatch.group(2)!);
          return DateTime(yesterday.year, yesterday.month, yesterday.day, hour, minute);
        }
        return DateTime(yesterday.year, yesterday.month, yesterday.day);
      }
    } catch (e) {
      print('Error parsing timestamp: $e');
    }
    
    return null;
  }
  
  int _getThaiMonth(String thaiMonth) {
    final Map<String, int> thaiMonths = {
      'ม.ค.': 1, 'มค': 1, 'มกราคม': 1,
      'ก.พ.': 2, 'กพ': 2, 'กุมภาพันธ์': 2,
      'มี.ค.': 3, 'มีค': 3, 'มีนาคม': 3,
      'เม.ย.': 4, 'เมย': 4, 'เมษายน': 4,
      'พ.ค.': 5, 'พค': 5, 'พฤษภาคม': 5,
      'มิ.ย.': 6, 'มิย': 6, 'มิถุนายน': 6,
      'ก.ค.': 7, 'กค': 7, 'กรกฎาคม': 7,
      'ส.ค.': 8, 'สค': 8, 'สิงหาคม': 8,
      'ก.ย.': 9, 'กย': 9, 'กันยายน': 9,
      'ต.ค.': 10, 'ตค': 10, 'ตุลาคม': 10,
      'พ.ย.': 11, 'พย': 11, 'พฤศจิกายน': 11,
      'ธ.ค.': 12, 'ธค': 12, 'ธันวาคม': 12,
    };
    
    for (final entry in thaiMonths.entries) {
      if (thaiMonth.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return 1; // Default to January if no match
  }

  Future<void> _preloadSounds() async {
    try {
      for (final sound in availableSounds) {
        final file = await _getAudioFile(sound);
        if (file.existsSync()) {
          await _audioPlayer.audioCache.load(sound);
        }
      }
    } catch (e) {
      debugPrint('Error preloading sounds: $e');
    }
  }
  
  Future<File> _getAudioFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    
    if (!file.existsSync()) {
      // Copy from assets to local storage
      final byteData = await rootBundle.load('assets/sounds/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    
    return file;
  }
  
  Future<void> saveSettings({
    bool? enableSound,
    double? soundVolume,
    String? selectedSound,
    bool? enableVibration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (enableSound != null) {
        _enableSound = enableSound;
        await prefs.setBool(_enableSoundKey, enableSound);
      }
      
      if (soundVolume != null) {
        _soundVolume = soundVolume;
        await prefs.setDouble(_soundVolumeKey, soundVolume);
      }
      
      if (selectedSound != null) {
        _selectedSound = selectedSound;
        await prefs.setString(_selectedSoundKey, selectedSound);
      }
      
      if (enableVibration != null) {
        _enableVibration = enableVibration;
        await prefs.setBool(_enableVibrationKey, enableVibration);
      }
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }
  
  // Getters for current settings
  bool get enableSound => _enableSound;
  double get soundVolume => _soundVolume;
  String get selectedSound => _selectedSound;
  bool get enableVibration => _enableVibration;
  
  // Play notification sound based on user settings
  Future<void> playNotificationSound() async {
    if (_enableSound) {
      try {
        // Check if the device supports vibration
        if (_enableVibration && await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 300);
        }
        
        // Play the selected sound with the chosen volume
        await _audioPlayer.setVolume(_soundVolume);
        await _audioPlayer.play(AssetSource('sounds/$_selectedSound'));
      } catch (e) {
        debugPrint('Error playing notification sound: $e');
      }
    }
  }
  
  // Show a local notification with the amount received
  Future<void> showTransactionNotification({
    required String title,
    required String body,
    required double amount,
    String? bankName,
    String? sender,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'payment_channel',
      'Payment Notifications',
      channelDescription: 'Notifications for payment received',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: false, // We'll handle sound manually
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false, // We'll handle sound manually
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    
    // Format the notification details
    final formattedBody = sender != null 
        ? '$body\nจาก: $sender' 
        : body;
    
    final bankInfo = bankName != null ? ' ($bankName)' : '';
    final formattedTitle = '$title$bankInfo';
    
    await _flutterLocalNotificationsPlugin.show(
      0,
      formattedTitle,
      formattedBody,
      platformChannelSpecifics,
    );
    
    // Play notification sound
    await playNotificationSound();
  }
  
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    // Handle notification tap
    // You can navigate to a specific screen if needed
    debugPrint('Notification tapped: ${notificationResponse.payload}');
  }
  
  // Request necessary permissions
  Future<bool> requestNotificationPermissions() async {
    try {
      // For iOS
      if (Platform.isIOS) {
        final result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return result ?? false;
      }
      // For Android
      else if (Platform.isAndroid) {
        final result = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestPermission();
        return result ?? false;
      }
      return false;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }
}