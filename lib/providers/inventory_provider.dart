import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../services/database_service.dart';

class InventoryProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<FoodItem> _items = [];
  List<FoodItem> _shoppingList = [];
  bool _isLoading = false;
  String? _error;

  List<FoodItem> get items => List.unmodifiable(_items);
  List<FoodItem> get shoppingList => List.unmodifiable(_shoppingList);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all items from the database and refresh the shopping list.
  Future<void> loadItems() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _db.getAllItems();
      _refreshShoppingListFromItems();
    } catch (e) {
      _error = 'Failed to load items: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new [FoodItem] to the database and refresh state.
  Future<void> addItem(FoodItem item) async {
    try {
      final id = await _db.insertItem(item);
      final saved = item.copyWith(id: id);
      _items.add(saved);
      _items.sort((a, b) => a.product.compareTo(b.product));
      _refreshShoppingListFromItems();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add item: $e';
      notifyListeners();
    }
  }

  /// Update an existing [FoodItem] in the database and refresh state.
  Future<void> updateItem(FoodItem item) async {
    try {
      await _db.updateItem(item);
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _items[idx] = item;
        _items.sort((a, b) => a.product.compareTo(b.product));
      }
      _refreshShoppingListFromItems();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update item: $e';
      notifyListeners();
    }
  }

  /// Delete a [FoodItem] by id and refresh state.
  Future<void> deleteItem(int id) async {
    try {
      await _db.deleteItem(id);
      _items.removeWhere((i) => i.id == id);
      _refreshShoppingListFromItems();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete item: $e';
      notifyListeners();
    }
  }

  /// Re-derive the shopping list from the current in-memory items.
  void refreshShoppingList() {
    _refreshShoppingListFromItems();
    notifyListeners();
  }

  void _refreshShoppingListFromItems() {
    _shoppingList = _items.where((item) => item.isLow).toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
