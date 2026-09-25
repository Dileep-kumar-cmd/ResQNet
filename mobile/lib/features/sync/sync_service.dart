import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/data/local/database_helper.dart';
import 'package:mobile/core/config/api_config.dart';

class SyncResult {
  final bool isSuccess;
  final int processedCount;
  final int conflictsResolved;
  final String message;

  SyncResult({
    required this.isSuccess,
    required this.processedCount,
    required this.conflictsResolved,
    required this.message,
  });
}

class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._init();
  SyncService._init();

  final String clientId = 'device_client_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Pulls all regional shelters from the backend and updates SQLite cache
  Future<int> pullSheltersFromServer() async {
    final hosts = await ApiConfig.getCandidateHosts();
    for (final host in hosts) {
      try {
        final url = ApiConfig.formatUrl(host, '/api/v1/admin/shelters');
        debugPrint('[SYNC_DEBUG] Pulling shelters from $url...');
        final response = await http.get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final dynamic data = jsonDecode(response.body);
          if (data is List) {
            final count = await DatabaseHelper.instance.syncSheltersFromServer(data);
            debugPrint('[SYNC_DEBUG] Successfully pulled and synced $count shelters from $host');
            return count;
          }
        }
      } catch (e) {
        debugPrint('[SYNC_DEBUG] Pull shelters from $host failed: $e');
      }
    }
    return 0;
  }

  /// Triggers bi-directional cloud sync between SQLite sync_queue and FastAPI backend
  Future<SyncResult> triggerSync() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> queueItems = await dbHelper.getPendingSyncItems();

      int processed = 0;
      int conflicts = 0;
      bool pushFailed = false;
      String? pushError;

      // 1. If queue has items, push them to /api/v1/sync/push
      if (queueItems.isNotEmpty) {
        List<Map<String, dynamic>> changesPayload = [];
        List<int> queueRowIds = [];

        for (final item in queueItems) {
          final int id = item['id'] as int;
          queueRowIds.add(id);

          changesPayload.add({
            'entity_type': item['entity_type'],
            'entity_id': item['entity_id'],
            'op': item['op'],
            'payload': jsonDecode(item['payload_json']),
            'vector_clock': item['vector_clock'] != null ? jsonDecode(item['vector_clock']) : {},
            'updated_at': item['created_at'],
          });
        }

        final requestBody = {
          'client_id': clientId,
          'vector_clock': {'client_seq': queueRowIds.length},
          'last_synced_at': _lastSyncTime?.toIso8601String(),
          'changes': changesPayload,
        };

        final hosts = await ApiConfig.getCandidateHosts();
        http.Response? response;
        String? successfulHost;

        for (final host in hosts) {
          try {
            final url = ApiConfig.formatUrl(host, '/api/v1/sync/push');
            debugPrint('[SYNC_DEBUG] Attempting sync push to $url...');
            response = await http.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            ).timeout(const Duration(seconds: 4));
            if (response.statusCode == 200) {
              successfulHost = host;
              debugPrint('[SYNC_DEBUG] Sync push succeeded with host $host');
              break;
            }
          } catch (e) {
            pushError = e.toString();
            debugPrint('[SYNC_DEBUG] Host $host failed: $e');
          }
        }

        if (response != null && response.statusCode == 200) {
          if (successfulHost != null) {
            await ApiConfig.setCustomHost(successfulHost);
          }

          final resData = jsonDecode(response.body);
          processed = resData['processed_count'] ?? 0;
          conflicts = resData['conflicts_resolved'] ?? 0;

          // Drain processed items from local SQLite sync_queue
          for (final rowId in queueRowIds) {
            await db.delete('sync_queue', where: 'id = ?', whereArgs: [rowId]);
          }

          // Mark local sos_logs as synced
          await db.update('sos_logs', {'synced_bool': 1});
        } else {
          pushFailed = true;
        }
      }

      // 2. Always pull latest shelters from backend to ensure admin additions/removals are synced
      final int pulledShelters = await pullSheltersFromServer();

      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      notifyListeners();

      if (queueItems.isEmpty) {
        return SyncResult(
          isSuccess: true,
          processedCount: pulledShelters,
          conflictsResolved: 0,
          message: pulledShelters > 0
              ? 'Local sync queue is clean (0 items to sync). Synced $pulledShelters shelters with cloud.'
              : 'Local sync queue is clean. 0 items to sync.',
        );
      }

      if (!pushFailed) {
        return SyncResult(
          isSuccess: true,
          processedCount: processed,
          conflictsResolved: conflicts,
          message: 'Synced $processed items ($conflicts CRDT resolved) & $pulledShelters shelters.',
        );
      } else {
        return SyncResult(
          isSuccess: false,
          processedCount: 0,
          conflictsResolved: 0,
          message: 'Sync offline: Backend unreachable. ($pushError)',
        );
      }
    } catch (e) {
      debugPrint('[SYNC_DEBUG] Sync critical failure: $e');
      _isSyncing = false;
      notifyListeners();
      return SyncResult(
        isSuccess: false,
        processedCount: 0,
        conflictsResolved: 0,
        message: 'Sync error: $e',
      );
    }
  }
}
