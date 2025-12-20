import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:qr_scanner_app/models/antibiotic.dart';
import 'package:qr_scanner_app/models/antibiotic_with_status.dart';
import 'package:qr_scanner_app/models/reasons.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Database? _database;

  // Initialize the SQLite database
  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'antibiotics.db');

    _database = await openDatabase(
      path,
      version: 18, // Incremented version number
      onCreate: (db, version) async {
        await db.execute(
          '''CREATE TABLE antibiotics (
               antibiotic_id TEXT PRIMARY KEY,
               name TEXT,
               parent TEXT,
               type TEXT,
               data TEXT,
               aware_classification TEXT,
               causative_organism TEXT,
               index_order INTEGER,
               children TEXT,
               ancestors TEXT,
               site_id TEXT,
               status TEXT,
               audit_log TEXT,
               bookmarked INTEGER DEFAULT 0,  -- Bookmark field
               connection TEXT DEFAULT 'offline'  -- Connection field
            )''',
        );

        await db.execute(
          '''CREATE TABLE antibiotic_metadata (
               id INTEGER PRIMARY KEY AUTOINCREMENT,
               status INTEGER,
               message TEXT,
               version REAL,
               total INTEGER
            )''',
        );

        // Create a new table for storing view actions
        await db.execute('''
    CREATE TABLE antibiotic_views (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      antibiotic_id TEXT NOT NULL,
      action TEXT NOT NULL,
      view INTEGER NOT NULL,
      date INTEGER NOT NULL
    )''');

        // Create reasons table
        await db.execute('''
        CREATE TABLE reasons (
          reason_id TEXT PRIMARY KEY,
          reason TEXT,
          site_id TEXT,
          status TEXT,
          audit_log TEXT,
          category TEXT
        )''');

        // Create compliance table
        await db.execute('''
        CREATE TABLE compliance (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          antibiotic_id TEXT NOT NULL,
          complied INTEGER NOT NULL,
          reason_id TEXT,
          message TEXT,
          date INTEGER NOT NULL,
          line_items_ids TEXT,             -- NEW
          line_types TEXT,                 -- NEW
          other_durgs TEXT,                -- NEW
          other_durgs_reason_id TEXT,      -- NEW
          other_durgs_message TEXT,        -- NEW
          helpful INTEGER,                 -- NEW (store bool as 0/1)
          helpful_message TEXT,            -- NEW
          source TEXT,                     -- NEW
          connection TEXT DEFAULT 'offline',
          compile_status TEXT DEFAULT 'no'
        )
        ''');

        // ⬅️ NEW: drugs table
        await db.execute('''
          CREATE TABLE drugs (
            id TEXT PRIMARY KEY,
            antibiotic_id TEXT NOT NULL,
            name TEXT,
            line_type TEXT,
            reason_id TEXT,
            message TEXT,
            other_durgs TEXT,
            other_durgs_reason_id TEXT,
            other_durgs_message TEXT,
            helpful INTEGER,
            helpful_message TEXT,
            FOREIGN KEY (antibiotic_id) REFERENCES antibiotics(antibiotic_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 11) {
          // Create reasons table if it doesn't exist
          await db.execute('''
          CREATE TABLE IF NOT EXISTS reasons (
            reason_id TEXT PRIMARY KEY,
            reason TEXT,
            site_id TEXT,
            status TEXT,
            audit_log TEXT,
            category TEXT
          )''');

          // Create compliance table if it doesn't exist
          await db.execute('''
          CREATE TABLE IF NOT EXISTS compliance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            antibiotic_id TEXT NOT NULL,
            complied INTEGER NOT NULL,
            reason_id TEXT,
            message TEXT,
            date INTEGER NOT NULL,
            connection TEXT DEFAULT 'offline',
            compile_status TEXT DEFAULT 'no'
          )''');
        }
        if (oldVersion < 12) {
          // Check if 'category' column exists before adding
          final columns = await db.rawQuery("PRAGMA table_info(reasons)");
          final columnNames = columns.map((c) => c['name']).toList();
          if (!columnNames.contains('category')) {
            await db.execute('ALTER TABLE reasons ADD COLUMN category TEXT');
          }
        }

        if (oldVersion < 13) {
          final columns = await db.rawQuery("PRAGMA table_info(compliance)");
          final columnNames = columns.map((c) => c['name']).toList();

          Future<void> addColumnIfNotExists(String name, String type) async {
            if (!columnNames.contains(name)) {
              await db.execute('ALTER TABLE compliance ADD COLUMN $name $type');
            }
          }

          await addColumnIfNotExists('line_items_ids', 'TEXT');
          await addColumnIfNotExists('line_types', 'TEXT');
          await addColumnIfNotExists('other_durgs', 'TEXT');
          await addColumnIfNotExists('other_durgs_reason_id', 'TEXT');
          await addColumnIfNotExists('other_durgs_message', 'TEXT');
          await addColumnIfNotExists('helpful', 'INTEGER');
          await addColumnIfNotExists('helpful_message', 'TEXT');
          await addColumnIfNotExists('source', 'TEXT');
        }

        if (oldVersion < 14) {
          // ⬅️ ensure drugs table exists
          await db.execute('''
            CREATE TABLE IF NOT EXISTS drugs (
              id TEXT PRIMARY KEY,
              antibiotic_id TEXT NOT NULL,
              name TEXT,
              line_type TEXT,
              reason_id TEXT,
              message TEXT,
              other_durgs TEXT,
              other_durgs_reason_id TEXT,
              other_durgs_message TEXT,
              helpful INTEGER,
              helpful_message TEXT,
              FOREIGN KEY (antibiotic_id) REFERENCES antibiotics(antibiotic_id)
            )
          ''');
        }

        if (oldVersion < 15) {
          final columns = await db.rawQuery("PRAGMA table_info(antibiotics)");
          final columnNames = columns.map((c) => c['name']).toList();

          if (!columnNames.contains('aware_classification')) {
            await db.execute(
                'ALTER TABLE antibiotics ADD COLUMN aware_classification TEXT');
            debugPrint(
                '✅ Added aware_classification column to antibiotics table');
          }
        }

        if (oldVersion < 16) {
          final columns = await db.rawQuery("PRAGMA table_info(antibiotics)");
          final columnNames = columns.map((c) => c['name']).toList();

          if (!columnNames.contains('causative_organism')) {
            await db.execute(
                'ALTER TABLE antibiotics ADD COLUMN causative_organism TEXT');
            debugPrint(
                '✅ Added causative_organism column to antibiotics table');
          }
        }

        if (oldVersion < 17) {
          final columns = await db.rawQuery("PRAGMA table_info(antibiotics)");
          final columnNames = columns.map((c) => c['name']).toList();

          if (!columnNames.contains('causative_organism')) {
            await db.execute(
                'ALTER TABLE antibiotics ADD COLUMN causative_organism TEXT');
            debugPrint(
                '✅ Added causative_organism column to antibiotics table (v17)');
          } else {
            debugPrint('ℹ️ causative_organism column already exists (v17)');
          }

          // Verify the column was added
          final verifyColumns =
              await db.rawQuery("PRAGMA table_info(antibiotics)");
          debugPrint(
              '📋 All columns after v17 migration: ${verifyColumns.map((c) => c['name']).toList()}');
        }

        if (oldVersion < 18) {
          final columns = await db.rawQuery("PRAGMA table_info(antibiotics)");
          final columnNames = columns.map((c) => c['name']).toList();

          if (!columnNames.contains('index_order')) {
            await db.execute(
                'ALTER TABLE antibiotics ADD COLUMN index_order INTEGER');
            debugPrint('✅ Added index_order column to antibiotics table');
          }
        }
      },
    );
    return _database!;
  }

  // ⬅️ Insert drug
  static Future<void> insertDrug(Map<String, dynamic> drug) async {
    final db = await getDatabase();

    if (drug['helpful'] is bool) {
      drug['helpful'] = (drug['helpful'] as bool) ? 1 : 0;
    }

    await db.insert(
      'drugs',
      drug,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint("💊 Inserted drug: $drug");
  }

  // ⬅️ Fetch drugs for an antibiotic
  static Future<List<Map<String, dynamic>>> getDrugsByAntibioticId(
      String antibioticId) async {
    final db = await getDatabase();
    final result = await db.query(
      'drugs',
      where: 'antibiotic_id = ?',
      whereArgs: [antibioticId],
    );
    debugPrint("💊 Drugs for $antibioticId: $result");
    return result;
  }

  static Future<void> insertAntibiotic(AntibioticWithStatus antibiotic) async {
    final db = await getDatabase();
    final data = antibiotic.antibiotic.toJson();

    // // Remove `bookmarked` if it is null
    // if (data['bookmarked'] == null) {
    //   data.remove('bookmarked');
    // }

    data.remove('index');

    debugPrint(
        'Inserting: ${antibiotic.antibiotic.toJson()}'); // Log the antibiotic data
    await db.insert(
      'antibiotics',
      {
        ...data,
        'aware_classification': antibiotic.antibiotic.awareClassification,
        'causative_organism': antibiotic.antibiotic.causativeOrganism,
        'index_order': antibiotic.antibiotic.index,
        'ancestors': jsonEncode(
            antibiotic.antibiotic.ancestors), // Encode to JSON string
        'children': antibiotic.antibiotic.children != null
            ? jsonEncode(antibiotic.antibiotic.children)
            : null, // Encode to JSON string
        'audit_log':
            jsonEncode(antibiotic.antibiotic.auditLog), // Encode to JSON string
        'bookmarked': antibiotic.bookmarked ? 1 : 0, // Store as integer
        'connection': antibiotic.connection, // Store connection status
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Log all antibiotics after insertion
    final allAntibiotics = await getAntibiotics();
    debugPrint('All Antibiotics after insertion: $allAntibiotics');
  }

// Update the bookmark status for a specific antibiotic
  static Future<void> updateBookmarkStatus(
      String antibioticId, bool isBookmarked) async {
    final db = await getDatabase();
    await db.update(
      'antibiotics',
      {'bookmarked': isBookmarked ? 1 : 0}, // Convert boolean to integer
      where: 'antibiotic_id = ?',
      whereArgs: [antibioticId],
    );
    debugPrint('Updated bookmark status for $antibioticId to $isBookmarked');
  }

  // Clear bookmarks for antibiotics not in the provided list
  static Future<void> clearBookmarksNotInList(List<String> ids) async {
    final db = await getDatabase();
    await db.update(
      'antibiotics',
      {'bookmarked': 0}, // Set all bookmarks to false
      where: 'antibiotic_id NOT IN (${ids.map((id) => "'$id'").join(',')})',
    );
  }

  static Future<void> clearReasonsTable() async {
    final db = await getDatabase();
    await db.delete('reasons'); // Replace 'reasons' with your actual table name
    debugPrint('Reasons table cleared.');
  }

  // Insert or update metadata
  static Future<void> insertMetadata(
      int status, String message, double version, int total) async {
    final db = await getDatabase();

    await db.insert(
      'antibiotic_metadata',
      {
        'status': status,
        'message': message,
        'version': version,
        'total': total,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

// Get metadata
  static Future<Map<String, dynamic>?> getMetadata() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result =
        await db.query('antibiotic_metadata');
    if (result.isNotEmpty) {
      return result.first;
    }
    return null; // Return null if no metadata is found
  }

// Get all antibiotics from the local database
  static Future<List<AntibioticWithStatus>> getAntibiotics() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('antibiotics');
    debugPrint('Retrieved Antibiotics: $maps'); // Log the retrieved data

    debugPrint(
        '📊 First record causative_organism: ${maps.isNotEmpty ? maps[0]['causative_organism'] : "No records"}');

    return List.generate(maps.length, (i) {
      // debugPrint(
      //     '🔍 Record $i causative_organism: ${maps[i]['causative_organism']}'); // Add this
      return AntibioticWithStatus(
        antibiotic: Antibiotic.fromJson({
          ...maps[i],
          'aware_classification': maps[i]['aware_classification'],
          'causative_organism': maps[i]['causative_organism'],
          'index': maps[i]['index_order'],
          'children': maps[i]['children'] != null
              ? List<String>.from(jsonDecode(maps[i]['children']))
              : null,
          'ancestors': List<String>.from(jsonDecode(maps[i]['ancestors'])),
          'audit_log': jsonDecode(maps[i]['audit_log']),
        }),
        bookmarked: maps[i]['bookmarked'] == 1, // Convert integer to boolean
        connection: maps[i]['connection'] ?? 'offline', // Default to 'offline'
      );
    });
  }

  static Future<List<Map<String, dynamic>>> getOfflineAntibiotics() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'antibiotics',
      where: 'connection = ?',
      whereArgs: ['offline'], // Filter for offline connection
    );

    debugPrint("getOfflineAntibiotics called.");
    debugPrint(
        "Number of records found: ${maps.length}"); // Print the number of records found

    return maps; // Return the list of offline antibiotics
  }

  // Update the connection status for a specific antibiotic
  static Future<void> updateConnectionStatus(
      String antibioticId, String connectionStatus) async {
    final db = await getDatabase();
    await db.update(
      'antibiotics',
      {'connection': connectionStatus}, // Set the connection status
      where: 'antibiotic_id = ?',
      whereArgs: [antibioticId],
    );
    debugPrint(
        'Updated connection status for $antibioticId to $connectionStatus');
  }

  static Future<List<AntibioticWithStatus>> getAntibioticsByIds(
      List<String> ids) async {
    final db = await getDatabase();
    final result = await db.query(
      'antibiotics',
      where: 'antibiotic_id IN (${ids.map((id) => "'$id'").join(',')})',
    );

    //   return List.generate(result.length, (i) {
    //     final map = result[i] as Map<String, dynamic>;
    //     return AntibioticWithStatus({
    //       ...map,
    //       'children': map['children'] != null
    //           ? List<String>.from(jsonDecode(map['children']))
    //           : null,
    //       'ancestors': List<String>.from(jsonDecode(map['ancestors'])),
    //       'audit_log': jsonDecode(map['audit_log']),
    //     });
    //   });
    // }
    return List.generate(result.length, (i) {
      final map = result[i] as Map<String, dynamic>;
      // bool isBookmarked = map['bookmarked'] == 1;

      return AntibioticWithStatus(
        antibiotic: Antibiotic.fromJson({
          ...map,
          'aware_classification': map['aware_classification'],
          'causative_organism': map['causative_organism'],
          'index': map['index_order'],
          'children': map['children'] != null
              ? List<String>.from(jsonDecode(map['children']))
              : null,
          'ancestors': List<String>.from(jsonDecode(map['ancestors'])),
          'audit_log': jsonDecode(map['audit_log']),
        }),
        bookmarked: map['bookmarked'] == 1, // Convert integer to boolean
        connection: map['connection'] ?? 'offline', // Default to 'offline'
      );
    });
  }

  // Insert a view action into the database
  static Future<void> insertView(Map<String, dynamic> antibioticView) async {
    final db = await getDatabase();
    await db.insert(
      'antibiotic_views',
      antibioticView,
      // conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('View data inserted successfully.');
  }

// Retrieve all view actions from the database
  static Future<List<Map<String, dynamic>>> getAntibioticViews() async {
    final db = await getDatabase();
    // Exclude the 'id' column by selecting only specific columns
    final views = await db.query(
      'antibiotic_views',
      columns: [
        'antibiotic_id',
        'action ',
        'view',
        'date'
      ], // Specify columns to fetch
    );
    debugPrint('Retrieved antibiotic views: $views'); // Log the retrieved views
    return views;
  }

  static Future<void> deleteAntibioticView(Map<String, dynamic> view) async {
    final db = await getDatabase();
    await db.delete(
      'antibiotic_views',
      where: 'antibiotic_id = ? AND action = ? AND view = ? AND date = ?',
      whereArgs: [
        view['antibiotic_id'],
        view['action'],
        view['view'],
        view['date'],
      ],
    );
  }

  // Clear all data from the antibiotics table
  static Future<void> clearDatabase() async {
    final db = await getDatabase();
    await db.delete('antibiotics'); // Deletes all rows in the table
    await db.delete(
        'antibiotic_metadata'); // Deletes all rows in the metadata table
  }

// Insert a reason into the reasons table
  static Future<void> insertReason(Map<String, dynamic> reason) async {
    final db = await getDatabase();

    debugPrint('Inserting reason: $reason');
    await db.insert(
      'reasons',
      reason,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all reasons from the reasons table
  static Future<List<Reason>> getReasons({String? category}) async {
    // final db = await getDatabase();
    // final List<Map<String, dynamic>> maps = await db.query('reasons');

    // Debugging: Log the fetched reasons
    // debugPrint('Fetched reasons from database: $maps');
    // Convert List<Map<String, dynamic>> to List<Reason>
    // return List.generate(maps.length, (i) {
    //   return Reason.fromJson(maps[i]);
    // });
    // Convert List<Map<String, dynamic>> to List<Reason>
    final db = await getDatabase();
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (category != null && category.isNotEmpty) {
      whereClause = 'category = ?';
      whereArgs = [category];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'reasons',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    debugPrint('Fetched reasons for category "$category": $maps');

    return List.generate(maps.length, (i) {
      // Decode the audit_log if it's a string
      final auditLogJson = maps[i]['audit_log'];
      Map<String, dynamic>? auditLogMap;

      if (auditLogJson is String) {
        auditLogMap = jsonDecode(auditLogJson);
      } else if (auditLogJson is Map) {
        auditLogMap = auditLogJson as Map<String, dynamic>;
      }

      // Create a new map for the Reason object
      final reasonData = {
        ...maps[i],
        'audit_log': auditLogMap,
      };

      return Reason.fromJson(reasonData);
    });
  }

  // Insert a compliance record into the compliance table
  static Future<void> insertCompliance(Map<String, dynamic> compliance) async {
    final db = await getDatabase();

    // Convert boolean to integer for the database
    compliance['complied'] = compliance['complied'] == true ? 1 : 0;
    if (compliance['helpful'] is bool) {
      compliance['helpful'] = (compliance['helpful'] as bool) ? 1 : 0;
    }

    // Convert List<String> → JSON string
    if (compliance['line_items_ids'] is List) {
      compliance['line_items_ids'] = jsonEncode(compliance['line_items_ids']);
    }
    debugPrint('Inserting compliance record: $compliance');
    await db.insert(
      'compliance',
      compliance,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all compliance records from the compliance table
  static Future<List<Map<String, dynamic>>> getComplianceRecords() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('compliance');

    // Decode list back
    for (var record in maps) {
      if (record['line_items_ids'] is String) {
        record['line_items_ids'] =
            List<String>.from(jsonDecode(record['line_items_ids']));
      }
      if (record['complied'] is int) {
        record['complied'] = record['complied'] == 1;
      }
      if (record['helpful'] is int) {
        record['helpful'] = record['helpful'] == 1;
      }
    }

    debugPrint('Fetched Compliance Records: $maps');
    return maps; // Return the list of compliance records
  }

  // Update the connection status for a specific compliance record
  static Future<void> updateComplianceConnectionStatus(
      String antibioticId, String connectionStatus) async {
    final db = await getDatabase();
    await db.update(
      'compliance',
      {'connection': connectionStatus}, // Set the connection status
      where: 'antibiotic_id = ?',
      whereArgs: [antibioticId],
    );
    debugPrint(
        'Updated connection status for compliance record $antibioticId to $connectionStatus');
  }
}
