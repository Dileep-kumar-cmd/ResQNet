import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('resqnet_local.db');
    try {
      await _database!.update(
        'shelters',
        {'latitude': 37.7812, 'longitude': -122.4160},
        where: 'id = ?',
        whereArgs: ['shl_001'],
      );
    } catch (_) {}
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.update(
            'shelters',
            {'latitude': 37.7812, 'longitude': -122.4160},
            where: 'id = ?',
            whereArgs: ['shl_001'],
          );
        }
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Shelters Table
    await db.execute('''
      CREATE TABLE shelters (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        capacity INTEGER NOT NULL DEFAULT 100,
        current_occupancy INTEGER NOT NULL DEFAULT 0,
        hazard_rating INTEGER NOT NULL DEFAULT 0,
        equipment_json TEXT,
        updated_at TEXT NOT NULL,
        vector_clock TEXT
      )
    ''');

    // 2. Medical Infrastructure Table
    await db.execute('''
      CREATE TABLE medical_infra (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        type TEXT NOT NULL,
        capacity INTEGER NOT NULL DEFAULT 50,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Emergency Contacts Table
    await db.execute('''
      CREATE TABLE emergency_contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        phone TEXT NOT NULL,
        latitude REAL,
        longitude REAL
      )
    ''');

    // 4. SOS Logs Table
    await db.execute('''
      CREATE TABLE sos_logs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'QUEUED',
        synced_bool INTEGER NOT NULL DEFAULT 0,
        relay_path_json TEXT,
        vector_clock TEXT
      )
    ''');

    // 5. Map Tiles Offline Cache Table
    await db.execute('''
      CREATE TABLE map_tiles (
        region_id TEXT NOT NULL,
        z INTEGER NOT NULL,
        x INTEGER NOT NULL,
        y INTEGER NOT NULL,
        blob BLOB NOT NULL,
        downloaded_at TEXT NOT NULL,
        PRIMARY KEY (region_id, z, x, y)
      )
    ''');

    // 6. Sync Queue Table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        op TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        vector_clock TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Seed initial offline sample shelters and emergency contacts
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // Seed Sample Shelters
    await db.insert('shelters', {
      'id': 'shl_001',
      'name': 'Civic Community Shelter',
      'latitude': 37.7812,
      'longitude': -122.4160,
      'capacity': 250,
      'current_occupancy': 85,
      'hazard_rating': 1,
      'equipment_json': jsonEncode({'generators': 2, 'clean_water_liters': 5000, 'first_aid_kits': 40}),
      'updated_at': now,
      'vector_clock': jsonEncode({'local': 1})
    });

    await db.insert('shelters', {
      'id': 'shl_002',
      'name': 'North Hill High School Shelter',
      'latitude': 37.7850,
      'longitude': -122.4090,
      'capacity': 500,
      'current_occupancy': 320,
      'hazard_rating': 0,
      'equipment_json': jsonEncode({'generators': 4, 'clean_water_liters': 12000, 'first_aid_kits': 100}),
      'updated_at': now,
      'vector_clock': jsonEncode({'local': 1})
    });

    // Seed Sample Medical Infrastructure
    await db.insert('medical_infra', {
      'id': 'med_001',
      'name': 'Metro General Hospital',
      'latitude': 37.7690,
      'longitude': -122.4280,
      'type': 'HOSPITAL',
      'capacity': 350,
      'updated_at': now,
    });

    await db.insert('medical_infra', {
      'id': 'med_002',
      'name': 'North Trauma & Relief Center',
      'latitude': 37.7810,
      'longitude': -122.4010,
      'type': 'TRAUMA_CENTER',
      'capacity': 150,
      'updated_at': now,
    });

    // Seed Sample Emergency Contacts
    await db.insert('emergency_contacts', {
      'id': 'contact_001',
      'name': 'Disaster Relief Control HQ',
      'type': 'HQ',
      'phone': '1-800-555-RESQ',
      'latitude': 37.7749,
      'longitude': -122.4194
    });

    await db.insert('emergency_contacts', {
      'id': 'contact_002',
      'name': 'Metro Search & Rescue Team A',
      'type': 'FIRST_RESPONDER',
      'phone': '1-800-555-SAR1',
      'latitude': 37.7800,
      'longitude': -122.4100
    });
  }

  /// Spatial calculation helper: Haversine distance in km
  double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Retrieves shelters ranked by proximity to user location
  Future<List<Map<String, dynamic>>> getNearbyShelters(double userLat, double userLon) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query('shelters');

    List<Map<String, dynamic>> sheltersWithDistance = maps.map((s) {
      final double sLat = (s['latitude'] as num).toDouble();
      final double sLon = (s['longitude'] as num).toDouble();
      final double dist = calculateDistanceKm(userLat, userLon, sLat, sLon);
      final Map<String, dynamic> mutable = Map<String, dynamic>.from(s);
      mutable['distance_km'] = dist;
      return mutable;
    }).toList();

    sheltersWithDistance.sort((a, b) => (a['distance_km'] as double).compareTo(b['distance_km'] as double));
    return sheltersWithDistance;
  }

  /// Synchronizes shelters from backend list into local SQLite cache.
  /// Upserts all server shelters and removes any obsolete shelters no longer on the server.
  Future<int> syncSheltersFromServer(List<dynamic> serverShelters) async {
    final db = await instance.database;
    final Set<String> serverIds = {};
    int count = 0;

    await db.transaction((txn) async {
      for (final raw in serverShelters) {
        if (raw is! Map) continue;
        final s = Map<String, dynamic>.from(raw);
        final id = s['id']?.toString();
        if (id == null || id.isEmpty) continue;
        serverIds.add(id);

        final equipment = s['equipment_json'];
        final equipmentStr = equipment is String ? equipment : jsonEncode(equipment ?? {});

        await txn.insert(
          'shelters',
          {
            'id': id,
            'name': s['name']?.toString() ?? 'Unnamed Shelter',
            'latitude': (s['latitude'] as num?)?.toDouble() ?? 0.0,
            'longitude': (s['longitude'] as num?)?.toDouble() ?? 0.0,
            'capacity': (s['capacity'] as num?)?.toInt() ?? 100,
            'current_occupancy': (s['current_occupancy'] as num?)?.toInt() ?? 0,
            'hazard_rating': (s['hazard_rating'] as num?)?.toInt() ?? 0,
            'equipment_json': equipmentStr,
            'updated_at': s['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
            'vector_clock': jsonEncode({'server_synced': 1}),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }

      // If the server returned valid shelters, prune local shelters that were deleted from server
      if (serverIds.isNotEmpty) {
        final existingLocal = await txn.query('shelters', columns: ['id']);
        for (final row in existingLocal) {
          final localId = row['id'] as String;
          if (!serverIds.contains(localId)) {
            await txn.delete('shelters', where: 'id = ?', whereArgs: [localId]);
          }
        }
      }
    });

    return count;
  }

  /// Queues an entity mutation into local sync queue
  Future<int> queueSyncOperation({
    required String entityType,
    required String entityId,
    required String op,
    required Map<String, dynamic> payload,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    return await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'op': op,
      'payload_json': jsonEncode(payload),
      'vector_clock': jsonEncode({'local_seq': DateTime.now().millisecondsSinceEpoch}),
      'created_at': now,
    });
  }

  /// Gets all items pending sync
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await instance.database;
    return await db.query('sync_queue', orderBy: 'id ASC');
  }

  /// Close DB instance
  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
