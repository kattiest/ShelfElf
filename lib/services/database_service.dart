import 'dart:io';
import 'package:flutter/foundation.dart';
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
    final newPath = p.join(dbPath, 'shelf_elf.db');
    final oldPath = p.join(dbPath, 'pantry_pal.db');

    // Migrate old database file name
    final oldFile = File(oldPath);
    final newFile = File(newPath);
    if (oldFile.existsSync() && !newFile.existsSync()) {
      await oldFile.copy(newPath);
      debugPrint('DatabaseService: migrated pantry_pal.db → shelf_elf.db');
    }

    return openDatabase(
      newPath,
      version: 4,
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
        quantity      INTEGER NOT NULL DEFAULT 1,
        quantity_used INTEGER NOT NULL DEFAULT 0,
        sell_by_date  TEXT    NOT NULL DEFAULT '',
        location      TEXT    NOT NULL DEFAULT 'Pantry',
        alert_at      INTEGER NOT NULL DEFAULT 1,
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
      try { await db.execute('ALTER TABLE food_items ADD COLUMN firestore_id TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE meal_plans ADD COLUMN firestore_id TEXT'); } catch (_) {}
    }
    if (oldVersion < 4) {
      // Replace percent-based columns with quantity-based columns
      try { await db.execute('ALTER TABLE food_items ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1'); } catch (_) {}
      try { await db.execute('ALTER TABLE food_items ADD COLUMN quantity_used INTEGER NOT NULL DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE food_items ADD COLUMN alert_at INTEGER NOT NULL DEFAULT 1'); } catch (_) {}
      // If something was 100% used, mark quantity_used = quantity
      try {
        await db.execute('''
          UPDATE food_items
          SET quantity_used = 1
          WHERE percent_used >= 100
        ''');
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
      WHERE (quantity - quantity_used) <= alert_at
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

  Future<List<MealPlan>> getMealsForWeek(DateTime weekStart) async {
    final db = await database;
    final start = weekStart.toIso8601String().substring(0, 10);
    final end = weekStart.add(const Duration(days: 6)).toIso8601String().substring(0, 10);
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
