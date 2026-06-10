/// A single meal assigned to a day slot.
class MealPlan {
  final int id;
  final String? firestoreId;
  final DateTime date;
  final String mealType;
  final String mealName;
  final List<String> ingredients;

  const MealPlan({
    required this.id,
    this.firestoreId,
    required this.date,
    required this.mealType,
    required this.mealName,
    required this.ingredients,
  });

  MealPlan copyWith({
    int? id,
    String? firestoreId,
    DateTime? date,
    String? mealType,
    String? mealName,
    List<String>? ingredients,
  }) {
    return MealPlan(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      mealName: mealName ?? this.mealName,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  // ── SQLite ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'date': date.toIso8601String().substring(0, 10),
        'meal_type': mealType,
        'meal_name': mealName,
        'ingredients': ingredients.join('||'),
        if (firestoreId != null) 'firestore_id': firestoreId,
      };

  factory MealPlan.fromMap(Map<String, dynamic> map) => MealPlan(
        id: map['id'] as int,
        firestoreId: map['firestore_id'] as String?,
        date: DateTime.parse(map['date'] as String),
        mealType: map['meal_type'] as String,
        mealName: map['meal_name'] as String,
        ingredients: (map['ingredients'] as String)
            .split('||')
            .where((s) => s.isNotEmpty)
            .toList(),
      );

  // ── Firestore ──────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'date': date.toIso8601String().substring(0, 10),
        'mealType': mealType,
        'mealName': mealName,
        'ingredients': ingredients,
      };

  factory MealPlan.fromFirestore(String docId, Map<String, dynamic> map) =>
      MealPlan(
        id: 0,
        firestoreId: docId,
        date: DateTime.parse(map['date'] as String),
        mealType: map['mealType'] as String? ?? 'Dinner',
        mealName: map['mealName'] as String? ?? '',
        ingredients: List<String>.from(map['ingredients'] as List? ?? []),
      );
}
