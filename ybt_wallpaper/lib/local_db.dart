import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class LocalDb {
  LocalDb._privateConstructor();
  static final LocalDb instance = LocalDb._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'ybt_local.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Favourites table
    await db.execute('''
      CREATE TABLE favourites(
        id INTEGER PRIMARY KEY,
        title TEXT,
        category_id INTEGER,
        file_url TEXT,
        download_count INTEGER,
        created_at TEXT
      )
    ''');

    // Search history table
    await db.execute('''
      CREATE TABLE search_history(
        query TEXT PRIMARY KEY,
        timestamp INTEGER
      )
    ''');

    // Downloads table
    await db.execute('''
      CREATE TABLE downloads(
        id INTEGER PRIMARY KEY,
        title TEXT,
        category_id INTEGER,
        file_url TEXT,
        local_path TEXT,
        created_at TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS downloads(
          id INTEGER PRIMARY KEY,
          title TEXT,
          category_id INTEGER,
          file_url TEXT,
          local_path TEXT,
          created_at TEXT
        )
      ''');
    }
  }

  // ── Favourites ─────────────────────────────────────
  Future<void> addFavourite(Map<String, dynamic> wallpaper) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('web_favourites') ?? '[]';
      final list = List<Map<String, dynamic>>.from(
        (jsonDecode(listStr) as List).map((x) => Map<String, dynamic>.from(x))
      );
      
      list.removeWhere((x) => x['id'] == wallpaper['id']);
      list.insert(0, {
        'id': wallpaper['id'],
        'title': wallpaper['title'],
        'category_id': wallpaper['category_id'],
        'file_url': wallpaper['file_url'],
        'download_count': wallpaper['download_count'] ?? 0,
        'created_at': wallpaper['created_at'],
      });
      
      await prefs.setString('web_favourites', jsonEncode(list));
      return;
    }

    final db = await database;
    await db.insert(
      'favourites',
      {
        'id': wallpaper['id'],
        'title': wallpaper['title'],
        'category_id': wallpaper['category_id'],
        'file_url': wallpaper['file_url'],
        'download_count': wallpaper['download_count'] ?? 0,
        'created_at': wallpaper['created_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavourite(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('web_favourites') ?? '[]';
      final list = List<Map<String, dynamic>>.from(
        (jsonDecode(listStr) as List).map((x) => Map<String, dynamic>.from(x))
      );
      
      list.removeWhere((x) => x['id'] == id);
      await prefs.setString('web_favourites', jsonEncode(list));
      return;
    }

    final db = await database;
    await db.delete(
      'favourites',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isFavourite(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('web_favourites') ?? '[]';
      final list = jsonDecode(listStr) as List;
      return list.any((x) => x['id'] == id);
    }

    final db = await database;
    final maps = await db.query(
      'favourites',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getFavourites() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('web_favourites') ?? '[]';
      final list = List<dynamic>.from(jsonDecode(listStr));
      return list.map((x) => Map<String, dynamic>.from(x)).toList();
    }

    final db = await database;
    return await db.query('favourites', orderBy: 'id DESC');
  }

  Future<void> clearFavourites() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_favourites');
      return;
    }

    final db = await database;
    await db.delete('favourites');
  }

  // ── Search History ──────────────────────────────────
  Future<void> addSearchQuery(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('web_search_history') ?? [];
      
      list.remove(cleanQuery);
      list.insert(0, cleanQuery);
      
      if (list.length > 5) {
        list.removeRange(5, list.length);
      }
      
      await prefs.setStringList('web_search_history', list);
      return;
    }

    final db = await database;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Insert or replace query with new timestamp
    await db.insert(
      'search_history',
      {
        'query': cleanQuery,
        'timestamp': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Keep only last 5 queries
    final history = await db.query(
      'search_history',
      orderBy: 'timestamp DESC',
    );

    if (history.length > 5) {
      // Delete old queries
      final queriesToDelete = history.sublist(5);
      for (final row in queriesToDelete) {
        await db.delete(
          'search_history',
          where: 'query = ?',
          whereArgs: [row['query']],
        );
      }
    }
  }

  Future<List<String>> getSearchHistory() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('web_search_history') ?? [];
    }

    final db = await database;
    final maps = await db.query(
      'search_history',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => maps[i]['query'] as String);
  }

  Future<void> deleteSearchQuery(String query) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('web_search_history') ?? [];
      list.remove(query);
      await prefs.setStringList('web_search_history', list);
      return;
    }

    final db = await database;
    await db.delete(
      'search_history',
      where: 'query = ?',
      whereArgs: [query],
    );
  }

  Future<void> clearSearchHistory() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_search_history');
      return;
    }

    final db = await database;
    await db.delete('search_history');
  }

  // ── Downloads (Offline Storage) ──────────────────────
  Future<void> addDownload(Map<String, dynamic> wallpaper, String localPath) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('web_downloads') ?? '[]';
      final list = List<Map<String, dynamic>>.from(
        (jsonDecode(listStr) as List).map((x) => Map<String, dynamic>.from(x))
      );
      
      list.removeWhere((x) => x['id'] == wallpaper['id']);
      list.insert(0, {
        'id': wallpaper['id'],
        'title': wallpaper['title'],
        'category_id': wallpaper['category_id'],
        'file_url': wallpaper['file_url'],
        'local_path': localPath,
        'created_at': wallpaper['created_at'],
      });
      
      await prefs.setString('web_downloads', jsonEncode(list));
      return;
    }

    final db = await database;
    await db.insert(
      'downloads',
      {
        'id': wallpaper['id'],
        'title': wallpaper['title'],
        'category_id': wallpaper['category_id'],
        'file_url': wallpaper['file_url'],
        'local_path': localPath,
        'created_at': wallpaper['created_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeDownload(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('web_downloads') ?? '[]';
      final list = List<Map<String, dynamic>>.from(
        (jsonDecode(listStr) as List).map((x) => Map<String, dynamic>.from(x))
      );
      
      list.removeWhere((x) => x['id'] == id);
      await prefs.setString('web_downloads', jsonEncode(list));
      return;
    }

    final db = await database;
    await db.delete(
      'downloads',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isDownloaded(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('web_downloads') ?? '[]';
      final list = jsonDecode(listStr) as List;
      return list.any((x) => x['id'] == id);
    }

    final db = await database;
    final maps = await db.query(
      'downloads',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getDownloads() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final listStr = prefs.getString('web_downloads') ?? '[]';
      final list = List<dynamic>.from(jsonDecode(listStr));
      return list.map((x) => Map<String, dynamic>.from(x)).toList();
    }

    final db = await database;
    return await db.query('downloads', orderBy: 'id DESC');
  }

  Future<void> clearDownloads() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('web_downloads');
      return;
    }

    final db = await database;
    await db.delete('downloads');
  }
}
