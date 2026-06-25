import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'api.dart';
import 'config.dart';
import 'theme.dart';
import 'search_screen.dart';
import 'recently_viewed.dart';
import 'wallpaper_detail.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  List<dynamic> _allWallpapers = [];
  List<dynamic> _featuredWallpapers = [];
  List<dynamic> _trendingWallpapers = [];
  List<Map<String, dynamic>> _recentlyViewed = [];

  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset > 400 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
    } else if (_scrollController.offset <= 400 && _showBackToTop) {
      setState(() => _showBackToTop = false);
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadWallpapers(),
      _loadRecentlyViewed(),
    ]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadRecentlyViewed() async {
    final list = await RecentlyViewed.getWallpapers();
    if (mounted) {
      setState(() {
        _recentlyViewed = list;
      });
    }
  }

  Future<void> _loadWallpapers() async {
    try {
      final data = await Api.getWallpapers(page: 1);
      if (mounted) {
        final list = data['wallpapers'] as List<dynamic>;
        _allWallpapers = list;
        _currentPage = 1;
        _totalPages = data['pagination']['totalPages'] ?? 1;

        // Featured: newest 5
        _featuredWallpapers = list.take(5).toList();

        // Trending: sorted by downloads descending
        List<dynamic> sorted = List.from(list);
        sorted.sort((a, b) => (b['downloads'] ?? 0).compareTo(a['downloads'] ?? 0));
        _trendingWallpapers = sorted.take(6).toList();
      }
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _totalPages) return;
    setState(() => _loadingMore = true);

    try {
      final data = await Api.getWallpapers(page: _currentPage + 1);
      if (mounted) {
        setState(() {
          _allWallpapers.addAll(data['wallpapers'] as List);
          _currentPage++;
          _totalPages = data['pagination']['totalPages'] ?? 1;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _showWallpaperDetail(Map<String, dynamic> wallpaper) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => WallpaperDetail(
        wallpaper: wallpaper,
        onDownloaded: () {
          _loadAllData();
        },
      ),
    ).then((_) {
      // Reload recently viewed after closing sheet
      _loadRecentlyViewed();
    });
  }

  void _showLongPressPreview(Map<String, dynamic> wallpaper) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: wallpaper['file_url'] ?? '',
                  fit: BoxFit.contain,
                  placeholder: (ctx, url) => Container(
                    height: 300,
                    color: Colors.black26,
                    child: Center(
                      child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                wallpaper['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isNew(String? dateStr) {
    if (dateStr == null) return false;
    try {
      final date = DateTime.parse(dateStr);
      return DateTime.now().difference(date).inDays <= 7;
    } catch (_) {
      return false;
    }
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          Config.appName,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
            icon: const Icon(Icons.search_rounded, size: 22),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: Theme.of(context).colorScheme.primary,
        child: _loading
            ? _buildShimmerLoading()
            : SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar (tappable trigger)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SearchScreen()),
                          );
                        },
                        child: AbsorbPointer(
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Search wallpapers...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              fillColor: Theme.of(context).colorScheme.surface,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Featured Banner (horizontal list)
                    if (_featuredWallpapers.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Featured Wallpapers',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _featuredWallpapers.length,
                          itemBuilder: (ctx, i) {
                            final w = _featuredWallpapers[i];
                            return GestureDetector(
                              onTap: () => _showWallpaperDetail(w),
                              onLongPress: () => _showLongPressPreview(w),
                              child: Container(
                                width: 280,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: w['file_url'] ?? '',
                                        fit: BoxFit.cover,
                                        placeholder: (ctx, url) => Shimmer.fromColors(
                                          baseColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                          highlightColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                          child: Container(color: Colors.white),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [Colors.transparent, Colors.black87],
                                            ),
                                          ),
                                          child: Text(
                                            w['title'] ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Trending Section
                    if (_trendingWallpapers.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Trending Wallpapers',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _trendingWallpapers.length,
                          itemBuilder: (ctx, i) {
                            final w = _trendingWallpapers[i];
                            return GestureDetector(
                              onTap: () => _showWallpaperDetail(w),
                              onLongPress: () => _showLongPressPreview(w),
                              child: Container(
                                width: 95,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: w['file_url'] ?? '',
                                        fit: BoxFit.cover,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          color: Colors.black54,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.download_rounded,
                                                  color: Colors.white, size: 10),
                                              const SizedBox(width: 2),
                                              Text(
                                                '${w['downloads'] ?? 0}',
                                                style: const TextStyle(
                                                    color: Colors.white, fontSize: 9),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Recently Viewed Section
                    if (_recentlyViewed.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Recently Viewed',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _recentlyViewed.length,
                          itemBuilder: (ctx, i) {
                            final w = _recentlyViewed[i];
                            return GestureDetector(
                              onTap: () => _showWallpaperDetail(w),
                              onLongPress: () => _showLongPressPreview(w),
                              child: Container(
                                width: 95,
                                margin: const EdgeInsets.only(right: 10),
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
                    ],

                    // Explore Grid Header
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text(
                        'Explore Wallpapers',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),

                    // Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _allWallpapers.length + (_loadingMore ? 2 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= _allWallpapers.length) {
                          return _buildShimmerCard();
                        }
                        final w = _allWallpapers[i];
                        return _buildWallpaperCard(w);
                      },
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: _showBackToTop
          ? FloatingActionButton(
              onPressed: _scrollToTop,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              mini: true,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
    );
  }

  Widget _buildWallpaperCard(Map<String, dynamic> wallpaper) {
    final showNewBadge = _isNew(wallpaper['created_at']);

    return GestureDetector(
      onTap: () => _showWallpaperDetail(wallpaper),
      onLongPress: () => _showLongPressPreview(wallpaper),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: wallpaper['file_url'] ?? '',
              fit: BoxFit.cover,
              placeholder: (ctx, url) => Shimmer.fromColors(
                baseColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                highlightColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                child: Container(color: Colors.white),
              ),
              errorWidget: (ctx, url, err) => Container(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                child: const Icon(Icons.broken_image_rounded, size: 32),
              ),
            ),
            // Bottom gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Text(
                  wallpaper['title'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // "New" badge
            if (showNewBadge)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
      highlightColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar placeholder
          Padding(
            padding: const EdgeInsets.all(16),
            child: Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              highlightColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Featured Banner title placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 20,
              width: 150,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 10),
          // Featured Banner cards placeholder
          SizedBox(
            height: 180,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: 2,
              itemBuilder: (ctx, i) => Shimmer.fromColors(
                baseColor: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                highlightColor: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                child: Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Explore grid placeholder
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.65,
            ),
            itemCount: 4,
            itemBuilder: (ctx, i) => _buildShimmerCard(),
          ),
        ],
      ),
    );
  }
}
