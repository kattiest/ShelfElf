import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/location_memory_service.dart';

/// Manages whether the app is in local-only or cloud-sync mode.
/// When signed in, all writes go to Firestore and stream back via listener.
/// When offline/local, writes go to SQLite only.
class SyncProvider extends ChangeNotifier {
  final AuthService _auth = AuthService.instance;
  final FirestoreService _firestore = FirestoreService.instance;
  final DatabaseService _db = DatabaseService.instance;

  String? _pantryId;
  bool _isCloudMode = false;
  StreamSubscription<List<FoodItem>>? _itemsSub;

  String? get pantryId => _pantryId;
  bool get isCloudMode => _isCloudMode;
  String? get uid => _auth.uid;
  bool get isSignedIn => _auth.isSignedIn;

  /// Call after auth state changes to set up cloud sync.
  Future<void> initSync() async {
    if (!_auth.isSignedIn) {
      await _disableCloud();
      return;
    }

    final pid = await _firestore.getPantryId(_auth.uid!);
    if (pid == null) {
      // Signed in but no pantry yet — still local
      await _disableCloud();
      return;
    }

    _pantryId = pid;
    _isCloudMode = true;
    notifyListeners();
  }

  /// Create a new pantry and enable cloud sync.
  Future<void> createPantry(String displayName) async {
    if (!_auth.isSignedIn) return;
    _pantryId = await _firestore.createPantry(_auth.uid!, displayName);
    _isCloudMode = true;
    notifyListeners();
  }

  /// Join an existing pantry by ID and enable cloud sync.
  Future<void> joinPantry(String pantryId, String displayName) async {
    if (!_auth.isSignedIn) return;
    await _firestore.joinPantry(_auth.uid!, pantryId, displayName);
    _pantryId = pantryId;
    _isCloudMode = true;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getMembers() async {
    if (_pantryId == null) return [];
    return _firestore.getPantryMembers(_pantryId!);
  }

  Future<void> _disableCloud() async {
    _pantryId = null;
    _isCloudMode = false;
    _itemsSub?.cancel();
    _itemsSub = null;
    notifyListeners();
  }

  /// Get a real-time stream of items — Firestore if cloud, null if local.
  Stream<List<FoodItem>>? itemsStream() {
    if (!_isCloudMode || _pantryId == null) return null;
    return _firestore.itemsStream(_pantryId!);
  }

  // ── Write operations — route to Firestore or SQLite ───────────────────────

  Future<FoodItem> addItem(FoodItem item) async {
    // Remember location for this product
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
    // Seed location memory from existing items
    LocationMemoryService.instance.seedFromItems(
      items.map((i) => MapEntry(i.product, i.location)).toList(),
    );
    return items;
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    super.dispose();
  }
}
