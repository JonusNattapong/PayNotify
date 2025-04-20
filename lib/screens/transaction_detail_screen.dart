import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pay_notify/models/transaction.dart';
import 'package:pay_notify/services/supabase_service.dart';
import 'package:pay_notify/services/database_service.dart';
import 'package:pay_notify/services/notification_service.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;
  
  const TransactionDetailScreen({
    Key? key,
    required this.transaction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'th_TH',
      symbol: '฿',
      decimalDigits: 2,
    );
    
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm:ss', 'th');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียดธุรกรรม'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle),
            tooltip: 'เล่นเสียงแจ้งเตือน',
            onPressed: () => NotificationService.instance.playNotificationSound(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareTransaction(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('ลบรายการ'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmountCard(context, currencyFormat),
            const SizedBox(height: 24),
            _buildDetailsSection(context, dateFormat),
            const SizedBox(height: 24),
            if (transaction.rawNotificationText.isNotEmpty)
              _buildRawNotificationSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, NumberFormat currencyFormat) {
    return Card(
      color: Theme.of(context).colorScheme.primary,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'ยอดเงิน',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(transaction.amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    transaction.isVerified ? 'ยืนยันแล้ว' : 'รอการยืนยัน',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, DateFormat dateFormat) {
    final infoItems = [
      {'label': 'ผู้ส่ง', 'value': transaction.senderInfo},
      {'label': 'ธนาคาร', 'value': transaction.bankName},
      {'label': 'บัญชีปลายทาง', 'value': transaction.accountNumber},
      {'label': 'วันและเวลา', 'value': dateFormat.format(transaction.timestamp)},
      if (transaction.description.isNotEmpty)
        {'label': 'รายละเอียด', 'value': transaction.description},
      {'label': 'Transaction ID', 'value': transaction.id},
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รายละเอียดการโอน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...infoItems.map((item) => _buildInfoRow(context, item['label']!, item['value']!)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(context, value),
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawNotificationSection(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ข้อความแจ้งเตือนดิบ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copyToClipboard(context, transaction.rawNotificationText),
                ),
              ],
            ),
            const Divider(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                transaction.rawNotificationText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('คัดลอกไปยังคลิปบอร์ดแล้ว'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareTransaction(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'th_TH',
      symbol: '฿',
      decimalDigits: 2,
    );
    
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    final String shareText = '''
💰 รายการเงินเข้า PayNotify 💰
จำนวน: ${currencyFormat.format(transaction.amount)}
จาก: ${transaction.senderInfo}
ธนาคาร: ${transaction.bankName}
เวลา: ${dateFormat.format(transaction.timestamp)}
${transaction.description.isNotEmpty ? "รายละเอียด: ${transaction.description}" : ""}
''';

    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('คัดลอกข้อมูลสำหรับแชร์ไปยังคลิปบอร์ดแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleMenuAction(BuildContext context, String action) async {
    switch (action) {
      case 'delete':
        final confirmed = await _showDeleteConfirmation(context);
        if (confirmed == true) {
          await _deleteTransaction(context);
        }
        break;
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบรายการ'),
        content: const Text('คุณต้องการลบรายการธุรกรรมนี้ใช่หรือไม่? การกระทำนี้ไม่สามารถเรียกคืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('ลบรายการ'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(BuildContext context) async {
    try {
      // Delete from Supabase
      await SupabaseService.instance.deleteTransaction(transaction.id);
      
      // Delete from local database
      await DatabaseService.instance.deleteTransaction(transaction.id);
      
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบรายการเรียบร้อยแล้ว'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}