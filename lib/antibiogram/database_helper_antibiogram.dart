import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelperAntibiogram {
  static final DatabaseHelperAntibiogram _instance =
      DatabaseHelperAntibiogram._internal();
  static Database? _database;

  DatabaseHelperAntibiogram._internal();

  factory DatabaseHelperAntibiogram() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'antibiogram_data.db');
    debugPrint('Database Path: $path');
    return await openDatabase(path, version: 2, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create the categories table
    await db.execute('''
      CREATE TABLE categories (
        category_id TEXT PRIMARY KEY,
        category_name TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE antibiograms (
        antibiogram_id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        category_name TEXT NOT NULL,
        site_id TEXT NOT NULL,
        sub_category TEXT NOT NULL,
        x_axis_id TEXT NOT NULL,
        x_axis_name TEXT NOT NULL,
        y_axis_id TEXT NOT NULL,
        y_axis_name TEXT NOT NULL,
        new_value TEXT,
        old_value TEXT
      );
    ''');
    await db.execute('''
    CREATE TABLE antibiogram_views (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category_id TEXT NOT NULL,
      sub_category TEXT NOT NULL,
      type TEXT NOT NULL,
      view INTEGER NOT NULL, -- Boolean: 1 (true), 0 (false)
      chat INTEGER NOT NULL, -- Boolean: 1 (true), 0 (false)
      date INTEGER NOT NULL -- Timestamp
    );
  ''');
  }

  // Method to insert a category
  Future<void> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    await db.insert(
      'categories',
      category,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Method to insert an antibiogram
  Future<void> insertAntibiogram(Map<String, dynamic> antibiogram) async {
    final db = await database;
    await db.insert(
      'antibiograms',
      antibiogram,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Getter function to fetch all categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories');
  }

  // Getter function to fetch all antibiograms
  Future<List<Map<String, dynamic>>> getAntibiograms() async {
    final db = await database;
    return await db.query('antibiograms');
  }

  // Method to clear all data from both tables
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('categories');
    await db.delete('antibiograms');
  }

  Future<List<Map<String, dynamic>>> getAntibiogramIdsByCategoryAndSubCategory(
      String categoryId, String subCategory) async {
    final db = await database;
    return await db.query(
      'antibiograms',
      columns: ['antibiogram_id'], // Only fetch the antibiogram_id column
      where: 'category_id = ? AND sub_category = ?',
      whereArgs: [categoryId, subCategory],
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> getAntibiogramsByIdsAndType(
      List<String> antibiogramIds) async {
    final db = await database;

    // Create a comma-separated string of placeholders for the SQL query (for the IN clause)
    String placeholders = List.filled(antibiogramIds.length, '?').join(', ');

    // Query to get data based on the list of antibiogram_ids and group by type
    List<Map<String, dynamic>> results = await db.rawQuery('''
    SELECT * FROM antibiograms
    WHERE antibiogram_id IN ($placeholders)
  ''', antibiogramIds);

    // Separate the data into two lists based on 'type'
    List<Map<String, dynamic>> gramPositiveList = [];
    List<Map<String, dynamic>> gramNegativeList = [];

    for (var result in results) {
      if (result['type'] == 'gram positive') {
        gramPositiveList.add(result);
      } else if (result['type'] == 'gram negative') {
        gramNegativeList.add(result);
      }
    }

    // Return both lists in a Map
    return {
      'gram_positive': gramPositiveList,
      'gram_negative': gramNegativeList,
    };
  }

  Future<void> insertAntibiogramView(
      Map<String, dynamic> antibiogramView) async {
    final db = await database;
    await db.insert(
      'antibiogram_views',
      antibiogramView,
    );
  }

  Future<List<Map<String, dynamic>>> getAntibiogramViews() async {
    final db = await database;
    // include 'id' here so the caller can delete by id
    return await db.query(
      'antibiogram_views',
      columns: [
        'id',
        'category_id',
        'sub_category',
        'type',
        'view',
        'date',
        'chat'
      ],
    );
  }

  Future<void> deleteAntibiogramView(Map<String, dynamic> view) async {
    final db = await database;

    if (view.containsKey('id') && view['id'] != null) {
      // Safe delete by primary key
      await db.delete(
        'antibiogram_views',
        where: 'id = ?',
        whereArgs: [view['id']],
      );
      return;
    }

    await db.delete(
      'antibiogram_views',
      where:
          'category_id = ? AND sub_category = ? AND type = ? AND date = ? AND chat = ?',
      whereArgs: [
        view['category_id'],
        view['sub_category'],
        view['type'],
        view['date'],
        view['chat'],
      ],
    );
  }

  Future<void> printAntibiogramViews() async {
    final db = await database;
    final List<Map<String, dynamic>> antibiogramViews =
        await db.query('antibiogram_views');

    debugPrint('Printing contents of the antibiogram_views table:');

    for (var view in antibiogramViews) {
      debugPrint(
          view.toString()); // Using debugPrint for cleaner debugging output
    }
  }
}
