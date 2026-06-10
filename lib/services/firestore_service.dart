import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../models/meal_plan.dart';

/// Firestore paths:
///
/// Pantries are shared spaces. A user can belong to one pantry.
///   pantries/{pantryId}/items/{itemId}
///   pantries/{pantryId}/meals/{mealId}
///   pantries/{pantryId}/members/{uid}  — who has access
///
/// User profile stores which pantry they belong to:
///   users/{uid}/pantryId  (field)
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Pantry membership ──────────────────────────────────────────────────────

  /// Create a new pantry owned by [uid]. Returns the new pantry ID.
  Future<String> createPantry(String uid, String ownerName) async {
    final pantryRef = _db.collection('pantries').doc();
    final batch = _db.batch();

    batch.set(pantryRef, {
      'ownerId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'name': "$ownerName's Pantry",
    });

    batch.set(pantryRef.collection('members').doc(uid), {
      'uid': uid,
      'displayName': ownerName,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_db.collection('users').doc(uid), {
      'pantryId': pantryRef.id,
      'displayName': ownerName,
    });

    await batch.commit();
    return pantryRef.id;
  }

  /// Get the pantry ID for a user. Returns null if not in a pantry.
  Future<String?> getPantryId(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['pantryId'] as String?;
  }

  /// Join an existing pantry by invite code (pantry ID).
  Future<void> joinPantry(String uid, String pantryId,
      String displayName) async {
    final batch = _db.batch();

    batch.set(
      _db.collection('pantries').doc(pantryId).collection('members').doc(uid),
      {
        'uid': uid,
        'displayName': displayName,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(_db.collection('users').doc(uid), {
      'pantryId': pantryId,
      'displayName': displayName,
    });

    await batch.commit();
  }

  /// Get list of members in a pantry.
  Future<List<Map<String, dynamic>>> getPantryMembers(
      String pantryId) async {
    final snap = await _db
        .collection('pantries')
        .doc(pantryId)
        .collection('members')
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ── Food items ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _itemsRef(String pantryId) =>
      _db.collection('pantries').doc(pantryId).collection('items');

  /// Real-time stream of all items in a pantry.
  Stream<List<FoodItem>> itemsStream(String pantryId) {
    return _itemsRef(pantryId)
        .orderBy('product')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => FoodItem.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  Future<String> addItem(String pantryId, FoodItem item) async {
    final ref = await _itemsRef(pantryId).add(item.toFirestore());
    return ref.id;
  }

  Future<void> updateItem(String pantryId, FoodItem item) async {
    if (item.firestoreId == null) return;
    await _itemsRef(pantryId).doc(item.firestoreId).update(item.toFirestore());
  }

  Future<void> deleteItem(String pantryId, String firestoreId) async {
    await _itemsRef(pantryId).doc(firestoreId).delete();
  }

  // ── Meal plans ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _mealsRef(String pantryId) =>
      _db.collection('pantries').doc(pantryId).collection('meals');

  Stream<List<MealPlan>> mealsStream(String pantryId, DateTime weekStart) {
    final start = weekStart.toIso8601String().substring(0, 10);
    final end = weekStart
        .add(const Duration(days: 6))
        .toIso8601String()
        .substring(0, 10);

    return _mealsRef(pantryId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => MealPlan.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  Future<String> addMeal(String pantryId, MealPlan meal) async {
    final ref = await _mealsRef(pantryId).add(meal.toFirestore());
    return ref.id;
  }

  Future<void> deleteMeal(String pantryId, String firestoreId) async {
    await _mealsRef(pantryId).doc(firestoreId).delete();
  }
}
