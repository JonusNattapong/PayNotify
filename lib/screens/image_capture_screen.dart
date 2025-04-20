import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class ImageCaptureScreen extends StatefulWidget {
  @override
  _ImageCaptureScreenState createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  File? _image;
  Transaction? _result;
  bool _processing = false;
  String _error = '';
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('สแกนสลิปโอนเงิน'),
        actions: [
          if (_image != null)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _resetScreen,
            ),
        ],
      ),
      body: _processing
          ? _buildProcessingView()
          : _result != null
              ? _buildResultView()
              : _buildCaptureView(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('กำลังประมวลผลภาพ...'),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    if (_result == null) return SizedBox();
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_image != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(_image!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          SizedBox(height: 16),
          Text('ผลการสแกน:', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: 8),
          _buildResultCard(),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveTransaction,
            child: Text('บันทึก'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('จำนวนเงิน: ${_result!.amount} บาท'),
            Text('ธนาคาร: ${_result!.bankName}'),
            Text('เลขบัญชี: ${_result!.accountNumber}'),
            Text('ผู้โอน: ${_result!.senderInfo}'),
            if (_result!.description.isNotEmpty)
              Text('รายละเอียด: ${_result!.description}'),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_image != null) ...[
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: FileImage(_image!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _processImage,
              child: Text('ประมวลผล'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 48),
              ),
            ),
          ] else
            Text('เลือกรูปภาพหรือถ่ายภาพสลิปโอนเงิน'),
          if (_error.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                _error,
                style: TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_processing || _result != null) return SizedBox();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _getImage(ImageSource.camera),
                icon: Icon(Icons.camera_alt),
                label: Text('ถ่ายภาพ'),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _getImage(ImageSource.gallery),
                icon: Icon(Icons.photo_library),
                label: Text('เลือกรูป'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _error = '';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'เกิดข้อผิดพลาดในการเลือกรูปภาพ';
      });
    }
  }

  Future<void> _processImage() async {
    if (_image == null) return;

    setState(() {
      _processing = true;
      _error = '';
    });

    try {
      // Check OCR availability
      final isAvailable = await OCRService.instance.isOCRAvailable();
      if (!isAvailable) {
        throw Exception('OCR service is not available');
      }

      // Process image
      final result = await OCRService.instance.processTransferImage(_image!.path);
      
      if (result != null) {
        setState(() {
          _result = result;
          _processing = false;
        });
      } else {
        throw Exception('Could not extract information from image');
      }
    } catch (e) {
      setState(() {
        _error = 'ไม่สามารถประมวลผลรูปภาพได้: ${e.toString()}';
        _processing = false;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_result == null) return;

    try {
      await DatabaseService.instance.saveTransaction(_result!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกข้อมูลสำเร็จ')),
      );
      Navigator.pop(context, _result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล')),
      );
    }
  }

  void _resetScreen() {
    setState(() {
      _image = null;
      _result = null;
      _error = '';
    });
  }
}