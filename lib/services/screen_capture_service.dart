import 'dart:async';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';

class ScreenCaptureService {
  static final ScreenCaptureService _instance = ScreenCaptureService._internal();
  static ScreenCaptureService get instance => _instance;

  final MethodChannel _screenChannel = const MethodChannel('com.paynotify/screen_capture');
  final MethodChannel _ocrChannel = const MethodChannel('com.paynotify/ocr');
  
  final StreamController<Transaction> _transactionStreamController = 
      StreamController<Transaction>.broadcast();
  Stream<Transaction> get transactionStream => _transactionStreamController.stream;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  ScreenCaptureService._internal() {
    _setupMethodChannels();
  }

  void _setupMethodChannels() {
    _screenChannel.setMethodCallHandler(_handleScreenCaptureMethods);
    _ocrChannel.setMethodCallHandler(_handleOCRMethods);
  }

  Future<void> _handleScreenCaptureMethods(MethodCall call) async {
    switch (call.method) {
      case 'onTransactionDetected':
        final data = Map<String, dynamic>.from(call.arguments);
        await _processTransactionData(data);
        break;
        
      case 'onCaptureError':
        print('Screen capture error: ${call.arguments}');
        await stopCapture();
        break;
    }
  }

  Future<void> _handleOCRMethods(MethodCall call) async {
    switch (call.method) {
      case 'onOCRCompleted':
        final data = Map<String, dynamic>.from(call.arguments);
        await _processTransactionData(data);
        break;
        
      case 'onOCRError':
        print('OCR processing error: ${call.arguments}');
        break;
    }
  }

  Future<bool> startCapture() async {
    if (_isCapturing) return true;

    try {
      // Check and request permissions first
      final bool hasPermission = await _checkPermissions();
      if (!hasPermission) {
        return false;
      }

      // Start native screen capture service
      final bool started = await _screenChannel.invokeMethod('startCapture');
      if (started) {
        _isCapturing = true;
        print('Screen capture started successfully');
      }
      return started;
    } catch (e) {
      print('Error starting screen capture: $e');
      return false;
    }
  }

  Future<void> stopCapture() async {
    if (!_isCapturing) return;

    try {
      await _screenChannel.invokeMethod('stopCapture');
      _isCapturing = false;
      print('Screen capture stopped successfully');
    } catch (e) {
      print('Error stopping screen capture: $e');
    }
  }

  Future<bool> _checkPermissions() async {
    try {
      // Check platform-specific permissions
      if (Platform.isAndroid) {
        final bool? hasAccess = await _screenChannel.invokeMethod('checkAccessibilityPermission');
        if (hasAccess != true) {
          // Open accessibility settings
          await _screenChannel.invokeMethod('openAccessibilitySettings');
          return false;
        }
      } else if (Platform.isIOS) {
        final bool? hasScreenRecord = await _screenChannel.invokeMethod('checkScreenRecordingPermission');
        if (hasScreenRecord != true) {
          // Request screen recording permission
          return await _screenChannel.invokeMethod('requestScreenRecordingPermission');
        }
        return true;
      }
      return true;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  Future<void> _processTransactionData(Map<String, dynamic> data) async {
    try {
      if (data['amount'] == null || (data['amount'] as num) <= 0) {
        return; // Invalid transaction data
      }

      final transaction = Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: (data['amount'] as num).toDouble(),
        bankName: data['bankName'] ?? 'Unknown',
        accountNumber: data['accountNumber'] ?? '',
        senderInfo: data['senderInfo'] ?? '',
        description: data['description'] ?? '',
        timestamp: DateTime.now(),
        rawNotificationText: data['rawText'] ?? '',
        isVerified: true,
      );

      // Save to database
      await DatabaseService.instance.saveTransaction(transaction);

      // Show notification
      await NotificationService.instance.showTransactionNotification(transaction);

      // Notify listeners
      _transactionStreamController.add(transaction);

    } catch (e) {
      print('Error processing transaction data: $e');
    }
  }

  Future<void> dispose() async {
    await stopCapture();
    await _transactionStreamController.close();
  }
}