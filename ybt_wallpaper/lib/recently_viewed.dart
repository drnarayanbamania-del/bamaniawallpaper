import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecentlyViewed {
  static const String _key = 'recently_viewed_wallpapers';

  static Future<void> addWallpaper(Map<String, dynamic> wallpaper) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getString(_key);
    List<dynamic> list = [];

    if (listStr != null) {
      try {
        list = jsonDecode(listStr) as List<dynamic>;
      } catch (_) {
        list = [];
      }
    }

    // Remove duplicates if the wallpaper is already in the list
    list.removeWhere((item) => item['id'] == wallpaper['id']);

    // Insert at beginning of list
    list.insert(0, {
      'id': wallpaper['id'],
      'title': wallpaper['title'],
      'category_id': wallpaper['category_id'],
      'file_url': wallpaper['file_url'],
      'download_count': wallpaper['download_count'] ?? 0,
      'created_at': wallpaper['created_at'],
    });

    // Limit to 10 items
    if (list.length > 10) {
      list = list.sublist(0, 10);
    }

    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getWallpapers() async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getString(_key);
    if (listStr == null) return [];

    try {
      final list = jsonDecode(listStr) as List<dynamic>;
      return list.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class DownloadTracker {
  static final List<Map<String, dynamic>> sessionDownloads = [];

  static void addDownload(Map<String, dynamic> wallpaper) {
    sessionDownloads.removeWhere((item) => item['id'] == wallpaper['id']);
    sessionDownloads.insert(0, wallpaper);
  }
}
