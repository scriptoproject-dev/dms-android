import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelperNotification {
  static final DatabaseHelperNotification _instance =
      DatabaseHelperNotification._internal();
  static Database? _database;

  DatabaseHelperNotification._internal();

  factory DatabaseHelperNotification() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'notifications.db');
    debugPrint('Database Path: $path');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notifications (
        unique_id TEXT PRIMARY KEY,
        notification_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        schedule_time REAL NOT NULL,
        viewed INTEGER NOT NULL,
        received INTEGER NOT NULL,
        status TEXT NOT NULL,
        content_id TEXT,
        content_comment TEXT,
        category_id TEXT,
        category_name TEXT,
        content_type TEXT,
        sub_category TEXT,
        audit_created_by TEXT NOT NULL,
        audit_created_id TEXT NOT NULL,
        audit_created_on INTEGER NOT NULL,
        audit_modified_by TEXT,
        audit_modified_id TEXT,
        audit_modified_on INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE pending_viewed_notifications (
        notification_id TEXT PRIMARY KEY
      );
    ''');
    debugPrint('Notifications table created.');
  }

  Future<void> insertNotifications(
      List<Map<String, dynamic>> notifications) async {
    final db = await database;
    final batch = db.batch();
    for (var notification in notifications) {
      debugPrint('Inserting notification: ${notification.toString()}');
      batch.insert(
        'notifications',
        notification,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
    debugPrint('Notifications inserted successfully.');
  }

  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    final db = await database;
    List<Map<String, dynamic>> notifications = await db.query('notifications');
    debugPrint('Retrieved notifications FROM DB: ${notifications.toString()}');
    return notifications;
  }

  Future<void> markAsViewed(String notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'viewed': 1}, // Set viewed to true (1)
      where: 'notification_id = ?',
      whereArgs: [notificationId],
    );
    debugPrint('Notification marked as viewed: $notificationId');
  }

  Future<void> addPendingViewedNotification(String notificationId) async {
    final db = await database;
    await db.insert(
      'pending_viewed_notifications',
      {'notification_id': notificationId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('Added pending viewed notification: $notificationId');
  }

  Future<List<String>> getPendingViewedNotifications() async {
    final db = await database;
    List<Map<String, dynamic>> result =
        await db.query('pending_viewed_notifications');
    return result.map((map) => map['notification_id'] as String).toList();
  }

  Future<void> removePendingViewedNotification(String notificationId) async {
    final db = await database;
    await db.delete(
      'pending_viewed_notifications',
      where: 'notification_id = ?',
      whereArgs: [notificationId],
    );
    debugPrint('Removed pending viewed notification: $notificationId');
  }

  Future<void> clearNotifications() async {
    final db = await database;
    await db.delete('notifications');
    debugPrint("Notifications table cleared.");
  }

  Future<bool> hasUnreadNotifications() async {
    final db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'notifications',
      columns: ['notification_id'],
      where: 'viewed = ?',
      whereArgs: [0],
      limit: 1, // Only check for one unread notification
    );
    bool hasUnread = result.isNotEmpty;
    debugPrint('Unread notifications exist: $hasUnread');
    return hasUnread;
  }
}
