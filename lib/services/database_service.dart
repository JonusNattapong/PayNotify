import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pay_notify/models/transaction.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseService get instance => _instance;
  
  Database? _database;
  
  // Offline mode management
  bool _isOffline = false;
  final List<Map<String, dynamic>> _offlineQueue = [];
  
  DatabaseService._internal();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'paynotify.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }
  
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions(
        id TEXT PRIMARY KEY,
        amount REAL,
        bank_name TEXT,
        account_number TEXT,
        sender_info TEXT,
        description TEXT,
        timestamp INTEGER,
        is_verified INTEGER,
        raw_notification_text TEXT,
        sync_status INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }
  
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync_status column if upgrading from version 1
      await db.execute('ALTER TABLE transactions ADD COLUMN sync_status INTEGER DEFAULT 0');
    }
  }
  
  // Check network connectivity
  Future<bool> _checkConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }
  
  // Save transaction to local database
  Future<void> saveTransaction(Transaction transaction) async {
    final db = await database;
    
    // Set sync status based on current connectivity
    bool isOnline = await _checkConnectivity();
    int syncStatus = isOnline ? 1 : 0; // 0 = not synced, 1 = synced
    
    Map<String, dynamic> transactionMap = transaction.toMap();
    transactionMap['sync_status'] = syncStatus;
    
    await db.insert(
      'transactions',
      transactionMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Update transaction sync status
  Future<void> updateSyncStatus(String id, int syncStatus) async {
    final db = await database;
    await db.update(
      'transactions',
      {'sync_status': syncStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Get all transactions
  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      orderBy: 'timestamp DESC', // Most recent first
    );
    
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }
  
  // Get unsynchronized transactions that need to be sent to cloud
  Future<List<Transaction>> getUnsyncedTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'sync_status = ?',
      whereArgs: [0],
    );
    
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }
  
  // Get transaction by ID
  Future<Transaction?> getTransactionById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isNotEmpty) {
      return Transaction.fromMap(maps.first);
    }
    return null;
  }
  
  // Get transactions for a specific date range
  Future<List<Transaction>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }
  
  // Get transactions by bank name
  Future<List<Transaction>> getTransactionsByBank(String bankName) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'bank_name = ?',
      whereArgs: [bankName],
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }
  
  // Get transactions grouped by day for statistics
  Future<Map<String, double>> getDailyTransactionTotals(int days) async {
    final db = await database;
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - days);
    
    final Map<String, double> dailyTotals = {};
    
    // Initialize all days with 0
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dailyTotals[dateString] = 0.0;
    }
    
    // Get transactions for the period
    final transactions = await getTransactionsByDateRange(
      startDate, 
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    
    // Sum transactions by day
    for (final transaction in transactions) {
      final date = DateTime.fromMillisecondsSinceEpoch(transaction.timestamp.millisecondsSinceEpoch);
      final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      dailyTotals[dateString] = (dailyTotals[dateString] ?? 0) + transaction.amount;
    }
    
    return dailyTotals;
  }
  
  // Save app settings
  Future<void> saveSetting(String key, dynamic value) async {
    final db = await database;
    
    await db.insert(
      'settings',
      {
        'key': key,
        'value': jsonEncode(value),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Retrieve app settings
  Future<dynamic> getSetting(String key, dynamic defaultValue) async {
    final db = await database;
    
    final List<Map<String, dynamic>> result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return jsonDecode(result.first['value']);
    }
    
    return defaultValue;
  }
  
  // Export all transactions as JSON for backup
  Future<String> exportTransactionsAsJson() async {
    final transactions = await getAllTransactions();
    
    List<Map<String, dynamic>> transactionsMapList = transactions
        .map((transaction) => transaction.toMap())
        .toList();
    
    return jsonEncode(transactionsMapList);
  }
  
  // Import transactions from JSON backup
  Future<int> importTransactionsFromJson(String jsonData) async {
    final db = await database;
    int importCount = 0;
    
    try {
      List<dynamic> transactionsData = jsonDecode(jsonData);
      
      for (var transactionMap in transactionsData) {
        try {
          if (transactionMap is Map<String, dynamic>) {
            await db.insert(
              'transactions',
              transactionMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            importCount++;
          }
        } catch (e) {
          print('Error importing transaction: $e');
        }
      }
    } catch (e) {
      print('Error parsing JSON data: $e');
    }
    
    return importCount;
  }
  
  // Delete a transaction
  Future<void> deleteTransaction(String id) async {
    final db = await database;
    
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Delete transactions older than a certain date
  Future<int> deleteOldTransactions(DateTime cutoffDate) async {
    final db = await database;
    
    return await db.delete(
      'transactions',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }
  
  // Mark all unsynchronized transactions for sync
  Future<int> markAllForSync() async {
    final db = await database;
    
    return await db.update(
      'transactions',
      {'sync_status': 0},
      where: 'sync_status = ?',
      whereArgs: [1],
    );
  }
}