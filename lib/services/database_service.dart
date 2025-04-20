import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pay_notify/models/transaction.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static DatabaseService get instance => _instance;
  
  Database? _database;
  
  DatabaseService._internal();
  
  Future<void> init() async {
    if (_database != null) return;
    
    final String path = join(await getDatabasesPath(), 'pay_notify.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions(
            id TEXT PRIMARY KEY,
            amount REAL NOT NULL,
            bankName TEXT NOT NULL,
            accountNumber TEXT NOT NULL,
            senderInfo TEXT NOT NULL,
            description TEXT,
            timestamp INTEGER NOT NULL,
            isVerified INTEGER NOT NULL,
            rawNotificationText TEXT NOT NULL
          )
        ''');
      },
    );
  }
  
  Future<void> saveTransaction(Transaction transaction) async {
    if (_database == null) await init();
    
    await _database!.insert(
      'transactions',
      {
        'id': transaction.id,
        'amount': transaction.amount,
        'bankName': transaction.bankName,
        'accountNumber': transaction.accountNumber,
        'senderInfo': transaction.senderInfo,
        'description': transaction.description,
        'timestamp': transaction.timestamp.millisecondsSinceEpoch,
        'isVerified': transaction.isVerified ? 1 : 0,
        'rawNotificationText': transaction.rawNotificationText,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Transaction>> getAllTransactions() async {
    if (_database == null) await init();
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'transactions',
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) {
      return Transaction(
        id: maps[i]['id'],
        amount: maps[i]['amount'],
        bankName: maps[i]['bankName'],
        accountNumber: maps[i]['accountNumber'],
        senderInfo: maps[i]['senderInfo'],
        description: maps[i]['description'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp']),
        isVerified: maps[i]['isVerified'] == 1,
        rawNotificationText: maps[i]['rawNotificationText'],
      );
    });
  }
  
  Future<List<Transaction>> getTransactionsByDate(DateTime date) async {
    if (_database == null) await init();
    
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'transactions',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [
        startOfDay.millisecondsSinceEpoch,
        endOfDay.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );
    
    return List.generate(maps.length, (i) {
      return Transaction(
        id: maps[i]['id'],
        amount: maps[i]['amount'],
        bankName: maps[i]['bankName'],
        accountNumber: maps[i]['accountNumber'],
        senderInfo: maps[i]['senderInfo'],
        description: maps[i]['description'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(maps[i]['timestamp']),
        isVerified: maps[i]['isVerified'] == 1,
        rawNotificationText: maps[i]['rawNotificationText'],
      );
    });
  }
  
  Future<void> updateTransaction(Transaction transaction) async {
    if (_database == null) await init();
    
    await _database!.update(
      'transactions',
      {
        'amount': transaction.amount,
        'bankName': transaction.bankName,
        'accountNumber': transaction.accountNumber,
        'senderInfo': transaction.senderInfo,
        'description': transaction.description,
        'timestamp': transaction.timestamp.millisecondsSinceEpoch,
        'isVerified': transaction.isVerified ? 1 : 0,
        'rawNotificationText': transaction.rawNotificationText,
      },
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }
  
  Future<void> deleteTransaction(String id) async {
    if (_database == null) await init();
    
    await _database!.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}