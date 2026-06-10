class FoodItem {
  final int? id;              // SQLite local id
  final String? firestoreId;  // Firestore document id (null when local-only)
  final String upc;
  final String product;
  final double packageSize;
  final double servingSize;
  final String sellByDate;
  final int percentUsed;
  final String location;
  final int orderingLevel;

  const FoodItem({
    this.id,
    this.firestoreId,
    required this.upc,
    required this.product,
    required this.packageSize,
    required this.servingSize,
    required this.sellByDate,
    required this.percentUsed,
    required this.location,
    required this.orderingLevel,
  });

  int get percentRemaining => 100 - percentUsed;
  bool get isLow => percentRemaining <= orderingLevel;

  double get servingsRemaining {
    if (servingSize <= 0) return 0;
    return (packageSize / servingSize) * (percentRemaining / 100.0);
  }

  FoodItem copyWith({
    int? id,
    String? firestoreId,
    String? upc,
    String? product,
    double? packageSize,
    double? servingSize,
    String? sellByDate,
    int? percentUsed,
    String? location,
    int? orderingLevel,
  }) {
    return FoodItem(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      upc: upc ?? this.upc,
      product: product ?? this.product,
      packageSize: packageSize ?? this.packageSize,
      servingSize: servingSize ?? this.servingSize,
      sellByDate: sellByDate ?? this.sellByDate,
      percentUsed: percentUsed ?? this.percentUsed,
      location: location ?? this.location,
      orderingLevel: orderingLevel ?? this.orderingLevel,
    );
  }

  // ── SQLite ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'upc': upc,
        'product': product,
        'package_size': packageSize,
        'serving_size': servingSize,
        'sell_by_date': sellByDate,
        'percent_used': percentUsed,
        'location': location,
        'ordering_level': orderingLevel,
        if (firestoreId != null) 'firestore_id': firestoreId,
      };

  factory FoodItem.fromMap(Map<String, dynamic> map) => FoodItem(
        id: map['id'] as int?,
        firestoreId: map['firestore_id'] as String?,
        upc: map['upc'] as String,
        product: map['product'] as String,
        packageSize: (map['package_size'] as num).toDouble(),
        servingSize: (map['serving_size'] as num).toDouble(),
        sellByDate: map['sell_by_date'] as String,
        percentUsed: map['percent_used'] as int,
        location: map['location'] as String,
        orderingLevel: map['ordering_level'] as int,
      );

  // ── Firestore ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'upc': upc,
        'product': product,
        'packageSize': packageSize,
        'servingSize': servingSize,
        'sellByDate': sellByDate,
        'percentUsed': percentUsed,
        'location': location,
        'orderingLevel': orderingLevel,
      };

  factory FoodItem.fromFirestore(String docId, Map<String, dynamic> map) =>
      FoodItem(
        firestoreId: docId,
        upc: map['upc'] as String? ?? '',
        product: map['product'] as String? ?? '',
        packageSize: (map['packageSize'] as num?)?.toDouble() ?? 0,
        servingSize: (map['servingSize'] as num?)?.toDouble() ?? 0,
        sellByDate: map['sellByDate'] as String? ?? '',
        percentUsed: map['percentUsed'] as int? ?? 0,
        location: map['location'] as String? ?? 'Pantry',
        orderingLevel: map['orderingLevel'] as int? ?? 20,
      );

  @override
  String toString() =>
      'FoodItem($product, ${percentRemaining}% left, $location)';
}
