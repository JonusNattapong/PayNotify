import 'package:flutter/services.dart';

class OCRPlugin {
  static final OCRPlugin _instance = OCRPlugin._internal();
  static OCRPlugin get instance => _instance;

  final MethodChannel _methodChannel = const MethodChannel('com.paynotify/ocr');
  
  OCRPlugin._internal();

  Future<bool> isOCRAvailable() async {
    try {
      final bool available = await _methodChannel.invokeMethod('isOCRAvailable');
      return available;
    } on PlatformException catch (e) {
      print('OCR Availability Check Error: ${e.message}');
      return false;
    }
  }

  Future<void> setupOCR() async {
    try {
      await _methodChannel.invokeMethod('setupOCR');
    } on PlatformException catch (e) {
      print('OCR Setup Error: ${e.message}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> processImage(String imagePath) async {
    try {
      final Map<String, dynamic>? result = await _methodChannel.invokeMapMethod(
        'processTransferImage',
        {'imagePath': imagePath},
      );
      
      if (result == null) return null;
      
      // Validate and normalize the result
      return {
        'amount': _parseAmount(result['amount']),
        'bankName': result['bankName'] ?? 'Unknown',
        'accountNumber': result['accountNumber'] ?? '',
        'senderInfo': result['senderInfo'] ?? '',
        'rawText': result['rawText'] ?? '',
      };
    } on PlatformException catch (e) {
      print('OCR Processing Error: ${e.message}');
      return null;
    }
  }

  double _parseAmount(dynamic amount) {
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      try {
        return double.parse(amount.replaceAll(',', ''));
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }
}