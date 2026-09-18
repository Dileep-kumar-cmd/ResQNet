import 'dart:async';
import 'dart:typed_data';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile/data/local/database_helper.dart';

class MapTileService {
  static final MapTileService instance = MapTileService._init();
  MapTileService._init();

  /// Retrieves cached tile blob or generates offline placeholder grid tile
  Future<Uint8List?> getTileBlob(String regionId, int z, int x, int y) async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'map_tiles',
      where: 'region_id = ? AND z = ? AND x = ? AND y = ?',
      whereArgs: [regionId, z, x, y],
    );

    if (maps.isNotEmpty) {
      final blobData = maps.first['blob'];
      if (blobData is Uint8List) {
        return blobData;
      } else if (blobData is List<int>) {
        return Uint8List.fromList(blobData);
      }
    }
    return null;
  }

  /// Saves downloaded tile package to local SQLite database
  Future<void> cacheTileBlob({
    required String regionId,
    required int z,
    required int x,
    required int y,
    required Uint8List blob,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'map_tiles',
      {
        'region_id': regionId,
        'z': z,
        'x': x,
        'y': y,
        'blob': blob,
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
