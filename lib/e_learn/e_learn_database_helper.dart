import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ElearnDatabaseHelper {
  static final ElearnDatabaseHelper _instance = ElearnDatabaseHelper._();
  static Database? _database;

  ElearnDatabaseHelper._();

  factory ElearnDatabaseHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'elearn.db');

    return await openDatabase(
      path,
      version: 4, // Incremented after adding the helpful to the database
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE elearns_summary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            elearn_id TEXT UNIQUE,
            heading TEXT,
            thumbnail_id TEXT,
            description TEXT,
            completed INTEGER,
            modified_on INTEGER,
            liked INTEGER,
            disliked INTEGER,
            user_completed INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE elearn_files (
            file_id TEXT PRIMARY KEY,
            elearn_id TEXT,
            file_name TEXT,
            download_url TEXT,
            content_type TEXT,
            FOREIGN KEY (elearn_id) REFERENCES elearns_summary (elearn_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            elearn_id TEXT,
            like BOOLEAN,
            dislike BOOLEAN,
            view BOOLEAN,
            completed BOOLEAN,
            date INTEGER,
            helpful BOOLEAN DEFAULT NULL
          )
        ''');
      },
      //Upgraded after adding the helpful to the database
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await db.execute('''
        ALTER TABLE offline_metrics
        ADD COLUMN helpful BOOLEAN DEFAULT NULL
      ''');
        }
      },
    );
  }

  // Store data from the API response

  Future<void> storeApiResponse(Map<String, dynamic> apiResponse) async {
    final data = apiResponse['data'];
    if (data == null || data.isEmpty) {
      debugPrint('API response data is null or empty.');
      return;
    }

    for (var item in data) {
      String elearnId = item['elearn_id'] ?? '';
      String heading = item['heading'] ?? 'Untitled';
      String thumbnailId = item['thumbnail_id'] ?? '';
      String description = item['description'] ?? 'No description';
      int completed = item['completed'] ?? 0;
      int modifiedOn =
          item['audit_log']?['modified_on'] ?? item['audit_log']?['created_on'];
      int liked = (item['liked'] == true) ? 1 : 0;
      int disliked = (item['disliked'] == true) ? 1 : 0;
      int userCompleted = (item['user_completed'] == true) ? 1 : 0;

      // Insert or update the main elearn entry
      bool exists = await _checkIfExists(elearnId);
      if (exists) {
        await updateUserCompleted(elearnId, userCompleted);
      }
      if (!exists) {
        await insertData(
          elearnId,
          heading,
          thumbnailId,
          description,
          completed,
          modifiedOn,
          liked,
          disliked,
          userCompleted,
        );
      }
    }
  }

  // Insert data into the 'elearns_summary' table
  Future<void> insertData(
      String elearnId,
      String heading,
      String thumbnailId,
      String description,
      int completed,
      int modifiedOn,
      int liked,
      int disliked,
      int userCompleted) async {
    final db = await database;
    await db.insert(
      'elearns_summary',
      {
        'elearn_id': elearnId,
        'heading': heading,
        'thumbnail_id': thumbnailId,
        'description': description,
        'completed': completed,
        'modified_on': modifiedOn,
        'liked': liked,
        'disliked': disliked,
        'user_completed': userCompleted
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert data into the 'elearn_files' table
  Future<void> insertFileData(String elearnId, String fileId, String fileName,
      String downloadUrl, String contentType) async {
    final db = await database;
    await db.insert(
      'elearn_files',
      {
        'elearn_id': elearnId,
        'file_id': fileId,
        'file_name': fileName,
        'download_url': downloadUrl,
        'content_type': contentType,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert offline metric data into the 'offline_metrics' table
  Future<void> storeOfflineMetric(Map<String, dynamic> metrics) async {
    debugPrint("Successfully uploaded metric stored: $metrics");
    final db = await database;
    debugPrint('completed matrice: ${metrics['completed']}');
    await db.insert(
      'offline_metrics',
      {
        'elearn_id': metrics['elearn_id'],
        'like': metrics['like'] ?? false,
        'dislike': metrics['dislike'] ?? false,
        'view': metrics['view'] ?? false,
        'completed': metrics['completed'] ?? false,
        'date': metrics['date'],
        'helpful': metrics['helpful'], // Can be true, false, or null
      },
    );
  }

  // Check if an elearn_id already exists in the database
  Future<bool> _checkIfExists(String elearnId) async {
    final db = await database;
    var result = await db.query(
      'elearns_summary',
      where: 'elearn_id = ?',
      whereArgs: [elearnId],
    );
    return result.isNotEmpty;
  }

  // Fetch all eLearn entries
  Future<List<Map<String, dynamic>>> getAllELearns() async {
    final db = await database;
    return await db.query('elearns_summary');
  }

  Future<List<Map<String, dynamic>>> getFilesByElearnId(String elearnId) async {
    final db = await database;
    return await db.query(
      'elearn_files',
      where: 'elearn_id = ?',
      whereArgs: [elearnId],
    );
  }

  Future<void> updateLikeDislikeStatus(
      String elearnId, int liked, int disliked) async {
    final db = await database;

    await db.update(
      'elearns_summary',
      {
        'liked': liked,
        'disliked': disliked,
      },
      where: 'elearn_id = ?',
      whereArgs: [elearnId],
    );
  }

  // Fetch all offline metrics
  Future<List<Map<String, dynamic>>> getOfflineMetrics() async {
    final db = await database;
    return await db.query('offline_metrics');
  }

  Future<int> deleteOfflineMetricById(int id) async {
    final db = await database;
    return await db.delete(
      'offline_metrics',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateUserCompleted(String elearnId, int userCompleted) async {
    final db = await database;
    await db.update(
      'elearns_summary',
      {'user_completed': userCompleted},
      where: 'elearn_id = ?',
      whereArgs: [elearnId],
    );
  }

  Future<void> clearTables() async {
    final db = await database;
    // Clear the 'elearns_summary' table
    await db.delete('elearns_summary');

    // Clear the 'elearn_files' table
    await db.delete('elearn_files');
    debugPrint('Cleared elearns_summary and elearn_files tables.');
  }
}
