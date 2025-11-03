// notification_storage.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model.dart';

// Import your models
// import 'models/notification_item.dart';
// import 'models/notification_settings.dart';

class NotificationStorage {
  static NotificationStorage? _instance;
  static Database? _database;

  // Singleton pattern
  NotificationStorage._();

  factory NotificationStorage() {
    _instance ??= NotificationStorage._();
    return _instance!;
  }

  // Initialize database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'notifications.db');

    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Notifications table
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        source TEXT NOT NULL,
        one_time_date INTEGER,
        recurring_time TEXT,
        end_date INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        extras TEXT
      )
    ''');

    // Create index for faster queries
    await db.execute('''
      CREATE INDEX idx_source ON notifications(source)
    ''');

    await db.execute('''
      CREATE INDEX idx_active ON notifications(is_active)
    ''');
  }

  // ============================================================================
  // NOTIFICATION CRUD OPERATIONS
  // ============================================================================

  /// Save a notification
  Future<void> saveNotification(NotificationItem item) async {
    final db = await database;
    await db.insert(
      'notifications',
      item.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update a notification
  Future<void> updateNotification(NotificationItem item) async {
    final db = await database;
    await db.update(
      'notifications',
      item.toJson(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  /// Delete a notification
  Future<void> deleteNotification(String id) async {
    final db = await database;
    await db.delete('notifications', where: 'id = ?', whereArgs: [id]);
  }

  /// Get notification by ID
  Future<NotificationItem?> getNotificationById(String id) async {
    final db = await database;
    final results = await db.query(
      'notifications',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;
    return NotificationItem.fromJson(results.first);
  }

  /// Get all notifications
  Future<List<NotificationItem>> getAllNotifications() async {
    final db = await database;
    final results = await db.query('notifications');

    return results.map((json) => NotificationItem.fromJson(json)).toList();
  }

  /// Get notifications by source (api or user)
  Future<List<NotificationItem>> getNotificationsBySource(
    NotificationSource source,
  ) async {
    final db = await database;
    final results = await db.query(
      'notifications',
      where: 'source = ?',
      whereArgs: [source.name],
    );

    return results.map((json) => NotificationItem.fromJson(json)).toList();
  }

  /// Get active notifications only
  Future<List<NotificationItem>> getActiveNotifications() async {
    final db = await database;
    final results = await db.query(
      'notifications',
      where: 'is_active = ?',
      whereArgs: [1],
    );

    return results.map((json) => NotificationItem.fromJson(json)).toList();
  }

  /// Delete all notifications by source
  Future<void> deleteAllBySource(NotificationSource source) async {
    final db = await database;
    await db.delete(
      'notifications',
      where: 'source = ?',
      whereArgs: [source.name],
    );
  }

  /// Delete expired notifications
  Future<int> deleteExpiredNotifications() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.delete(
      'notifications',
      where: 'end_date IS NOT NULL AND end_date < ?',
      whereArgs: [now],
    );
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    final db = await database;
    await db.delete('notifications');
  }

  // ============================================================================
  // SETTINGS OPERATIONS (Using SharedPreferences for simplicity)
  // ============================================================================

  static const String _settingsKey = 'notification_settings';

  /// Save notification settings
  Future<void> saveSettings(NotificationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// Get notification settings
  Future<NotificationSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_settingsKey);

    if (jsonStr == null) {
      return NotificationSettings.defaults;
    }

    return NotificationSettings.fromJson(jsonDecode(jsonStr));
  }

  // ============================================================================
  // API CACHE OPERATIONS (Optional - for offline fallback)
  // ============================================================================

  static const String _cachePrefix = 'api_cache_';

  /// Cache API reminders for a specific date
  Future<void> cacheApiReminders(
    DateTime date,
    List<NotificationItem> reminders,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cachePrefix + _formatDate(date);

    final cacheData = {
      'date': date.millisecondsSinceEpoch,
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'cached_at': DateTime.now().millisecondsSinceEpoch,
    };

    await prefs.setString(cacheKey, jsonEncode(cacheData));
  }

  /// Get cached API reminders for a specific date
  Future<List<NotificationItem>?> getCachedApiReminders(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cachePrefix + _formatDate(date);
    final jsonStr = prefs.getString(cacheKey);

    if (jsonStr == null) return null;

    final cacheData = jsonDecode(jsonStr);
    final remindersList = cacheData['reminders'] as List;

    return remindersList
        .map((json) => NotificationItem.fromJson(json))
        .toList();
  }

  /// Check if cache exists for a date
  Future<bool> hasCacheForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cachePrefix + _formatDate(date);
    return prefs.containsKey(cacheKey);
  }

  /// Get cache age in hours
  Future<int?> getCacheAge(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _cachePrefix + _formatDate(date);
    final jsonStr = prefs.getString(cacheKey);

    if (jsonStr == null) return null;

    final cacheData = jsonDecode(jsonStr);
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(
      cacheData['cached_at'] as int,
    );

    return DateTime.now().difference(cachedAt).inHours;
  }

  /// Clear old cache (older than X days)
  Future<void> clearOldCache({int daysToKeep = 7}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    for (final key in keys) {
      if (key.startsWith(_cachePrefix)) {
        final dateStr = key.replaceFirst(_cachePrefix, '');
        try {
          final date = DateTime.parse(dateStr);
          if (date.isBefore(cutoffDate)) {
            await prefs.remove(key);
          }
        } catch (e) {
          // Invalid date format, remove it
          await prefs.remove(key);
        }
      }
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get database statistics
  Future<Map<String, int>> getStatistics() async {
    final db = await database;

    final total =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM notifications'),
        ) ??
        0;

    final apiCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM notifications WHERE source = ?',
            ['api'],
          ),
        ) ??
        0;

    final userCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM notifications WHERE source = ?',
            ['user'],
          ),
        ) ??
        0;

    final activeCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM notifications WHERE is_active = 1',
          ),
        ) ??
        0;

    return {
      'total': total,
      'api': apiCount,
      'user': userCount,
      'active': activeCount,
      'inactive': total - activeCount,
    };
  }

  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Reset database (useful for testing)
  Future<void> resetDatabase() async {
    final db = await database;
    await db.delete('notifications');

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
