import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'config.dart';
import 'theme.dart';
import 'search_screen.dart';
import 'recently_viewed.dart';
import 'wallpaper_detail.dart';
import 'local_db.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  late final PageController _pageController;
  double _carouselCurrentPage = 0.0;

  List<dynamic> _allWallpapers = [];
  List<dynamic> _featuredWallpapers = [];
  List<dynamic> _trendingWallpapers = [];
  List<Map<String, dynamic>> _recentlyViewed = [];
  List<Map<String, dynamic>> _offlineWallpapers = [];

  String _selectedSection = 'All'; // 'All', 'Featured', 'Trending', 'Offline'

  bool _loading = true;
  bool _loadingMore = false;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _showBackToTop = false;
  bool _showDownloadsBadge = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _carouselCurrentPage = _pageController.page ?? 0.0;
        });
      }
    });
    _loadSettings();
    _loadAllData();
    _scrollController.addListener(_scrollListener);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showDownloadsBadge = prefs.getBool('show_downloads_badge') ?? true;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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

  Future<void> _loadOfflineDownloads() async {
    final list = await LocalDb.instance.getDownloads();
    if (mounted) {
      setState(() {
        _offlineWallpapers = list;
      });
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _loadWallpapers(),
      _loadRecentlyViewed(),
      _loadOfflineDownloads(),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/logo.png',
                height: 32,
                width: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.wallpaper_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              Config.appName,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
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

                    // Section Filter Chips
                    _buildFilterChips(),
                    const SizedBox(height: 8),

                    // Modular Section Body
                    _buildSectionBody(),

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
            // "PRO" lock badge
            if (wallpaper['is_premium'] == 1 || wallpaper['is_premium'] == true)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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
            // Downloads Count Badge
            if (_showDownloadsBadge)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download_rounded, color: Colors.white, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        '${wallpaper['downloads'] ?? 0}',
                        style: const TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ],
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

  Widget _buildFilterChips() {
    final sections = ['All', 'Featured', 'Trending', 'Offline'];
    return SizedBox(
      height: 48,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final sec = sections[index];
          final isSelected = _selectedSection == sec;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(sec),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedSection = sec;
                });
                if (sec == 'Offline') {
                  _loadOfflineDownloads();
                }
              },
              selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOfflineWallpaperCard(Map<String, dynamic> wallpaper) {
    final localPath = wallpaper['local_path'] ?? '';
    final file = File(localPath);
    return GestureDetector(
      onTap: () => _showWallpaperDetail(wallpaper),
      onLongPress: () => _showLongPressPreview(wallpaper),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            file.existsSync()
                ? Image.file(
                    file,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    child: const Icon(Icons.broken_image_rounded, size: 32),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBody() {
    if (_selectedSection == 'All') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Banner (animated PageView carousel)
          if (_featuredWallpapers.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Editor\'s Choice',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.2),
              ),
            ),
            SizedBox(
              height: 200,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _featuredWallpapers.length,
                itemBuilder: (ctx, i) {
                  final w = _featuredWallpapers[i];
                  double scale = 1.0;
                  if (_pageController.position.haveDimensions) {
                    double value = _carouselCurrentPage - i;
                    scale = (1 - value.abs() * 0.08).clamp(0.9, 1.0);
                  } else {
                    scale = i == 0 ? 1.0 : 0.92;
                  }

                  return Transform.scale(
                    scale: scale,
                    child: GestureDetector(
                      onTap: () => _showWallpaperDetail(w),
                      onLongPress: () => _showLongPressPreview(w),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
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
                                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black87],
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          w['title'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (w['is_premium'] == 1 || w['is_premium'] == true)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber[700],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock_rounded, color: Colors.white, size: 10),
                                              SizedBox(width: 2),
                                              Text(
                                                'PRO',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Carousel Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_featuredWallpapers.length, (idx) {
                bool isActive = _carouselCurrentPage.round() == idx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                  height: 6,
                  width: isActive ? 16 : 6,
                  decoration: BoxDecoration(
                    color: isActive 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
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
      );
    } else if (_selectedSection == 'Featured') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Featured Wallpapers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
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
            itemCount: _featuredWallpapers.length,
            itemBuilder: (ctx, i) {
              final w = _featuredWallpapers[i];
              return _buildWallpaperCard(w);
            },
          ),
        ],
      );
    } else if (_selectedSection == 'Trending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Trending Wallpapers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
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
            itemCount: _trendingWallpapers.length,
            itemBuilder: (ctx, i) {
              final w = _trendingWallpapers[i];
              return _buildWallpaperCard(w);
            },
          ),
        ],
      );
    } else { // 'Offline'
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(
              'Offline Downloads',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          _offlineWallpapers.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No offline wallpapers found',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Wallpapers you download to gallery will appear here for offline viewing.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.65,
                  ),
                  itemCount: _offlineWallpapers.length,
                  itemBuilder: (ctx, i) {
                    final w = _offlineWallpapers[i];
                    return _buildOfflineWallpaperCard(w);
                  },
                ),
        ],
      );
    }
  }
}
