import 'package:flutter/foundation.dart';

/// Remembers the last known location for a product name and
/// also has a built-in smart default based on common keywords.
///
/// Stored in the SQLite DB via DatabaseService so it persists
/// without needing a separate package.
class LocationMemoryService {
  LocationMemoryService._();
  static final LocationMemoryService instance = LocationMemoryService._();

  // In-memory cache: product name (lowercase) → location
  final Map<String, String> _memory = {};

  /// Keywords that suggest a location.
  static const Map<String, List<String>> _locationKeywords = {
    'Fridge': [
      'milk', 'dairy', 'cheese', 'yogurt', 'yoghurt', 'butter', 'cream',
      'egg', 'eggs', 'juice', 'smoothie', 'tofu', 'hummus', 'dip',
      'sauce', 'salsa', 'dressing', 'mayonnaise', 'mayo', 'ketchup',
      'mustard', 'jam', 'jelly', 'syrup', 'bacon', 'sausage', 'ham',
      'turkey', 'chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna',
      'shrimp', 'prawn', 'meat', 'deli', 'lettuce', 'spinach', 'kale',
      'berries', 'strawberry', 'blueberry', 'grape', 'apple', 'orange',
      'lemon', 'lime', 'carrot', 'celery', 'broccoli', 'drink', 'soda',
      'cola', 'beer', 'wine', 'kombucha', 'water',
    ],
    'Freezer': [
      'frozen', 'ice cream', 'gelato', 'sorbet', 'popsicle', 'ice',
      'pizza', 'nuggets', 'fries', 'waffles', 'edamame', 'burritos',
    ],
    'Pantry': [
      'pasta', 'noodle', 'rice', 'flour', 'sugar', 'salt', 'pepper',
      'spice', 'herb', 'oil', 'vinegar', 'bread', 'cereal', 'oat',
      'granola', 'crackers', 'chips', 'popcorn', 'nuts', 'peanut',
      'almond', 'cashew', 'walnut', 'dried', 'canned', 'can ', 'beans',
      'lentils', 'chickpeas', 'soup', 'stock', 'broth', 'tomato',
      'coconut', 'honey', 'chocolate', 'cocoa', 'coffee', 'tea',
      'baking', 'yeast', 'vanilla', 'powder', 'mix', 'sauce',
    ],
    'Cabinet': [
      'vitamin', 'supplement', 'medicine', 'tablet', 'capsule',
      'protein', 'bar', 'snack', 'candy', 'gum', 'mints',
    ],
  };

  /// Load remembered locations from a map (call this on app start
  /// after loading items from DB).
  void seedFromItems(List<MapEntry<String, String>> productLocations) {
    for (final entry in productLocations) {
      _memory[entry.key.toLowerCase()] = entry.value;
    }
  }

  /// Remember that [productName] was stored in [location].
  void remember(String productName, String location) {
    if (productName.isEmpty || location.isEmpty) return;
    _memory[productName.toLowerCase()] = location;
    debugPrint('LocationMemory: ${productName.toLowerCase()} → $location');
  }

  /// Suggest a location for [productName].
  /// Returns the remembered location if known, otherwise uses keyword matching.
  /// Falls back to 'Pantry' if nothing matches.
  String suggest(String productName) {
    if (productName.isEmpty) return 'Pantry';

    final lower = productName.toLowerCase();

    // 1. Check memory first
    if (_memory.containsKey(lower)) return _memory[lower]!;

    // 2. Partial memory match (e.g. "Whole Milk" matches memory for "milk")
    for (final entry in _memory.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }

    // 3. Keyword matching
    for (final entry in _locationKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) return entry.key;
      }
    }

    return 'Pantry';
  }
}
