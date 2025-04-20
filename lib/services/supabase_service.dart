import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pay_notify/models/transaction.dart';
import 'package:pay_notify/services/database_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class SupabaseService extends ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  static SupabaseService get instance => _instance;
  
  static const String _tableName = 'transactions';
  
  bool _isInitialized = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;
  
  // Auto-sync settings
  bool _autoSync = true;
  bool _syncOnWifiOnly = true;
  
  SupabaseClient get _client => Supabase.instance.client;
  
  SupabaseService._internal();
  
  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseKey,
  }) async {
    if (_isInitialized) return;
    
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );
      
      _isInitialized = true;
      
      // Initialize sync settings
      await _loadSyncSettings();
      
      // Set up connectivity listener for auto-sync
      if (_autoSync) {
        _setupConnectivityListener();
      }
      
      print('Supabase initialized successfully');
    } catch (e) {
      print('Failed to initialize Supabase: $e');
    }
  }
  
  Future<void> _loadSyncSettings() async {
    _autoSync = await DatabaseService.instance.getSetting('auto_sync', true);
    _syncOnWifiOnly = await DatabaseService.instance.getSetting('sync_on_wifi_only', true);
  }
  
  Future<void> saveSyncSettings({bool? autoSync, bool? syncOnWifiOnly}) async {
    if (autoSync != null) {
      _autoSync = autoSync;
      await DatabaseService.instance.saveSetting('auto_sync', autoSync);
      
      if (autoSync) {
        _setupConnectivityListener();
      } else {
        await _connectivitySubscription?.cancel();
        _connectivitySubscription = null;
      }
    }
    
    if (syncOnWifiOnly != null) {
      _syncOnWifiOnly = syncOnWifiOnly;
      await DatabaseService.instance.saveSetting('sync_on_wifi_only', syncOnWifiOnly);
    }
  }
  
  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (!_autoSync) return;
      
      if (result == ConnectivityResult.wifi || 
          (!_syncOnWifiOnly && result != ConnectivityResult.none)) {
        // Auto-sync when connectivity is available based on settings
        syncTransactions();
      }
    });
  }
  
  Future<bool> isOnlineAndConnected() async {
    if (!_isInitialized) return false;
    
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      if (_syncOnWifiOnly && connectivityResult != ConnectivityResult.wifi) {
        return false;
      }
      
      // Perform a simple API call to verify connection
      await _client.from('_dummy').select('*').limit(1).maybeSingle();
      return true;
    } catch (e) {
      print('Connection check failed: $e');
      return false;
    }
  }
  
  Future<void> saveTransaction(Transaction transaction) async {
    if (!_isInitialized) {
      throw Exception('Supabase not initialized');
    }
    
    final isConnected = await isOnlineAndConnected();
    if (!isConnected) {
      throw Exception('No connectivity available');
    }
    
    try {
      await _client.from(_tableName).upsert({
        'id': transaction.id,
        'amount': transaction.amount,
        'bank_name': transaction.bankName,
        'account_number': transaction.accountNumber,
        'sender_info': transaction.senderInfo,
        'description': transaction.description,
        'timestamp': transaction.timestamp.millisecondsSinceEpoch,
        'is_verified': transaction.isVerified ? 1 : 0,
        'raw_notification_text': transaction.rawNotificationText,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Update sync status in local database
      await DatabaseService.instance.updateSyncStatus(transaction.id, 1);
      
      print('Transaction saved to Supabase: ${transaction.id}');
    } catch (e) {
      print('Failed to save transaction to Supabase: $e');
      throw e;
    }
  }
  
  Future<List<Transaction>> fetchTransactions({int limit = 100}) async {
    if (!_isInitialized) {
      throw Exception('Supabase not initialized');
    }
    
    try {
      final response = await _client
        .from(_tableName)
        .select()
        .order('timestamp', ascending: false)
        .limit(limit);
      
      return (response as List).map((data) {
        return Transaction(
          id: data['id'],
          amount: data['amount'],
          bankName: data['bank_name'],
          accountNumber: data['account_number'],
          senderInfo: data['sender_info'],
          description: data['description'],
          timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp']),
          isVerified: data['is_verified'] == 1,
          rawNotificationText: data['raw_notification_text'],
        );
      }).toList();
    } catch (e) {
      print('Failed to fetch transactions from Supabase: $e');
      throw e;
    }
  }
  
  // Sync local transactions with Supabase
  Future<void> syncTransactions() async {
    if (!_isInitialized || _isSyncing) return;
    
    final isConnected = await isOnlineAndConnected();
    if (!isConnected) return;
    
    _isSyncing = true;
    
    try {
      // Get unsynchronized transactions
      final unsyncedTransactions = await DatabaseService.instance.getUnsyncedTransactions();
      
      if (unsyncedTransactions.isEmpty) {
        _isSyncing = false;
        return;
      }
      
      print('Syncing ${unsyncedTransactions.length} transactions...');
      
      // Upload each unsynchronized transaction
      for (final transaction in unsyncedTransactions) {
        try {
          await saveTransaction(transaction);
        } catch (e) {
          print('Failed to sync transaction ${transaction.id}: $e');
        }
      }
      
      print('Sync completed');
    } catch (e) {
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  // Delete a transaction from cloud
  Future<void> deleteTransaction(String id) async {
    if (!_isInitialized) {
      throw Exception('Supabase not initialized');
    }
    
    try {
      await _client.from(_tableName).delete().eq('id', id);
      print('Transaction deleted from Supabase: $id');
    } catch (e) {
      print('Failed to delete transaction from Supabase: $e');
      throw e;
    }
  }
  
  // Fetch transaction statistics from cloud
  Future<Map<String, dynamic>> fetchTransactionStats() async {
    if (!_isInitialized) {
      throw Exception('Supabase not initialized');
    }
    
    try {
      // Using Postgres functions - this requires a SQL function to be created in Supabase
      final response = await _client.rpc('get_transaction_stats');
      return response as Map<String, dynamic>;
    } catch (e) {
      print('Failed to fetch transaction stats: $e');
      throw e;
    }
  }
  
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}