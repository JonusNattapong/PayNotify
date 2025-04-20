import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pay_notify/models/transaction.dart';
import 'package:pay_notify/services/supabase_service.dart';
import 'package:pay_notify/services/database_service.dart';
import 'package:pay_notify/services/notification_listener_service.dart';
import 'package:pay_notify/widgets/transaction_card.dart';
import 'package:pay_notify/screens/settings_screen.dart';
import 'package:pay_notify/screens/transaction_detail_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLocalMode = false;
  List<Transaction>? _localTransactions;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'th_TH',
    symbol: '฿',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadLocalTransactions();
  }

  Future<void> _loadLocalTransactions() async {
    try {
      final transactions = await DatabaseService.instance.getAllTransactions();
      if (mounted) {
        setState(() {
          _localTransactions = transactions;
        });
      }
    } catch (e) {
      print('Error loading local transactions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationListenerService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayNotify'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildModeToggle(),
          Expanded(
            child: _isLocalMode
                ? _buildLocalTransactionList()
                : _buildCloudTransactionList(),
          ),
        ],
      ),
      floatingActionButton: !notificationService.isServiceRunning
          ? FloatingActionButton.extended(
              onPressed: () {
                notificationService.openNotificationSettings();
              },
              label: const Text('เปิดการแจ้งเตือน'),
              icon: const Icon(Icons.notifications_active),
              backgroundColor: Theme.of(context).colorScheme.error,
            )
          : null,
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'สรุปรายการวันนี้',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _isLocalMode
                ? _buildLocalSummary()
                : _buildCloudSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalSummary() {
    if (_localTransactions == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Filter transactions for today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTransactions = _localTransactions!.where((transaction) {
      final transactionDate = DateTime(
        transaction.timestamp.year,
        transaction.timestamp.month,
        transaction.timestamp.day,
      );
      return transactionDate.isAtSameMomentAs(today);
    }).toList();

    final totalAmount = todayTransactions.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('จำนวนรายการ'),
            Text(
              '${todayTransactions.length} รายการ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ยอดรวม'),
            Text(
              _currencyFormat.format(totalAmount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCloudSummary() {
    return StreamBuilder<List<Transaction>>(
      stream: SupabaseService.instance.getTransactionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
          );
        }

        final transactions = snapshot.data ?? [];

        // Filter transactions for today
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todayTransactions = transactions.where((transaction) {
          final transactionDate = DateTime(
            transaction.timestamp.year,
            transaction.timestamp.month,
            transaction.timestamp.day,
          );
          return transactionDate.isAtSameMomentAs(today);
        }).toList();

        final totalAmount = todayTransactions.fold<double>(
          0,
          (sum, transaction) => sum + transaction.amount,
        );

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('จำนวนรายการ'),
                Text(
                  '${todayTransactions.length} รายการ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ยอดรวม'),
                Text(
                  _currencyFormat.format(totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('โหมดการแสดงผล:'),
          const Spacer(),
          ToggleButtons(
            isSelected: [!_isLocalMode, _isLocalMode],
            onPressed: (index) {
              setState(() {
                _isLocalMode = index == 1;
                if (_isLocalMode) {
                  _loadLocalTransactions();
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Cloud'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Local'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocalTransactionList() {
    if (_localTransactions == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_localTransactions!.isEmpty) {
      return const Center(
        child: Text('ไม่พบรายการธุรกรรม'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLocalTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _localTransactions!.length,
        itemBuilder: (context, index) {
          final transaction = _localTransactions![index];
          return TransactionCard(
            transaction: transaction,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionDetailScreen(
                    transaction: transaction,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCloudTransactionList() {
    return StreamBuilder<List<Transaction>>(
      stream: SupabaseService.instance.getTransactionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
          );
        }

        final transactions = snapshot.data ?? [];

        if (transactions.isEmpty) {
          return const Center(
            child: Text('ไม่พบรายการธุรกรรม'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return TransactionCard(
              transaction: transaction,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransactionDetailScreen(
                      transaction: transaction,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}