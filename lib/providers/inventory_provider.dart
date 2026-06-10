import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../models/sort_option.dart';
import '../services/location_memory_service.dart';
import 'sync_provider.dart';

class InventoryProvider extends ChangeNotifier {
  final SyncProvider _sync;

  InventoryProvider(this._sync);

  List<FoodItem> _items = [];
  List<FoodItem> _shoppingList = [];
  bool _isLoading = false;
  String? _error;
  SortOption _sortOption = SortOption.defaultSort;
  StreamSubscription<List<FoodItem>>? _cloudSub;

  List<FoodItem> get items => _sortedItems();
  List<FoodItem> get shoppingList => List.unmodifiable(_shoppingList);
  bool get isLoading => _isLoading;
  String? get error => _error;
  SortOption get sortOption => _sortOption;

  // ── Sorting ────────────────────────────────────────────────────────────────

  void setSortOption(SortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  List<FoodItem> _sortedItems() {
    final list = List<FoodItem>.from(_items);
    list.sort((a, b) {
      int cmp;
      switch (_sortOption.field) {
        case SortField.name:
          cmp = a.product.toLowerCase().compareTo(b.product.toLowerCase());
        case SortField.percentRemaining:
          cmp = a.percentRemaining.compareTo(b.percentRemaining);
        case SortField.expiryDate:
          final aDate = a.sellByDate.isEmpty ? '9999-99-99' : a.sellByDate;
          final bDate = b.sellByDate.isEmpty ? '9999-99-99' : b.sellByDate;
          cmp = aDate.compareTo(bDate);
        case SortField.location:
          cmp = a.location.compareTo(b.location);
      }
      return _sortOption.direction == SortDirection.asc ? cmp : -cmp;
    });
    return List.unmodifiable(list);
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Cancel any existing cloud subscription
      await _cloudSub?.cancel();
      _cloudSub = null;

      final stream = _sync.itemsStream();
      if (stream != null) {
        // Cloud mode — listen to real-time updates
        _cloudSub = stream.listen(
          (items) {
            _items = items;
            _refreshShoppingList();
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = 'Sync error: $e';
            _isLoading = false;
            notifyListeners();
          },
        );
      } else {
        // Local mode
        _items = await _sync.loadLocalItems();
        _refreshShoppingList();
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to load: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<void> addItem(FoodItem item) async {
    try {
      final saved = await _sync.addItem(item);
      if (_sync.isCloudMode) return; // stream will update _items
      _items.add(saved);
      _refreshShoppingList();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add item: $e';
      notifyListeners();
    }
  }

  Future<void> updateItem(FoodItem item) async {
    try {
      await _sync.updateItem(item);
      if (_sync.isCloudMode) return; // stream handles it
      final idx = _items.indexWhere(
          (i) => i.id == item.id || i.firestoreId == item.firestoreId);
      if (idx != -1) _items[idx] = item;
      _refreshShoppingList();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update item: $e';
      notifyListeners();
    }
  }

  Future<void> deleteItem(int? id, {String? firestoreId}) async {
    try {
      final item = _items.firstWhere(
        (i) => (id != null && i.id == id) ||
            (firestoreId != null && i.firestoreId == firestoreId),
      );
      await _sync.deleteItem(item);
      if (_sync.isCloudMode) return;
      _items.removeWhere(
          (i) => i.id == id || i.firestoreId == firestoreId);
      _refreshShoppingList();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete item: $e';
      notifyListeners();
    }
  }

  Future<void> restockItem(FoodItem item) async {
    await updateItem(item.copyWith(percentUsed: 0));
  }

  // ── Lookup ─────────────────────────────────────────────────────────────────

  FoodItem? findByUpc(String upc) {
    if (upc.isEmpty) return null;
    try {
      return _items.firstWhere((i) => i.upc == upc);
    } catch (_) {
      return null;
    }
  }

  FoodItem? findByName(String name) {
    if (name.isEmpty) return null;
    final lower = name.toLowerCase();
    try {
      return _items.firstWhere((i) =>
          i.product.toLowerCase() == lower ||
          i.product.toLowerCase().contains(lower) ||
          lower.contains(i.product.toLowerCase()));
    } catch (_) {
      return null;
    }
  }

  /// Suggest a location for a product name using memory + keywords.
  String suggestLocation(String productName) =>
      LocationMemoryService.instance.suggest(productName);

  // ── Shopping list ──────────────────────────────────────────────────────────

  void _refreshShoppingList() {
    _shoppingList = _items.where((i) => i.isLow).toList();
  }

  void refreshShoppingList() {
    _refreshShoppingList();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cloudSub?.cancel();
    super.dispose();
  }
}
