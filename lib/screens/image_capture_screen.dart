import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:screenshot/screenshot.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({Key? key}) : super(key: key);

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isProcessing = false;
  String _extractedText = '';
  Transaction? _extractedTransaction;
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService.instance;
  final ScreenshotController _screenshotController = ScreenshotController();

  // Enhanced bank patterns for better recognition
  final Map<String, Map<String, dynamic>> _bankPatterns = {
    'scb': {
      'name': 'SCB',
      'fullName': 'ธนาคารไทยพาณิชย์',
      'patterns': [
        RegExp(r'(?:scb|ไทยพาณิชย์|siam commercial)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับโอน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
    'kbank': {
      'name': 'KBANK',
      'fullName': 'ธนาคารกสิกรไทย',
      'patterns': [
        RegExp(r'(?:kbank|กสิกร|kasikorn)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับเงิน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
    'ktb': {
      'name': 'KTB',
      'fullName': 'ธนาคารกรุงไทย',
      'patterns': [
        RegExp(r'(?:ktb|krungthai|กรุงไทย)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับโอน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
    'bbl': {
      'name': 'BBL',
      'fullName': 'ธนาคารกรุงเทพ',
      'patterns': [
        RegExp(r'(?:bbl|bangkok bank|กรุงเทพ)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับเงิน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
    'ttb': {
      'name': 'TTB',
      'fullName': 'ธนาคารทหารไทยธนชาต',
      'patterns': [
        RegExp(r'(?:ttb|tmb|thanachart|ทหารไทย|ธนชาต)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับโอน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
    'uob': {
      'name': 'UOB',
      'fullName': 'ธนาคารยูโอบี',
      'patterns': [
        RegExp(r'(?:uob|tmrw|ยูโอบี)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับโอน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
    'bay': {
      'name': 'BAY',
      'fullName': 'ธนาคารกรุงศรีอยุธยา',
      'patterns': [
        RegExp(r'(?:bay|krungsri|กรุงศรี|อยุธยา)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับโอน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
    'gsb': {
      'name': 'GSB',
      'fullName': 'ธนาคารออมสิน',
      'patterns': [
        RegExp(r'(?:gsb|ออมสิน)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับเงิน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
    'baac': {
      'name': 'BAAC',
      'fullName': 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร',
      'patterns': [
        RegExp(r'(?:baac|ธกส|เพื่อการเกษตร)'),
        RegExp(r'(?:เงินเข้า|โอนเงิน|รับโอน)[^0-9]*([0-9,.]+)(?:บาท)?', caseSensitive: false),
      ]
    },
  };

  // Enhanced pattern recognition
  final RegExp _amountPattern = RegExp(r'(?:จำนวนเงิน|โอนเงิน|ได้รับเงิน|รับโอนเงิน|เงินเข้า|รับเงิน|money received|amount)[^\d]*([\d,]+\.?\d*)', caseSensitive: false);
  final RegExp _senderNamePattern = RegExp(r'(?:จาก|โดย|from)[^\w]*([ก-๙a-zA-Z0-9\s.]{2,})', caseSensitive: false);
  final RegExp _accountNumberPattern = RegExp(r'(?:เลขที่บัญชี|บัญชี|account|acc.)[^\d]*(\d{10}|\d{3}-\d-\d{5}-\d|\d{3}-\d{6}-\d)', caseSensitive: false);
  final RegExp _timestampPattern = RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})\s*\d{1,2}:\d{2}(?::\d{2})?', caseSensitive: false);

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        // Compress the image for better OCR performance
        final compressedImage = await _compressImage(File(pickedFile.path));
        
        setState(() {
          _imageFile = compressedImage;
          _extractedText = '';
          _extractedTransaction = null;
          _isProcessing = true;
        });

        await _processImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // New method to compress images for better OCR
  Future<File> _compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";
    
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 95,
      minWidth: 1024,
      minHeight: 1024,
    );
    
    return File(result?.path ?? file.path);
  }

  Future<void> _captureScreenshot() async {
    try {
      setState(() {
        _isProcessing = true;
      });
      
      final image = await _screenshotController.capture();
      if (image == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่สามารถจับภาพหน้าจอได้')),
        );
        return;
      }
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/screenshot.png');
      await file.writeAsBytes(image);
      
      setState(() {
        _imageFile = file;
      });
      
      await _processImage();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการจับภาพหน้าจอ: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    try {
      // Enhanced text recognition with improved options
      final textRecognizer = GoogleMlKit.vision.textRecognizer(script: TextRecognitionScript.thai);
      final inputImage = InputImage.fromFile(_imageFile!);
      final recognizedText = await textRecognizer.processImage(inputImage);

      setState(() {
        _extractedText = recognizedText.text;
      });
      
      // Enhanced transaction data parsing with multiple attempts
      final transaction = _parseTransactionData(recognizedText.text);
      if (transaction != null) {
        setState(() {
          _extractedTransaction = transaction;
        });
        
        // Save the transaction
        await _saveTransaction(transaction);
      }

      // Release resources
      textRecognizer.close();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('การวิเคราะห์ภาพล้มเหลว: ${e.toString()}')),
      );
    }
  }

  Transaction? _parseTransactionData(String text) {
    try {
      // Convert to lowercase for easier matching
      final fullText = text;
      final lowerText = text.toLowerCase();

      // Initialize variables
      double? amount;
      String? sender;
      String? bankName;
      String? accountNumber;
      DateTime? timestamp;
      
      // Try to detect bank by keywords
      String detectedBank = 'ไม่ระบุ';
      String fullBankName = 'ไม่ระบุธนาคาร';
      
      // Enhanced bank detection
      for (var entry in _bankPatterns.entries) {
        final bank = entry.value;
        final namePattern = bank['patterns'][0];
        
        if (namePattern.hasMatch(lowerText)) {
          detectedBank = bank['name'];
          fullBankName = bank['fullName'];
          break;
        }
      }
      
      // Extract the amount using the enhanced pattern
      final amountMatch = _amountPattern.firstMatch(fullText);
      if (amountMatch != null) {
        final amountStr = amountMatch.group(1)?.replaceAll(',', '') ?? '0';
        amount = double.tryParse(amountStr);
      }
      
      // Extract sender name
      final senderMatch = _senderNamePattern.firstMatch(fullText);
      if (senderMatch != null) {
        sender = senderMatch.group(1)?.trim();
      }
      
      // Extract account number
      final accountMatch = _accountNumberPattern.firstMatch(fullText);
      if (accountMatch != null) {
        accountNumber = accountMatch.group(1)?.trim();
      }
      
      // Extract timestamp if available
      final timestampMatch = _timestampPattern.firstMatch(fullText);
      if (timestampMatch != null) {
        final dateStr = timestampMatch.group(0) ?? '';
        try {
          // Handle various date formats
          if (dateStr.contains(':')) {
            timestamp = DateTime.parse(dateStr.replaceAll('/', '-'));
          }
        } catch (_) {
          // If parsing fails, use current timestamp
          timestamp = DateTime.now();
        }
      } else {
        timestamp = DateTime.now();
      }
      
      // Check if we have at least an amount
      if (amount != null) {
        // Create the transaction object with all extracted data
        final transaction = Transaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          amount: amount,
          bankName: fullBankName,
          accountNumber: accountNumber ?? '',
          senderInfo: sender ?? 'ไม่ระบุ',
          description: 'วิเคราะห์จากรูปภาพ',
          timestamp: timestamp ?? DateTime.now(),
          isVerified: false,
          rawNotificationText: fullText,
        );
        
        return transaction;
      }
    } catch (e) {
      debugPrint('Error parsing transaction data: $e');
    }
    
    return null;
  }

  Future<void> _saveTransaction(Transaction transaction) async {
    try {
      // Save image file if available
      if (_imageFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${transaction.id}${path.extension(_imageFile!.path)}';
        final savedImage = await _imageFile!.copy('${directory.path}/$fileName');
        
        // Update transaction with image path
        transaction = transaction.copyWith(
          imagePath: savedImage.path,
        );
      }
      
      // Save transaction to local database
      await _databaseService.insertTransaction(transaction);
      
      // Save to Supabase if connected
      try {
        await SupabaseService.instance.addTransaction(transaction);
      } catch (e) {
        debugPrint('Failed to save to Supabase: $e');
      }
      
      // Show notification with sound
      await _notificationService.showTransactionNotification(
        title: 'ได้รับเงิน ${transaction.amount.toString()} บาท',
        body: 'จาก: ${transaction.senderInfo}, ธนาคาร: ${transaction.bankName}',
      );
      
      // Play notification sound
      _notificationService.playNotificationSound();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลการโอนเงินเรียบร้อยแล้ว')),
      );
      
      // Navigate back if the OCR was successful
      Navigator.pop(context, transaction);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล: ${e.toString()}')),
      );
    }
  }
  
  // Manual data entry form
  Future<void> _showManualEntryForm() async {
    final amountController = TextEditingController();
    final senderController = TextEditingController();
    final bankController = TextEditingController();
    final accountController = TextEditingController();
    final descriptionController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ป้อนข้อมูลการโอนเงินเอง'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'จำนวนเงิน (บาท)',
                    hintText: 'เช่น 1000.50',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: senderController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อผู้ส่ง',
                    hintText: 'เช่น นายทดสอบ ระบบดี',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bankController,
                  decoration: const InputDecoration(
                    labelText: 'ธนาคาร',
                    hintText: 'เช่น กสิกรไทย, SCB',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accountController,
                  decoration: const InputDecoration(
                    labelText: 'เลขบัญชี (ถ้ามี)',
                    hintText: 'เช่น xxx-x-xxxxx-x',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียดเพิ่มเติม',
                    hintText: 'เช่น ชำระค่าสินค้า',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate
                if (amountController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('กรุณาระบุจำนวนเงิน')),
                  );
                  return;
                }
                
                final amount = double.tryParse(amountController.text);
                if (amount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('จำนวนเงินไม่ถูกต้อง')),
                  );
                  return;
                }
                
                // Create transaction
                final transaction = Transaction(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  amount: amount,
                  bankName: bankController.text.isNotEmpty ? bankController.text : 'ไม่ระบุ',
                  accountNumber: accountController.text,
                  senderInfo: senderController.text.isNotEmpty ? senderController.text : 'ไม่ระบุ',
                  description: descriptionController.text,
                  timestamp: DateTime.now(),
                  isVerified: true,  // Manual entry is considered verified
                  rawNotificationText: 'บันทึกด้วยตนเอง',
                );
                
                // Save transaction
                await _saveTransaction(transaction);
                
                // Close dialog and return to previous screen
                if (context.mounted) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(transaction);
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('วิเคราะห์การแจ้งเตือน'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'ป้อนข้อมูลด้วยตนเอง',
            onPressed: _showManualEntryForm,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'สำหรับผู้ใช้ iOS หรือกรณีที่การตรวจจับอัตโนมัติไม่ทำงาน คุณสามารถถ่ายภาพหน้าจอการแจ้งเตือนหรืออัปโหลดภาพเพื่อวิเคราะห์ข้อมูลการโอนเงิน',
                style: TextStyle(fontSize: 16.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('ถ่ายภาพ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _getImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('เลือกภาพ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  if (Platform.isIOS)
                    ElevatedButton.icon(
                      onPressed: _captureScreenshot,
                      icon: const Icon(Icons.screenshot),
                      label: const Text('จับภาพหน้าจอ'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isProcessing)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    const Text('กำลังวิเคราะห์ข้อมูล...'),
                  ],
                )
              else if (_imageFile != null) ...[
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _imageFile!,
                        height: 300,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_extractedTransaction != null) ...[
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ข้อมูลที่วิเคราะห์ได้:',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.attach_money, color: Colors.green),
                            title: const Text('จำนวนเงิน'),
                            subtitle: Text(
                              '${_extractedTransaction!.amount} บาท',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          if (_extractedTransaction!.senderInfo.isNotEmpty &&
                              _extractedTransaction!.senderInfo != 'ไม่ระบุ')
                            ListTile(
                              leading: const Icon(Icons.person),
                              title: const Text('จาก'),
                              subtitle: Text(_extractedTransaction!.senderInfo),
                            ),
                          ListTile(
                            leading: const Icon(Icons.account_balance),
                            title: const Text('ธนาคาร'),
                            subtitle: Text(_extractedTransaction!.bankName),
                          ),
                          if (_extractedTransaction!.accountNumber.isNotEmpty)
                            ListTile(
                              leading: const Icon(Icons.credit_card),
                              title: const Text('เลขบัญชี'),
                              subtitle: Text(_extractedTransaction!.accountNumber),
                            ),
                          ListTile(
                            leading: const Icon(Icons.access_time),
                            title: const Text('เวลา'),
                            subtitle: Text(
                              '${_extractedTransaction!.timestamp.day}/${_extractedTransaction!.timestamp.month}/${_extractedTransaction!.timestamp.year} ${_extractedTransaction!.timestamp.hour}:${_extractedTransaction!.timestamp.minute.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showManualEntryForm,
                        icon: const Icon(Icons.edit),
                        label: const Text('แก้ไขข้อมูล'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, _extractedTransaction),
                        icon: const Icon(Icons.check),
                        label: const Text('ยืนยันข้อมูล'),
                      ),
                    ],
                  ),
                ] else if (_extractedText.isNotEmpty) ...[
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange),
                              const SizedBox(width: 8),
                              const Text('ไม่สามารถวิเคราะห์ข้อมูลได้โดยอัตโนมัติ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  )),
                            ],
                          ),
                          const Divider(),
                          const Text('ข้อความที่สกัดได้:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _extractedText,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              onPressed: _showManualEntryForm,
                              icon: const Icon(Icons.add),
                              label: const Text('ป้อนข้อมูลด้วยตนเอง'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              if (!_isProcessing && _imageFile == null)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.info_outline, size: 36, color: Colors.blue),
                        const SizedBox(height: 8),
                        const Text(
                          'คำแนะนำสำหรับการสแกนภาพที่ดีที่สุด',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• ถ่ายภาพหน้าจอการแจ้งเตือนให้ชัดเจน\n'
                          '• ตรวจสอบให้แน่ใจว่าข้อความในภาพอ่านได้ง่าย\n'
                          '• หลีกเลี่ยงแสงสะท้อนและเงาบนหน้าจอ\n'
                          '• สำหรับผู้ใช้ iOS สามารถใช้คุณสมบัติจับภาพหน้าจอได้',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}