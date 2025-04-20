import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pay_notify/models/transaction.dart';
import 'package:pay_notify/services/database_service.dart';
import 'package:pay_notify/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    
    await _loadSoundPreferences();
  }
  
  Future<void> _loadSoundPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _selectedSoundPath = prefs.getString('selected_sound_path') ?? 'assets/sounds/cash_register.mp3';
    _soundVolume = prefs.getDouble('sound_volume') ?? 0.5;
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
      // Create transaction from notification
      final transaction = Transaction.fromNotification(
        notificationText, 
        bankName,
      );
      
      // Save to local database
      await DatabaseService.instance.saveTransaction(transaction);
      
      // Upload to Supabase
      await SupabaseService.instance.saveTransaction(transaction);
      
      // Show local notification with sound
      await showTransactionNotification(transaction);
    }
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
      // Add other banks as needed
    };
    
    return bankPackages[packageName] ?? 'Unknown Bank';
  }
  
  bool _isPaymentNotification(String notificationText, String bankName) {
    // Different patterns for different banks
    final Map<String, List<String>> paymentKeywords = {
      'SCB': ['รับเงิน', 'โอนเงิน', 'รายการเงินเข้า'],
      'Kasikorn': ['รับโอน', 'เงินเข้าบัญชี', 'ได้รับเงิน'],
      'Krungthai': ['รับโอน', 'เงินเข้า', 'รายการโอนเงิน'],
      'Bangkok Bank': ['เงินเข้าบัญชี', 'รับโอนเงิน'],
      'TMB': ['เงินเข้า', 'รับโอน'],
      'Default': ['รับเงิน', 'โอนเงิน', 'เงินเข้า', 'ได้รับเงิน'],
    };
    
    final keywords = paymentKeywords[bankName] ?? paymentKeywords['Default']!;
    
    for (final keyword in keywords) {
      if (notificationText.toLowerCase().contains(keyword.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }
}