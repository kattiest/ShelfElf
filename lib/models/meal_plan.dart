/// A single meal assigned to a day slot.
class MealPlan {
  final int id;
  final DateTime date;
  final String mealType; // Breakfast, Lunch, Dinner, Snack
  final String mealName;
  final List<String> ingredients; // ingredient names from AI

  const MealPlan({
    required this.id,
    required this.date,
    required this.mealType,
    required this.mealName,
    required this.ingredients,
  });

  MealPlan copyWith({
    int? id,
    DateTime? date,
    String? mealType,
    String? mealName,
    List<String>? ingredients,
  }) {
    return MealPlan(
      id: id ?? this.id,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      mealName: mealName ?? this.mealName,
      ingredients: ingredients ?? this.ingredients,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'date': date.toIso8601String().substring(0, 10),
        'meal_type': mealType,
        'meal_name': mealName,
        'ingredients': ingredients.join('||'),
      };

  factory MealPlan.fromMap(Map<String, dynamic> map) => MealPlan(
        id: map['id'] as int,
        date: DateTime.parse(map['date'] as String),
        mealType: map['meal_type'] as String,
        mealName: map['meal_name'] as String,
        ingredients: (map['ingredients'] as String)
            .split('||')
            .where((s) => s.isNotEmpty)
            .toList(),
      );
}
