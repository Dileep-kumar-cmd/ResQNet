class MeshDeduplicator {
  static final MeshDeduplicator instance = MeshDeduplicator._init();
  MeshDeduplicator._init();

  final int _maxCacheSize = 1000;
  final List<String> _seenPacketIds = [];

  /// Checks if packet has already been processed or relayed by this node
  bool hasSeen(String packetId) {
    return _seenPacketIds.contains(packetId);
  }

  /// Marks packet ID as processed and evicts oldest entries if exceeding cache size
  void markSeen(String packetId) {
    if (!_seenPacketIds.contains(packetId)) {
      _seenPacketIds.add(packetId);
      if (_seenPacketIds.length > _maxCacheSize) {
        _seenPacketIds.removeAt(0); // Evict LRU oldest
      }
    }
  }

  /// Total count of unique packets de-duplicated
  int get totalSeenCount => _seenPacketIds.length;

  /// Resets deduplicator state
  void clear() {
    _seenPacketIds.clear();
  }
}
