import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pay_notify/services/notification_service.dart';

class NotificationListenerService extends ChangeNotifier {
  static const platform = MethodChannel('com.paynotify/notification_listener');
  
  bool _isServiceRunning = false;
  bool get isServiceRunning => _isServiceRunning;
  
  NotificationListenerService() {
    _initNotificationListenerChannel();
    _checkServiceStatus();
  }
  
  void _initNotificationListenerChannel() {
    platform.setMethodCallHandler(_handleMethodCall);
  }
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch(call.method) {
      case 'onNotificationReceived':
        final Map<String, dynamic> arguments = call.arguments;
        final String packageName = arguments['packageName'] ?? '';
        final String title = arguments['title'] ?? '';
        final String text = arguments['text'] ?? '';
        
        // Process the notification if it's from a banking app
        if (packageName.isNotEmpty && text.isNotEmpty) {
          await NotificationService.instance.processPaymentNotification(
            text, 
            packageName,
          );
          return true;
        }
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }
  
  Future<void> _checkServiceStatus() async {
    try {
      final bool isEnabled = await platform.invokeMethod('isNotificationServiceEnabled');
      _isServiceRunning = isEnabled;
      
      if (isEnabled) {
        await platform.invokeMethod('startService');
      }
      
      notifyListeners();
    } on PlatformException catch (e) {
      print('Error checking notification service status: ${e.message}');
    }
  }
  
  Future<void> requestNotificationPermission() async {
    try {
      final bool isEnabled = await platform.invokeMethod('isNotificationServiceEnabled');
      
      if (!isEnabled) {
        await openNotificationSettings();
      }
    } on PlatformException catch (e) {
      print('Error requesting notification permission: ${e.message}');
    }
  }
  
  Future<void> openNotificationSettings() async {
    try {
      await platform.invokeMethod('openNotificationListenerSettings');
    } on PlatformException catch (e) {
      print('Error opening notification settings: ${e.message}');
    }
  }
  
  Future<void> stopService() async {
    try {
      await platform.invokeMethod('stopService');
      _isServiceRunning = false;
      notifyListeners();
    } on PlatformException catch (e) {
      print('Error stopping service: ${e.message}');
    }
  }
  
  Future<void> startService() async {
    try {
      await platform.invokeMethod('startService');
      await _checkServiceStatus();
    } on PlatformException catch (e) {
      print('Error starting service: ${e.message}');
    }
  }
}