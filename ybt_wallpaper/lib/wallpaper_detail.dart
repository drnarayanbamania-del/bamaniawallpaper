import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'local_db.dart';
import 'recently_viewed.dart';
import 'wallpaper_editor.dart';
import 'ad_helper.dart';

class WallpaperDetail extends StatefulWidget {
  final Map<String, dynamic> wallpaper;
  final VoidCallback? onDownloaded;

  const WallpaperDetail({
    super.key,
    required this.wallpaper,
    this.onDownloaded,
  });

  @override
  State<WallpaperDetail> createState() => _WallpaperDetailState();
}

class _WallpaperDetailState extends State<WallpaperDetail> {
  late Map<String, dynamic> _activeWallpaper;
  bool _downloading = false;
  bool _isFavourite = false;
  bool _loadingSimilar = true;
  List<dynamic> _similarWallpapers = [];
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _activeWallpaper = widget.wallpaper;
    _initDetailData();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerAd() {
    _bannerAd = AdHelper.createBannerAd(
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() => _isBannerAdLoaded = true);
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        _bannerAd = null;
      },
    );
    _bannerAd!.load();
  }

  void _initDetailData() {
    _checkFavourite();
    _loadSimilar();
    RecentlyViewed.addWallpaper(_activeWallpaper);
  }

  Future<void> _checkFavourite() async {
    final fav = await LocalDb.instance.isFavourite(_activeWallpaper['id']);
    if (mounted) {
      setState(() => _isFavourite = fav);
    }
  }

  Future<void> _toggleFavourite() async {
    await HapticFeedback.lightImpact();
    if (_isFavourite) {
      await LocalDb.instance.removeFavourite(_activeWallpaper['id']);
      setState(() => _isFavourite = false);
      _showToast('Removed from favourites');
    } else {
      await LocalDb.instance.addFavourite(_activeWallpaper);
      setState(() => _isFavourite = true);
      _showToast('Added to favourites ❤️');
    }
  }

  Future<void> _loadSimilar() async {
    setState(() => _loadingSimilar = true);
    try {
      final categoryId = _activeWallpaper['category_id'];
      if (categoryId != null) {
        final data = await Api.getWallpapers(page: 1, categoryId: categoryId);
        if (mounted) {
          final list = data['wallpapers'] as List<dynamic>;
          // Remove current wallpaper from similar list
          _similarWallpapers = list.where((w) => w['id'] != _activeWallpaper['id']).toList();
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingSimilar = false);
    }
  }

  Future<void> _shareWallpaper() async {
    await HapticFeedback.lightImpact();
    final imageUrl = _activeWallpaper['file_url'] ?? '';
    if (imageUrl.isEmpty) return;

    _showToast('Preparing share content...');
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/shared_wallpaper_${_activeWallpaper['id']}_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(response.bodyBytes);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: 'Check out "${_activeWallpaper['title']}" on Bamania wall paper app!',
        );
      } else {
        _showToast('Failed to retrieve image for sharing', isError: true);
      }
    } catch (e) {
      _showToast('Error sharing wallpaper: $e', isError: true);
    }
  }

  void _showUpgradePrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 40),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'PRO Membership Required',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'This is a premium locked wallpaper. Upgrade to PRO to unlock all premium wallpapers, high-speed downloads, and support our development!',
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.white.withOpacity(0.65),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _downloading = true);
                  try {
                    final res = await Api.updateMeToPro();
                    if (res['is_pro'] == true || res['message'] != null) {
                      _showToast('Upgraded to PRO successfully! 🎉');
                      // Wait a brief moment then retry download
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _download();
                      });
                    }
                  } catch (e) {
                    _showToast('Upgrade failed: $e', isError: true);
                    setState(() => _downloading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Upgrade to PRO Now', 
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.6),
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLimitReachedPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[950],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 40),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Daily Limit Reached',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w800, 
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Standard users are limited to 3 downloads per day. Upgrade to PRO to enjoy unlimited high-speed downloads!',
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.white.withOpacity(0.65),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _downloading = true);
                  try {
                    final res = await Api.updateMeToPro();
                    if (res['is_pro'] == true || res['message'] != null) {
                      _showToast('Upgraded to PRO successfully! 🎉');
                      // Wait a brief moment then retry download
                      Future.delayed(const Duration(milliseconds: 500), () {
                        _download();
                      });
                    }
                  } catch (e) {
                    _showToast('Upgrade failed: $e', isError: true);
                    setState(() => _downloading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Upgrade to PRO Now', 
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white.withOpacity(0.6),
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _download() async {
    await HapticFeedback.mediumImpact();
    setState(() => _downloading = true);

    try {
      // ── Pro Premium Wallpapers validation ────────────────
      final isPremium = _activeWallpaper['is_premium'] == 1 || _activeWallpaper['is_premium'] == true;
      if (isPremium) {
        bool isPro = false;
        try {
          final profile = await Api.getMe();
          isPro = profile['user']['is_pro'] == 1 || profile['user']['is_pro'] == true;
          // Update cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('cached_is_pro', isPro);
        } catch (_) {
          final prefs = await SharedPreferences.getInstance();
          isPro = prefs.getBool('cached_is_pro') ?? false;
        }

        if (!isPro) {
          setState(() => _downloading = false);
          _showUpgradePrompt();
          return;
        }
      }

      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final photosStatus = await Permission.photos.request();
          if (!photosStatus.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Storage permission required'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            }
            setState(() => _downloading = false);
            return;
          }
        }
      }

      // Increment download count on backend
      await Api.downloadWallpaper(_activeWallpaper['id']);

      // Download image bytes
      final imageUrl = _activeWallpaper['file_url'] ?? '';
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        try {
          // Save to gallery
          await Gal.putImageBytes(
            Uint8List.fromList(response.bodyBytes),
            album: 'YBT Wallpaper',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Wallpaper saved to gallery!'),
                backgroundColor: Theme.of(context).colorScheme.primary,
                behavior: SnackBarBehavior.floating,
              ),
            );

            // Update download counts in active view
            setState(() {
              _activeWallpaper['downloads'] = (_activeWallpaper['downloads'] ?? 0) + 1;
            });
            DownloadTracker.addDownload(_activeWallpaper);
            widget.onDownloaded?.call();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to save wallpaper: $e'),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('limit reached')) {
        setState(() => _downloading = false);
        _showLimitReachedPrompt();
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openZoomPreview() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullScreenZoom(
          imageUrl: _activeWallpaper['file_url'] ?? '',
          title: _activeWallpaper['title'] ?? 'Preview',
          heroTag: 'detail_hero_${_activeWallpaper['id']}',
        ),
      ),
    );
  }

  void _openEditor() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WallpaperEditor(wallpaper: _activeWallpaper),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenHeight * 0.9,
      child: Column(
        children: [
          // Full-screen image preview with actions
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: _openZoomPreview,
                  child: Hero(
                    tag: 'detail_hero_${_activeWallpaper['id']}',
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      child: CachedNetworkImage(
                        imageUrl: _activeWallpaper['file_url'] ?? '',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (ctx, url) => Center(
                          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        ),
                        errorWidget: (ctx, url, err) => Container(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Top control buttons on image
                Positioned(
                  top: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _imageButton(
                        icon: Icons.zoom_in_rounded,
                        onPressed: _openZoomPreview,
                      ),
                      const SizedBox(width: 10),
                      _imageButton(
                        icon: _isFavourite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: _isFavourite ? Colors.redAccent : Colors.white,
                        onPressed: _toggleFavourite,
                      ),
                      const SizedBox(width: 10),
                      _imageButton(
                        icon: Icons.share_rounded,
                        onPressed: _shareWallpaper,
                      ),
                      const SizedBox(width: 10),
                      _imageButton(
                        icon: Icons.edit_road_rounded,
                        onPressed: _openEditor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Info + Similar + Download bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  _activeWallpaper['title'] ?? 'Untitled',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Category + Downloads
                Row(
                  children: [
                    if (_activeWallpaper['category_name'] != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _activeWallpaper['category_name'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_activeWallpaper['downloads'] ?? 0} downloads',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Similar Wallpapers Header
                const Text(
                  'Similar Wallpapers',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Similar Wallpapers Horizontal Row
                SizedBox(
                  height: 90,
                  child: _loadingSimilar
                      ? _buildSimilarShimmer()
                      : _similarWallpapers.isEmpty
                          ? Center(
                              child: Text(
                                'No similar wallpapers found',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.4),
                                ),
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _similarWallpapers.length,
                              itemBuilder: (ctx, idx) {
                                final similar = _similarWallpapers[idx];
                                return GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      _activeWallpaper = similar;
                                      _initDetailData();
                                    });
                                  },
                                  child: Container(
                                    width: 60,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: similar['file_url'] ?? '',
                                        fit: BoxFit.cover,
                                        placeholder: (ctx, url) => Container(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withOpacity(0.1),
                                        ),
                                        errorWidget: (ctx, url, err) => const Icon(
                                            Icons.broken_image,
                                            size: 20),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                const SizedBox(height: 16),

                // Download button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(_downloading ? 'Saving to Gallery...' : 'Download to Gallery'),
                  ),
                ),

                // Banner Ad
                if (_isBannerAdLoaded && _bannerAd != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imageButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color iconColor = Colors.white,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildSimilarShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: 4,
      itemBuilder: (ctx, idx) => Shimmer.fromColors(
        baseColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        highlightColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        child: Container(
          width: 60,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class FullScreenZoom extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String heroTag;

  const FullScreenZoom({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              placeholder: (ctx, url) => Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              ),
              errorWidget: (ctx, url, err) =>
                  const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
