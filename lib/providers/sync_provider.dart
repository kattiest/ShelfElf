import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/location_memory_service.dart';

/// Callback used to tell InventoryProvider to reload when sync state changes.
typedef OnSyncReady = Future<void> Function();

class SyncProvider extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;
  final FirestoreService _firestore = FirestoreService.instance;
  final DatabaseService _db = DatabaseService.instance;

  String? _pantryId;
  bool _isCloudMode = false;
  bool _isInitializing = false;
  StreamSubscription<User?>? _authSub;

  /// Set this so SyncProvider can trigger InventoryProvider to reload
  /// when the pantry/sync state changes (login, join, create).
  OnSyncReady? onSyncReady;

  String? get pantryId => _pantryId;
  bool get isCloudMode => _isCloudMode;
  bool get isInitializing => _isInitializing;
  String? get uid => _auth.uid;
  bool get isSignedIn => _auth.isSignedIn;

  SyncProvider() {
    // Auto-respond to Firebase auth state changes
    _authSub =
        FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user == null) {
      await _disableCloud();
    } else {
      await _doInitSync();
    }
    onSyncReady?.call();
  }

  Future<void> _doInitSync() async {
    if (!_auth.isSignedIn) {
      await _disableCloud();
      return;
    }

    _isInitializing = true;
    notifyListeners();

    try {
      final pid = await _firestore.getPantryId(_auth.uid!);
      if (pid == null) {
        await _disableCloud();
      } else {
        _pantryId = pid;
        _isCloudMode = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('SyncProvider._doInitSync error: $e');
      await _disableCloud();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// Manually trigger sync init — call after login/register.
  Future<void> initSync() => _doInitSync();

  Future<void> createPantry(String displayName) async {
    if (!_auth.isSignedIn) return;

    _isInitializing = true;
    notifyListeners();

    try {
      final pid =
          await _firestore.createPantry(_auth.uid!, displayName);
      _pantryId = pid;
      _isCloudMode = true;
      notifyListeners();
      onSyncReady?.call();
    } catch (e) {
      rethrow;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> joinPantry(String pantryId, String displayName) async {
    if (!_auth.isSignedIn) return;

    _isInitializing = true;
    notifyListeners();

    try {
      // Verify pantry exists first
      final pantryDoc = await FirebaseFirestore.instance
          .collection('pantries')
          .doc(pantryId.trim())
          .get();
      if (!pantryDoc.exists) {
        throw Exception('Pantry not found. Double-check the invite code.');
      }

      await _firestore.joinPantry(_auth.uid!, pantryId.trim(), displayName);
      _pantryId = pantryId.trim();
      _isCloudMode = true;
      notifyListeners();
      onSyncReady?.call();
    } catch (e) {
      rethrow;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getMembers() async {
    if (_pantryId == null) return [];
    return _firestore.getPantryMembers(_pantryId!);
  }

  Future<void> _disableCloud() async {
    _pantryId = null;
    _isCloudMode = false;
    notifyListeners();
  }

  Stream<List<FoodItem>>? itemsStream() {
    if (!_isCloudMode || _pantryId == null) return null;
    return _firestore.itemsStream(_pantryId!);
  }

  // ── Write operations ───────────────────────────────────────────────────────

  Future<FoodItem> addItem(FoodItem item) async {
    LocationMemoryService.instance.remember(item.product, item.location);
    if (_isCloudMode && _pantryId != null) {
      final fsId = await _firestore.addItem(_pantryId!, item);
      return item.copyWith(firestoreId: fsId);
    } else {
      final id = await _db.insertItem(item);
      return item.copyWith(id: id);
    }
  }

  Future<void> updateItem(FoodItem item) async {
    LocationMemoryService.instance.remember(item.product, item.location);
    if (_isCloudMode && _pantryId != null && item.firestoreId != null) {
      await _firestore.updateItem(_pantryId!, item);
    } else {
      await _db.updateItem(item);
    }
  }

  Future<void> deleteItem(FoodItem item) async {
    if (_isCloudMode && _pantryId != null && item.firestoreId != null) {
      await _firestore.deleteItem(_pantryId!, item.firestoreId!);
    } else if (item.id != null) {
      await _db.deleteItem(item.id!);
    }
  }

  Future<List<FoodItem>> loadLocalItems() async {
    final items = await _db.getAllItems();
    LocationMemoryService.instance.seedFromItems(
      items.map((i) => MapEntry(i.product, i.location)).toList(),
    );
    return items;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
