class FoodItem {
  final int? id;
  final String upc;
  final String product;
  final double packageSize;
  final double servingSize;
  final String sellByDate;
  final int percentUsed; // 0-100, steps of 10
  final String location;
  final int orderingLevel; // percent threshold for reorder

  const FoodItem({
    this.id,
    required this.upc,
    required this.product,
    required this.packageSize,
    required this.servingSize,
    required this.sellByDate,
    required this.percentUsed,
    required this.location,
    required this.orderingLevel,
  });

  /// Percent of item remaining (inverse of percentUsed)
  int get percentRemaining => 100 - percentUsed;

  /// True when remaining stock is at or below the ordering threshold
  bool get isLow => percentRemaining <= orderingLevel;

  /// Calculated servings remaining based on package size, serving size, and percent remaining
  double get servingsRemaining {
    if (servingSize <= 0) return 0;
    final totalServings = packageSize / servingSize;
    return totalServings * (percentRemaining / 100.0);
  }

  FoodItem copyWith({
    int? id,
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

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'upc': upc,
      'product': product,
      'package_size': packageSize,
      'serving_size': servingSize,
      'sell_by_date': sellByDate,
      'percent_used': percentUsed,
      'location': location,
      'ordering_level': orderingLevel,
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'] as int?,
      upc: map['upc'] as String,
      product: map['product'] as String,
      packageSize: (map['package_size'] as num).toDouble(),
      servingSize: (map['serving_size'] as num).toDouble(),
      sellByDate: map['sell_by_date'] as String,
      percentUsed: map['percent_used'] as int,
      location: map['location'] as String,
      orderingLevel: map['ordering_level'] as int,
    );
  }

  @override
  String toString() {
    return 'FoodItem(id: $id, upc: $upc, product: $product, '
        'percentRemaining: $percentRemaining%, location: $location, '
        'isLow: $isLow)';
  }
}
