import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/features/sync/sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    FlutterSecureStorage.setMockInitialValues({});

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => '.',
    );
  });

  group('Phase 5 Cloud Sync Unit Tests', () {
    test('SyncService handles clean queue gracefully when 0 items pending', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('sync_queue'); // Clear any pending items from earlier test runs

      final syncService = SyncService.instance;
      final result = await syncService.triggerSync();

      expect(result.processedCount, equals(0));
      expect(result.message, contains('0 items to sync'));
    });

    test('DatabaseHelper queueSyncOperation inserts items into local SQLite sync_queue', () async {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.queueSyncOperation(
        entityType: 'shelters',
        entityId: 'shl_unit_test',
        op: 'UPDATE_OCCUPANCY',
        payload: {'current_occupancy': 150},
      );

      final items = await dbHelper.getPendingSyncItems();
      expect(items.isNotEmpty, isTrue);
      final lastItem = items.lastWhere((item) => item['entity_id'] == 'shl_unit_test');
      expect(lastItem['entity_type'], equals('shelters'));
      expect(lastItem['op'], equals('UPDATE_OCCUPANCY'));
    });
  });
}
