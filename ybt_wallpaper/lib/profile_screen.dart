import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart' hide Config;
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'auth_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'api.dart';
import 'config.dart';
import 'theme.dart';
import 'main.dart';
import 'local_db.dart';
import 'recently_viewed.dart';
import 'wallpaper_detail.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  // Local stats
  int _favCount = 0;
  int _downloadCount = 0;
  int _daysJoined = 1;

  // Settings values
  String _themeModeStr = 'light';
  String _accentName = 'skyBlue';
  int _gridColumns = 2;
  String _fitMode = 'Fill';
  String _downloadQuality = 'Original';
  bool _autoSave = true;
  String _folderName = 'YBT Wallpaper';
  String _defaultSetAs = 'Both';
  bool _showDownloadsBadge = true;
  bool _safeSearch = false;
  bool _hapticFeedback = true;
  String _cacheSize = '0.00 MB';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _loading = true);
    await _loadUser();
    await _loadStatsAndSettings();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Try fetching from API
      final data = await Api.getMe();
      if (mounted) {
        _user = data['user'] as Map<String, dynamic>;
        
        // Cache name from API
        if (_user?['name'] != null) {
          await prefs.setString('cached_user_name', _user!['name']);
        }
      }
    } catch (_) {
      // Fallback to cached user name if offline
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('cached_user_name') ?? 'Guest User';
      if (mounted) {
        _user = {
          'name': cachedName,
          'email': 'Operating Offline',
          'created_at': DateTime.now().toIso8601String(),
        };
      }
    }
  }

  Future<void> _loadStatsAndSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // SQLite Favourites count
    final favs = await LocalDb.instance.getFavourites();
    _favCount = favs.length;

    // Downloads session count
    _downloadCount = DownloadTracker.sessionDownloads.length;

    // Days since joined
    _daysJoined = _daysSinceJoined(_user?['created_at']);

    // Settings
    _themeModeStr = prefs.getString('theme') ?? 'light';
    _accentName = prefs.getString('accent') ?? 'skyBlue';
    _gridColumns = prefs.getInt('grid_columns') ?? 2;
    _fitMode = prefs.getString('fit_mode') ?? 'Fill';
    _downloadQuality = prefs.getString('download_quality') ?? 'Original';
    _autoSave = prefs.getBool('auto_save') ?? true;
    _folderName = prefs.getString('folder_name') ?? 'YBT Wallpaper';
    _defaultSetAs = prefs.getString('default_set_as') ?? 'Both';
    _showDownloadsBadge = prefs.getBool('show_downloads_badge') ?? true;
    _safeSearch = prefs.getBool('safe_search') ?? false;
    _hapticFeedback = prefs.getBool('haptic_feedback') ?? true;

    // Cache Size
    await _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int totalSize = 0;
      if (tempDir.existsSync()) {
        tempDir.listSync(recursive: true).forEach((file) {
          if (file is File) {
            totalSize += file.lengthSync();
          }
        });
      }
      if (mounted) {
        setState(() {
          _cacheSize = '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cacheSize = '0.00 MB');
      }
    }
  }

  int _daysSinceJoined(String? dateStr) {
    if (dateStr == null) return 1;
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date).inDays;
      return diff <= 0 ? 1 : diff;
    } catch (_) {
      return 1;
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _triggerHaptic() async {
    if (_hapticFeedback) {
      await HapticFeedback.lightImpact();
    }
  }

  Future<void> _logout() async {
    await _triggerHaptic();
    await Api.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _sendSupportEmail() async {
    await _triggerHaptic();
    final uri = Uri(scheme: 'mailto', path: Config.supportEmail);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _shareApp() async {
    await _triggerHaptic();
    await Share.share(
      'Download Bamania wall paper App! Access thousands of free, high-definition wallpapers custom styled for you.',
    );
  }

  Future<void> _editNameSheet() async {
    await _triggerHaptic();
    final controller = TextEditingController(text: _user?['name'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Edit Display Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter display name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(ctx);
                  await _updateName(newName);
                }
              },
              child: const Text('Save Changes'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _updateName(String newName) async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    
    // Fallback: save locally
    await prefs.setString('cached_user_name', newName);

    try {
      // API call (if backend supports PATCH /me, or mock/fail gracefully)
      await Api.updateMe(newName);
    } catch (_) {}

    await _loadUser();
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated successfully!')),
      );
    }
  }

  // Settings modification helpers
  Future<void> _updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
    await _loadStatsAndSettings();
    setState(() {});
  }

  void _showThemeSelector() {
    _triggerHaptic();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Theme Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _radioThemeTile(ctx, 'Light Mode', 'light', ThemeMode.light),
              _radioThemeTile(ctx, 'Dark Mode', 'dark', ThemeMode.dark),
              _radioThemeTile(ctx, 'System Default', 'system', ThemeMode.system),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioThemeTile(BuildContext ctx, String label, String value, ThemeMode mode) {
    final isSelected = _themeModeStr == value;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        _updateSetting('theme', value);
        YBTWallpaperApp.of(context)?.updateThemeMode(mode);
      },
    );
  }

  void _showFitSelector() {
    _triggerHaptic();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Wallpaper Fit Preview Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _radioFitTile(ctx, 'Fill Screen', 'Fill'),
              _radioFitTile(ctx, 'Fit to Screen', 'Fit'),
              _radioFitTile(ctx, 'Center Image', 'Center'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioFitTile(BuildContext ctx, String label, String value) {
    final isSelected = _fitMode == value;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        _updateSetting('fit_mode', value);
      },
    );
  }

  void _showFolderNameDialog() {
    _triggerHaptic();
    final controller = TextEditingController(text: _folderName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Downloads Folder Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter folder name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  _updateSetting('folder_name', name);
                }
              },
              child: const Text('Apply Folder Name'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDefaultSetSelector() {
    _triggerHaptic();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Default Wallpaper Set As',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _radioDefaultSetTile(ctx, 'Home Screen', 'Home'),
              _radioDefaultSetTile(ctx, 'Lock Screen', 'Lock'),
              _radioDefaultSetTile(ctx, 'Home & Lock Screens', 'Both'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioDefaultSetTile(BuildContext ctx, String label, String value) {
    final isSelected = _defaultSetAs == value;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        _updateSetting('default_set_as', value);
      },
    );
  }

  // Clear data methods
  Future<void> _clearCache() async {
    await _triggerHaptic();
    await DefaultCacheManager().emptyCache();
    await _calculateCacheSize();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image cache cleared!')),
    );
  }

  Future<void> _clearSearchHistory() async {
    await _triggerHaptic();
    await LocalDb.instance.clearSearchHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search history cleared!')),
    );
  }

  void _confirmClearFavourites() {
    _triggerHaptic();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Clear All Favourites?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This will permanently delete all wallpapers saved to your local favourites. This action cannot be undone.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await LocalDb.instance.clearFavourites();
                  await _loadStatsAndSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All favourites cleared!')),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Yes, Clear Favourites', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showWallpaperDetail(Map<String, dynamic> wallpaper) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => WallpaperDetail(
        wallpaper: wallpaper,
        onDownloaded: () => _loadProfileData(),
      ),
    ).then((_) => _loadProfileData());
  }

  @override
  Widget build(BuildContext context) {
    final appState = YBTWallpaperApp.of(context);
    final activeAccent = appState?.accentColor ?? AppTheme.skyBlue;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Profile Avatar Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: _editNameSheet,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 44,
                                    backgroundColor: activeAccent,
                                    child: Text(
                                      _getInitials(_user?['name']),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black26, blurRadius: 4)
                                        ],
                                      ),
                                      child: Icon(Icons.edit, size: 14, color: activeAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _user?['name'] ?? 'Guest User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_user?['is_pro'] == 1 || _user?['is_pro'] == true) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber[700],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user?['email'] ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Local stats row
                  Row(
                    children: [
                      _statCard('Downloads', '$_downloadCount', Icons.download_done_rounded),
                      const SizedBox(width: 12),
                      _statCard('Favourites', '$_favCount', Icons.favorite_rounded),
                      const SizedBox(width: 12),
                      _statCard('Days Joined', '$_daysJoined', Icons.calendar_today_rounded),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // PRO Membership Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: (_user?['is_pro'] == 1 || _user?['is_pro'] == true)
                          ? LinearGradient(
                              colors: [Colors.blueGrey[900]!, Colors.blueGrey[700]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [Colors.amber[800]!, Colors.orange[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (_user?['is_pro'] == 1 || _user?['is_pro'] == true)
                              ? Colors.black.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (_user?['is_pro'] == 1 || _user?['is_pro'] == true)
                                      ? Colors.amber.withOpacity(0.2)
                                      : Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.stars_rounded, 
                                  color: (_user?['is_pro'] == 1 || _user?['is_pro'] == true) ? Colors.amber[400] : Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_user?['is_pro'] == 1 || _user?['is_pro'] == true) ? 'PRO Membership Active' : 'Upgrade to PRO',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      (_user?['is_pro'] == 1 || _user?['is_pro'] == true)
                                          ? 'Enjoy unlimited premium wallpaper downloads.'
                                          : 'Unlock high quality premium locked content.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: (_user?['is_pro'] == 1 || _user?['is_pro'] == true)
                                            ? Colors.white.withOpacity(0.7)
                                            : Colors.white.withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (!(_user?['is_pro'] == 1 || _user?['is_pro'] == true)) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () async {
                                await _triggerHaptic();
                                setState(() => _loading = true);
                                try {
                                  final res = await Api.updateMeToPro();
                                  if (res['is_pro'] == true || res['message'] != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Congratulations! You are now a PRO member.'),
                                        backgroundColor: Colors.amber,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Upgrade failed: $e')),
                                  );
                                }
                                await _loadProfileData();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.orange[800],
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Get PRO Features - Upgrade Now', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Session Downloads list
                  if (DownloadTracker.sessionDownloads.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'Downloaded This Session',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: DownloadTracker.sessionDownloads.length,
                        itemBuilder: (ctx, idx) {
                          final w = DownloadTracker.sessionDownloads[idx];
                          return GestureDetector(
                            onTap: () => _showWallpaperDetail(w),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: w['file_url'] ?? '',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Settings Panel
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Text(
                      'Settings',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),

                  // Appearance settings group
                  _settingsHeader('Appearance'),
                  Card(
                    child: Column(
                      children: [
                        _settingsTile(
                          icon: Icons.brightness_6_rounded,
                          title: 'Theme Mode',
                          subtitle: _themeModeStr.toUpperCase(),
                          onTap: _showThemeSelector,
                        ),
                        const Divider(height: 0, indent: 56),
                        ListTile(
                          leading: Icon(Icons.palette_rounded, color: Theme.of(context).colorScheme.primary),
                          title: const Text('Accent Color Preset'),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: YBTWallpaperAppState.accentPresets.keys.map((key) {
                                final color = YBTWallpaperAppState.accentPresets[key]!;
                                final isSelected = _accentName == key;
                                return GestureDetector(
                                  onTap: () {
                                    _triggerHaptic();
                                    _updateSetting('accent', key);
                                    YBTWallpaperApp.of(context)?.updateAccentColor(key);
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 3)
                                          : null,
                                      boxShadow: isSelected
                                          ? [const BoxShadow(color: Colors.black45, blurRadius: 4)]
                                          : null,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTileSwitch(
                          icon: Icons.grid_view_rounded,
                          title: 'Grid View Layout',
                          subtitle: 'Use $_gridColumns columns in lists',
                          value: _gridColumns == 3,
                          onChanged: (v) => _updateSetting('grid_columns', v ? 3 : 2),
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTile(
                          icon: Icons.fit_screen_rounded,
                          title: 'Wallpaper Fit Preview',
                          subtitle: _fitMode,
                          onTap: _showFitSelector,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Downloads settings group
                  _settingsHeader('Downloads'),
                  Card(
                    child: Column(
                      children: [
                        _settingsTileSwitch(
                          icon: Icons.compress_rounded,
                          title: 'Compressed Quality',
                          subtitle: 'Saves cellular data when downloading',
                          value: _downloadQuality == 'Compressed',
                          onChanged: (v) =>
                              _updateSetting('download_quality', v ? 'Compressed' : 'Original'),
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTileSwitch(
                          icon: Icons.save_alt_rounded,
                          title: 'Auto-Save to Gallery',
                          subtitle: 'Automatically back up to device gallery',
                          value: _autoSave,
                          onChanged: (v) => _updateSetting('auto_save', v),
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTile(
                          icon: Icons.folder_open_rounded,
                          title: 'Download Folder Name',
                          subtitle: _folderName,
                          onTap: _showFolderNameDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Behavior settings group
                  _settingsHeader('Behaviour'),
                  Card(
                    child: Column(
                      children: [
                        _settingsTile(
                          icon: Icons.aspect_ratio_rounded,
                          title: 'Default Set As Option',
                          subtitle: _defaultSetAs == 'Both'
                              ? 'Home & Lock Screens'
                              : '$_defaultSetAs Screen',
                          onTap: _showDefaultSetSelector,
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTileSwitch(
                          icon: Icons.badge_outlined,
                          title: 'Show Downloads Badge',
                          subtitle: 'Display count badges on wallpaper items',
                          value: _showDownloadsBadge,
                          onChanged: (v) => _updateSetting('show_downloads_badge', v),
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTileSwitch(
                          icon: Icons.security_rounded,
                          title: 'Safe Search Content',
                          subtitle: 'Filters content locally in client search',
                          value: _safeSearch,
                          onChanged: (v) => _updateSetting('safe_search', v),
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTileSwitch(
                          icon: Icons.vibration_rounded,
                          title: 'Haptic Feedback',
                          subtitle: 'Vibrate slightly on tap actions',
                          value: _hapticFeedback,
                          onChanged: (v) => _updateSetting('haptic_feedback', v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Data & Cache settings group
                  _settingsHeader('Data & Cache'),
                  Card(
                    child: Column(
                      children: [
                        _settingsTile(
                          icon: Icons.cleaning_services_rounded,
                          title: 'Clear Cache Size',
                          subtitle: _cacheSize,
                          trailing: const Text('Clear', style: TextStyle(color: Colors.red)),
                          onTap: _clearCache,
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTile(
                          icon: Icons.history_rounded,
                          title: 'Clear Search History',
                          trailing: const Text('Clear', style: TextStyle(color: Colors.red)),
                          onTap: _clearSearchHistory,
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTile(
                          icon: Icons.delete_forever_rounded,
                          title: 'Clear Saved Favourites',
                          trailing: const Text('Reset', style: TextStyle(color: Colors.red)),
                          onTap: _confirmClearFavourites,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // About settings group
                  _settingsHeader('About'),
                  Card(
                    child: Column(
                      children: [
                        _settingsTile(
                          icon: Icons.info_outline_rounded,
                          title: 'App Version',
                          subtitle: Config.version,
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTile(
                          icon: Icons.mail_outline_rounded,
                          title: 'Email Support',
                          subtitle: Config.supportEmail,
                          onTap: _sendSupportEmail,
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTile(
                          icon: Icons.star_outline_rounded,
                          title: 'Rate App',
                          onTap: _triggerHaptic, // Simulate rate dialog/link
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTile(
                          icon: Icons.share_rounded,
                          title: 'Share Bamania wall paper App',
                          onTap: _shareApp,
                        ),
                        const Divider(height: 0, indent: 56),
                        _settingsTile(
                          icon: Icons.logout_rounded,
                          title: 'Logout Account',
                          titleColor: Colors.redAccent,
                          iconColor: Colors.redAccent,
                          onTap: _logout,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
      onTap: onTap,
    );
  }

  Widget _settingsTileSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: (v) {
        _triggerHaptic();
        onChanged(v);
      },
      activeThumbColor: Theme.of(context).colorScheme.primary,
    );
  }
}
