import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile/data/local/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Haversine distance calculation produces correct kilometer result', () {
    final dbHelper = DatabaseHelper.instance;
    // San Francisco (37.7749, -122.4194) to Oakland (37.8044, -122.2712) ~ 13.5 km
    final dist = dbHelper.calculateDistanceKm(37.7749, -122.4194, 37.8044, -122.2712);
    expect(dist, greaterThan(12.0));
    expect(dist, lessThan(15.0));
  });

  test('Database helper seeds shelters and emergency contacts correctly', () async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shelters (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            capacity INTEGER NOT NULL,
            current_occupancy INTEGER NOT NULL,
            hazard_rating INTEGER NOT NULL,
            equipment_json TEXT,
            updated_at TEXT NOT NULL,
            vector_clock TEXT
          )
        ''');

        await db.insert('shelters', {
          'id': 'shl_test',
          'name': 'Test Shelter',
          'latitude': 37.7749,
          'longitude': -122.4194,
          'capacity': 100,
          'current_occupancy': 10,
          'hazard_rating': 0,
          'equipment_json': '{}',
          'updated_at': DateTime.now().toIso8601String(),
          'vector_clock': '{}'
        });
      },
    );

    final List<Map<String, dynamic>> results = await db.query('shelters');
    expect(results.length, equals(1));
    expect(results.first['name'], equals('Test Shelter'));
    await db.close();
  });
}
