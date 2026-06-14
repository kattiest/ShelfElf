class FoodItem {
  final int? id;
  final String? firestoreId;
  final String upc;
  final String product;
  final int quantity;       // total units you have (e.g. 4 cans)
  final int quantityUsed;  // how many have been used/consumed
  final String sellByDate;
  final String location;
  final int alertAt;       // add to shopping list when remaining <= this

  const FoodItem({
    this.id,
    this.firestoreId,
    required this.upc,
    required this.product,
    required this.quantity,
    required this.quantityUsed,
    required this.sellByDate,
    required this.location,
    required this.alertAt,
  });

  /// How many units are left
  int get quantityRemaining => (quantity - quantityUsed).clamp(0, quantity);

  /// True when you're running low
  bool get isLow => quantityRemaining <= alertAt;

  /// Percentage remaining — used for colour coding
  int get percentRemaining =>
      quantity <= 0 ? 0 : ((quantityRemaining / quantity) * 100).round();

  /// Legacy compat — some widgets still reference this
  int get percentUsed => 100 - percentRemaining;

  FoodItem copyWith({
    int? id,
    String? firestoreId,
    String? upc,
    String? product,
    int? quantity,
    int? quantityUsed,
    String? sellByDate,
    String? location,
    int? alertAt,
  }) =>
      FoodItem(
        id: id ?? this.id,
        firestoreId: firestoreId ?? this.firestoreId,
        upc: upc ?? this.upc,
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
        quantityUsed: quantityUsed ?? this.quantityUsed,
        sellByDate: sellByDate ?? this.sellByDate,
        location: location ?? this.location,
        alertAt: alertAt ?? this.alertAt,
      );

  // ── SQLite ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'upc': upc,
        'product': product,
        'quantity': quantity,
        'quantity_used': quantityUsed,
        'sell_by_date': sellByDate,
        'location': location,
        'alert_at': alertAt,
        if (firestoreId != null) 'firestore_id': firestoreId,
      };

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    // Handle old schema (percent_used / ordering_level) for migration
    final hasNewSchema = map.containsKey('quantity');

    if (hasNewSchema) {
      return FoodItem(
        id: map['id'] as int?,
        firestoreId: map['firestore_id'] as String?,
        upc: map['upc'] as String? ?? '',
        product: map['product'] as String? ?? '',
        quantity: map['quantity'] as int? ?? 1,
        quantityUsed: map['quantity_used'] as int? ?? 0,
        sellByDate: map['sell_by_date'] as String? ?? '',
        location: map['location'] as String? ?? 'Pantry',
        alertAt: map['alert_at'] as int? ?? 1,
      );
    } else {
      // Migrate from old percent-based schema
      final percentUsed = map['percent_used'] as int? ?? 0;
      final orderingLevel = map['ordering_level'] as int? ?? 20;
      // Treat old data as qty=1 with used based on percent
      final wasUsed = percentUsed >= 100 ? 1 : 0;
      final alertAt = orderingLevel >= 80 ? 1 : 0;
      return FoodItem(
        id: map['id'] as int?,
        firestoreId: map['firestore_id'] as String?,
        upc: map['upc'] as String? ?? '',
        product: map['product'] as String? ?? '',
        quantity: 1,
        quantityUsed: wasUsed,
        sellByDate: map['sell_by_date'] as String? ?? '',
        location: map['location'] as String? ?? 'Pantry',
        alertAt: alertAt,
      );
    }
  }

  // ── Firestore ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'upc': upc,
        'product': product,
        'quantity': quantity,
        'quantityUsed': quantityUsed,
        'sellByDate': sellByDate,
        'location': location,
        'alertAt': alertAt,
      };

  factory FoodItem.fromFirestore(String docId, Map<String, dynamic> map) {
    // Handle both old and new Firestore schema
    if (map.containsKey('quantity')) {
      return FoodItem(
        firestoreId: docId,
        upc: map['upc'] as String? ?? '',
        product: map['product'] as String? ?? '',
        quantity: map['quantity'] as int? ?? 1,
        quantityUsed: map['quantityUsed'] as int? ?? 0,
        sellByDate: map['sellByDate'] as String? ?? '',
        location: map['location'] as String? ?? 'Pantry',
        alertAt: map['alertAt'] as int? ?? 1,
      );
    } else {
      // Old Firestore schema
      final percentUsed = map['percentUsed'] as int? ?? 0;
      return FoodItem(
        firestoreId: docId,
        upc: map['upc'] as String? ?? '',
        product: map['product'] as String? ?? '',
        quantity: 1,
        quantityUsed: percentUsed >= 100 ? 1 : 0,
        sellByDate: map['sellByDate'] as String? ?? '',
        location: map['location'] as String? ?? 'Pantry',
        alertAt: 1,
      );
    }
  }

  @override
  String toString() =>
      'FoodItem($product, $quantityRemaining/$quantity left, $location)';
}
