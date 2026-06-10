import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/food_item.dart';
import '../models/meal_plan.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'shelf_elf.db');

    return openDatabase(
      fullPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE food_items (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        upc           TEXT    NOT NULL,
        product       TEXT    NOT NULL,
        package_size  REAL    NOT NULL DEFAULT 0,
        serving_size  REAL    NOT NULL DEFAULT 0,
        sell_by_date  TEXT    NOT NULL DEFAULT '',
        percent_used  INTEGER NOT NULL DEFAULT 0,
        location      TEXT    NOT NULL DEFAULT 'Pantry',
        ordering_level INTEGER NOT NULL DEFAULT 20,
        firestore_id  TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE meal_plans (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        date         TEXT    NOT NULL,
        meal_type    TEXT    NOT NULL DEFAULT 'Dinner',
        meal_name    TEXT    NOT NULL,
        ingredients  TEXT    NOT NULL DEFAULT '',
        firestore_id TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS meal_plans (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          date         TEXT    NOT NULL,
          meal_type    TEXT    NOT NULL DEFAULT 'Dinner',
          meal_name    TEXT    NOT NULL,
          ingredients  TEXT    NOT NULL DEFAULT '',
          firestore_id TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add firestore_id columns to existing tables
      try {
        await db.execute(
            'ALTER TABLE food_items ADD COLUMN firestore_id TEXT');
      } catch (_) {}
      try {
        await db.execute(
            'ALTER TABLE meal_plans ADD COLUMN firestore_id TEXT');
      } catch (_) {}
    }
  }

  // ── FoodItem CRUD ──────────────────────────────────────────────────────────

  Future<int> insertItem(FoodItem item) async {
    final db = await database;
    return db.insert('food_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateItem(FoodItem item) async {
    if (item.id == null) throw ArgumentError('Cannot update FoodItem without id');
    final db = await database;
    return db.update('food_items', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return db.delete('food_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FoodItem>> getAllItems() async {
    final db = await database;
    final rows = await db.query('food_items', orderBy: 'product ASC');
    return rows.map(FoodItem.fromMap).toList();
  }

  Future<List<FoodItem>> getLowItems() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT * FROM food_items
      WHERE (100 - percent_used) <= ordering_level
      ORDER BY product ASC
    ''');
    return rows.map(FoodItem.fromMap).toList();
  }

  // ── MealPlan CRUD ──────────────────────────────────────────────────────────

  Future<int> insertMeal(MealPlan meal) async {
    final db = await database;
    return db.insert('meal_plans', meal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateMeal(MealPlan meal) async {
    final db = await database;
    return db.update('meal_plans', meal.toMap(),
        where: 'id = ?', whereArgs: [meal.id]);
  }

  Future<int> deleteMeal(int id) async {
    final db = await database;
    return db.delete('meal_plans', where: 'id = ?', whereArgs: [id]);
  }

  /// Get all meals for a given week (Mon–Sun containing [weekStart]).
  Future<List<MealPlan>> getMealsForWeek(DateTime weekStart) async {
    final db = await database;
    final start = weekStart.toIso8601String().substring(0, 10);
    final end = weekStart
        .add(const Duration(days: 6))
        .toIso8601String()
        .substring(0, 10);
    final rows = await db.query(
      'meal_plans',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      orderBy: 'date ASC, meal_type ASC',
    );
    return rows.map(MealPlan.fromMap).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
