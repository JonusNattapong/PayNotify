import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/transaction.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  static OCRService get instance => _instance;

  final MethodChannel _channel = const MethodChannel('com.paynotify/ocr');
  
  OCRService._internal();

  Future<Transaction?> processTransferImage(String imagePath) async {
    try {
      final result = await _channel.invokeMethod('processTransferImage', {
        'imagePath': imagePath,
      });

      if (result == null) return null;

      // Parse OCR result into Transaction object
      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        amount: result['amount'] ?? 0.0,
        bankName: result['bankName'] ?? 'Unknown',
        accountNumber: result['accountNumber'] ?? '',
        senderInfo: result['senderInfo'] ?? '',
        description: result['description'] ?? '',
        timestamp: DateTime.now(),
        rawNotificationText: result['rawText'] ?? '',
      );
    } on PlatformException catch (e) {
      print('OCR Error: ${e.message}');
      return null;
    }
  }

  Future<bool> isOCRAvailable() async {
    try {
      final bool available = await _channel.invokeMethod('isOCRAvailable');
      return available;
    } on PlatformException catch (e) {
      print('OCR Availability Check Error: ${e.message}');
      return false;
    }
  }

  Future<void> performOneTimeSetup() async {
    try {
      await _channel.invokeMethod('setupOCR');
    } on PlatformException catch (e) {
      print('OCR Setup Error: ${e.message}');
      rethrow;
    }
  }
}