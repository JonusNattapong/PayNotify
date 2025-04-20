import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pay_notify/models/transaction.dart';

class SupabaseService extends ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  static SupabaseService get instance => _instance;
  
  // Supabase client to access the API
  late final SupabaseClient _client;
  
  // User authentication data
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  // User device token for push notifications
  String? _deviceToken;
  String? get deviceToken => _deviceToken;
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  SupabaseService._internal();
  
  Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    if (_isInitialized) return;
    
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      
      _client = Supabase.instance.client;
      _isInitialized = true;
      
      // Set up authentication listener
      _initializeAuthListener();
      
      print('Supabase initialized successfully');
    } catch (e) {
      print('Error initializing Supabase: $e');
      rethrow;
    }
  }
  
  void _initializeAuthListener() {
    _client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _currentUser = session?.user;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        notifyListeners();
      }
    });
    
    // Check if user is already signed in
    _currentUser = _client.auth.currentUser;
    if (_currentUser != null) {
      notifyListeners();
    }
  }
  
  Future<void> signInAnonymously() async {
    try {
      final response = await _client.auth.signInAnonymously();
      _currentUser = response.user;
      notifyListeners();
    } catch (e) {
      print('Error signing in anonymously: $e');
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
  
  Future<void> registerDeviceToken(String token) async {
    try {
      if (_currentUser == null) {
        await signInAnonymously();
      }
      
      _deviceToken = token;
      
      // Save the token in the database
      await _client
          .from('device_tokens')
          .upsert({
            'user_id': _currentUser!.id,
            'device_token': token,
            'platform': 'android',
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id, device_token');
      
      notifyListeners();
    } catch (e) {
      print('Error registering device token: $e');
      rethrow;
    }
  }
  
  Future<void> saveTransaction(Transaction transaction) async {
    try {
      if (_currentUser == null) {
        await signInAnonymously();
      }
      
      final transactionData = {
        ...transaction.toMap(),
        'user_id': _currentUser!.id,
      };
      
      // Insert the transaction to the database
      await _client
          .from('transactions')
          .insert(transactionData);
      
      print('Transaction saved to Supabase');
    } catch (e) {
      print('Error saving transaction: $e');
      rethrow;
    }
  }
  
  Future<List<Transaction>> getTransactions() async {
    if (_currentUser == null) {
      return [];
    }
    
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', _currentUser!.id)
          .order('timestamp', ascending: false);
      
      final List<Transaction> transactions = [];
      for (final item in response) {
        transactions.add(_mapToTransaction(item));
      }
      
      return transactions;
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }
  
  Stream<List<Transaction>> getTransactionsStream() {
    if (_currentUser == null) {
      return Stream.value([]);
    }
    
    return _client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', _currentUser!.id)
        .order('timestamp')
        .map((items) => items.map((item) => _mapToTransaction(item)).toList());
  }
  
  Transaction _mapToTransaction(Map<String, dynamic> data) {
    return Transaction(
      id: data['id'],
      amount: (data['amount'] as num).toDouble(),
      bankName: data['bank_name'] ?? '',
      accountNumber: data['account_number'] ?? '',
      senderInfo: data['sender_info'] ?? '',
      description: data['description'] ?? '',
      timestamp: DateTime.parse(data['timestamp']),
      isVerified: data['is_verified'] ?? false,
      rawNotificationText: data['raw_notification_text'] ?? '',
    );
  }
  
  Future<void> deleteTransaction(String transactionId) async {
    if (_currentUser == null) return;
    
    try {
      await _client
          .from('transactions')
          .delete()
          .eq('id', transactionId)
          .eq('user_id', _currentUser!.id);
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }
  
  Future<void> configureLineNotify(String lineNotifyToken) async {
    if (_currentUser == null) return;
    
    try {
      await _client
          .from('user_integrations')
          .upsert({
            'user_id': _currentUser!.id,
            'integration_type': 'line_notify',
            'config': { 'token': lineNotifyToken },
            'is_enabled': true,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id, integration_type');
    } catch (e) {
      print('Error configuring LINE Notify: $e');
      rethrow;
    }
  }
}