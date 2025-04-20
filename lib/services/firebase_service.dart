import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:pay_notify/models/transaction.dart';

class FirebaseService extends ChangeNotifier {
  static final FirebaseService _instance = FirebaseService._internal();
  static FirebaseService get instance => _instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  User? _currentUser;
  User? get currentUser => _currentUser;
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  FirebaseService._internal() {
    _initializeFirebaseAuth();
    _initializeFirebaseMessaging();
  }
  
  void _initializeFirebaseAuth() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }
  
  Future<void> _initializeFirebaseMessaging() async {
    // Request permission for notifications
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User declined permission');
    }
    
    // Get FCM token
    _fcmToken = await _messaging.getToken();
    print('FCM Token: $_fcmToken');
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _saveTokenToFirestore();
    });
  }
  
  Future<void> _saveTokenToFirestore() async {
    if (_currentUser != null && _fcmToken != null) {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('tokens')
          .doc('fcm')
          .set({
        'token': _fcmToken,
        'platform': 'android',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
  
  Future<void> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      _currentUser = userCredential.user;
      notifyListeners();
      
      if (_fcmToken != null) {
        await _saveTokenToFirestore();
      }
    } catch (e) {
      print('Error signing in anonymously: $e');
      rethrow;
    }
  }
  
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
  
  Future<void> uploadTransaction(Transaction transaction) async {
    try {
      if (_currentUser == null) {
        await signInAnonymously();
      }
      
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .doc(transaction.id)
          .set(transaction.toMap());
      
      // Also add to a global transactions collection for admin monitoring
      await _firestore
          .collection('all_transactions')
          .doc(transaction.id)
          .set({
        ...transaction.toMap(),
        'userId': _currentUser!.uid,
      });
    } catch (e) {
      print('Error uploading transaction: $e');
      rethrow;
    }
  }
  
  Stream<List<Transaction>> getTransactionsStream() {
    if (_currentUser == null) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Transaction.fromDocument(doc)).toList();
    });
  }
  
  Future<void> deleteTransaction(String transactionId) async {
    if (_currentUser == null) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .doc(transactionId)
          .delete();
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
    }
  }
  
  Future<void> configureLineNotify(String lineNotifyToken) async {
    if (_currentUser == null) return;
    
    await _firestore
        .collection('users')
        .doc(_currentUser!.uid)
        .set({
      'integrations': {
        'lineNotify': {
          'token': lineNotifyToken,
          'enabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }
    }, SetOptions(merge: true));
  }
}